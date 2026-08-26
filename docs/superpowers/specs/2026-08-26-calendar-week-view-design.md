# Vista semanal de calendário — design

Data: 2026-08-26
Estado: aprovado, a aguardar plano de implementação

## Objectivo

Nova aba na janela principal (primeira na sidebar) que mostra as sessões da
semana num calendário tipo grelha (dias em coluna, horas em linha), com
suporte para arrastar sessões para as mover ou redimensionar, actualizando o
`Session` correspondente. Fim-de-semana visível/escondido por preferência.

## Fora de âmbito (nesta versão)

- Criar sessões novas a partir do calendário (clique+arrasto em área vazia).
  Continua a fazer-se pelo popover (Começar/Parar) ou pelo `SessionEditorView`.
- Popover rápido ao clicar num bloco — usa-se o `SessionEditorView` completo.
- Mover por arrasto horizontal (entre dias) uma sessão que atravessa a
  meia-noite — essa edição faz-se no `SessionEditorView`.

## Componentes

### `UI/CalendarWeekView.swift` (novo)

View principal da aba. Estado local: `referenceDate` (semana visível, default
hoje). Lê `showWeekend` de `@AppStorage(PreferencesKey.reportsShowWeekend)` —
**reaproveitada da preferência já existente em Reports**, não é uma nova
chave; mudar a opção nas Preferências afecta as duas vistas.

Reaproveita:
- `ReportBuilder.weekDays(containing:showWeekend:)` para obter os 5/7 dias.
- O padrão de navegação semanal do `ReportsView` (`weekNavigator`): chevrons
  esquerda/direita a saltar ±7 dias, botão "Esta semana" a repor
  `referenceDate = Date()`.

Faz `@Query` a todas as `Session` e filtra em memória as que tocam algum dos
dias visíveis (mesma abordagem do `ReportsView`, não há necessidade de query
com predicate por datas dado o volume de dados de uso pessoal).

Estrutura visual: `ScrollView` vertical com uma grelha de fundo (linhas de
hora, 00:00–24:00), colunas de dia lado a lado, blocos de sessão posicionados
em `ZStack` por cima da grelha via `.offset`/`.position` calculados a partir
de `CalendarLayoutMath`.

### `UI/CalendarSessionBlock.swift` (novo)

Um bloco de sessão (ou segmento de sessão, ver secção "Sessões que atravessam
a meia-noite"). Responsabilidades:

- Cor de preenchimento = cor do projecto da tarefa associada.
- Sessões `.break` (pausa): estilo neutro/cinzento em vez da cor do projecto.
- Sessão sem tarefa atribuída ("Sem atribuição"): contorno tracejado.
- Sessão com `editedAt` preenchido: ícone pequeno ou itálico no texto, mesmo
  tratamento discreto já usado nos Reports.
- Sessão a decorrer (sem `endedAt`): renderiza até "agora", sem gesto de
  arrasto anexado — não é arrastável nem redimensionável enquanto corre.
- `DragGesture` no corpo do bloco → mover.
- Dois handles finos (topo/fundo) → redimensionar, cada um só presente
  quando o segmento representa o extremo real da sessão (ver abaixo).
- Durante o arrasto: não escreve no SwiftData, só actualiza um offset visual
  local; fica com contorno de aviso se a posição candidata colidir com outra
  sessão (chamada a `SessionStore.overlappingSession` a cada frame de drag,
  contra a lista de sessões já carregada em memória — sem custo de I/O).
- Ao soltar: dispara o commit (ver "Fluxo de arrasto").

### `Core/CalendarLayoutMath.swift` (novo)

Struct/funções puras, sem SwiftUI, para:

- Conversão hora↔pixel (altura da grelha ÷ 24h) e o inverso (pixel→`Date`).
- Snap ao intervalo configurado em `PreferencesKey.calendarSnapMinutes`.
- Divisão de uma sessão que atravessa a meia-noite em segmentos por dia
  (ver secção dedicada).
- Atribuição de "faixas" horizontais quando duas ou mais sessões do mesmo dia
  se sobrepõem no tempo (permitido pelo modelo — overlaps são avisados, não
  bloqueados), para as desenhar lado a lado em vez de sobrepostas.

Sendo puro, é testável com Swift Testing sem correr a app.

### `SessionStore` (alteração)

Extrai-se a lógica de `findOverlappingSession`, hoje só dentro do
`SessionEditorView`, para um método partilhado:

```swift
static func overlappingSession(
    for candidate: (start: Date, end: Date),
    excluding: PersistentIdentifier?,
    in sessions: [Session]
) -> Session?
```

Mesma regra (`startedAt < candidate.endedAt && endedAt > candidate.startedAt`,
excluindo a própria sessão em edição). Reaproveitado pelo `SessionEditorView`
(substituindo a implementação local) e pelo `CalendarSessionBlock`/
`CalendarWeekView` durante o arrasto.

### `MainWindowSection` (alteração)

Novo caso `.calendar`, **declarado primeiro** (a ordem do enum define a
ordem na sidebar). Ícone SF Symbol `calendar`. `detailContent` ganha o
`case .calendar: CalendarWeekView()` correspondente.

### `Preferences` (alteração)

Nova chave `PreferencesKey.calendarSnapMinutes` /
`PreferencesDefault.calendarSnapMinutes = 15`. `SettingsView` ganha um
`Picker` (5 / 15 / 30 min) numa secção "Calendário".

A preferência de mostrar fim-de-semana **não é nova** — reaproveita-se
`reportsShowWeekend` já existente, sem duplicar estado (decisão explícita:
mudar essa opção nas Preferências afecta Reports e Calendário em conjunto).

## Fluxo de arrasto (mover e redimensionar)

**Mover** (arrastar o corpo do bloco):
- Recalcula `startedAt`/`endedAt` mantendo a duração, com snap ao intervalo
  configurado.
- Funciona vertical (mudar hora no mesmo dia) e horizontal (mudar de dia),
  **excepto** para sessões que atravessam a meia-noite: essas só se movem
  verticalmente dentro do próprio segmento, nunca trocam de dia por arrasto
  (mover horizontalmente um intervalo de dois dias é ambíguo — ver secção
  dedicada).

**Redimensionar** (arrastar um handle de borda):
- Handle de topo só existe no segmento que contém o `startedAt` real da
  sessão; handle de fundo só no segmento que contém o `endedAt` real.
- O gesto é limitado (clamp) para nunca cruzar o extremo oposto — garante
  `endedAt > startedAt` sem precisar de alerta.
- O gesto é limitado a não ultrapassar "agora" — não é possível arrastar uma
  sessão para o futuro (sem alerta, apenas clamp silencioso, consistente
  com a validação já existente no `SessionEditorView`).

**Commit ao soltar** (mover ou redimensionar):
1. Corre `SessionStore.overlappingSession(...)` contra as sessões carregadas.
2. Se colidir: alerta "Sobreposição de sessões" (mesmo texto/padrão do
   `SessionEditorView`) com "Continuar mesmo assim" / "Cancelar". Cancelar
   repõe a posição original sem gravar nada.
3. Se a duração resultante > 12h: mesmo alerta de confirmação já existente
   no editor.
4. Ao confirmar (ou se não houver conflito/duração longa), grava-se
   `editedAt = Date()` e a sessão é actualizada via `modelContext`, igual ao
   que o `SessionEditorView` já faz.

Nenhuma escrita no SwiftData acontece durante o arrasto — só no commit final,
consistente com a regra existente de "só grava no fim".

## Sessões que atravessam a meia-noite

Uma sessão com `startedAt` num dia e `endedAt` no dia seguinte é dividida
**visualmente** em dois segmentos (um por dia), pelo `CalendarLayoutMath` —
o `Session` subjacente continua a ser um único registo, os segmentos são
puramente de renderização.

- Segmento do primeiro dia: vai até às 24:00, tem o handle de redimensionar
  de topo (é onde a sessão começa de facto).
- Segmento do segundo dia: começa às 00:00, tem o handle de redimensionar de
  fundo (é onde a sessão acaba de facto).
- Ambos os segmentos disparam o mesmo gesto de mover (arrastar qualquer um
  desloca a sessão inteira no tempo, sem mudar de dia — ver acima).

Sessões que atravessam **mais do que uma** meia-noite (duram 2+ dias
completos) são um caso extremo e raro para uma app de time tracking pessoal
(já disparam o alerta de "duração > 12h" muito antes disso); ficam clipadas
ao primeiro e último dia visível da semana, sem handles de redimensionar
nem gesto de mover — apenas informativas. Não vale a pena construir a
mecânica completa de N segmentos para este caso.

## Distinção visual (resumo)

| Estado | Tratamento |
|---|---|
| Cor base | Cor do projecto da tarefa |
| `.break` | Neutro/cinzento, ignora cor de projecto |
| Sem tarefa atribuída | Contorno tracejado |
| `editedAt` preenchido | Ícone discreto / itálico (mesmo padrão dos Reports) |
| A decorrer (sem `endedAt`) | Bloco até "agora", sem drag |
| Candidato em overlap durante arrasto | Contorno de aviso |

## Testes

- `CalendarLayoutMath`: testável com Swift Testing (conversão hora↔pixel,
  snap, split de meia-noite, atribuição de faixas) — puro, sem SwiftUI.
- `SessionStore.overlappingSession`: testável directamente, substitui e
  cobre o que hoje só é exercitado manualmente através do
  `SessionEditorView`.
- Não automatizável (confirmar manualmente antes de dar como concluído):
  sensação do arrasto/snap ao vivo, hit-testing dos handles de
  redimensionar, aparência dos blocos partidos na meia-noite, comportamento
  em multi-monitor ao mover a janela principal. Xcode Previews não
  reproduzem gestos de arrasto ao vivo, só estados estáticos.

## Decisões tomadas durante o brainstorming

- Snap: 15 min por default, configurável (5/15/30) nas Preferências.
- Criar sessões no calendário: fora de âmbito nesta versão.
- Sessão a decorrer: aparece, sem ser arrastável.
- Preferência de fim-de-semana: partilhada com Reports (`reportsShowWeekend`).
- Overlap: feedback visual durante o arrasto + alerta de confirmação ao
  soltar (reaproveitando o alerta já existente).
- Grelha: 24h completas com scroll vertical.
- Arrasto entre dias: permitido, excepto para sessões que atravessam a
  meia-noite (só arrasto vertical nesse caso).
- Clique no bloco: sem acção; duplo clique abre o `SessionEditorView`
  (consistente com o comportamento actual noutras listas).
- Cor: cor do projecto + tratamento distinto para pausa/sem
  atribuição/editada manualmente.
- Meia-noite: sessão dividida em dois segmentos visuais, um por dia.
