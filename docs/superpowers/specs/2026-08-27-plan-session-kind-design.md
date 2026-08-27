# Tipo de sessão "Plano" — design

Data: 2026-08-27
Estado: aprovado, a aguardar plano de implementação

## Objectivo

Um terceiro tipo de sessão, `SessionKind.plan`, para planear o dia com
antecedência (ou registar retroactivamente o que se tinha planeado, para
comparar depois com o que foi de facto executado). Ao contrário de
Trabalho/Pausa, um Plano:

- pode ter datas no futuro (e no passado, sem restrição nenhuma);
- pode sobrepor-se a sessões de Trabalho/Pausa sem gerar aviso — é o
  comportamento esperado (planear em cima do que se vai fazer);
- aparece no calendário com uma cor própria, `#FAE588`.

## Fora de âmbito (nesta versão)

- **Comparação planeado vs executado.** É a motivação de fundo do Plano,
  mas fica para uma iteração futura, com o seu próprio design.
- **Iniciar um Plano "ao vivo"** (botão Começar no popover). Confirmado
  com o utilizador: um Plano só se cria à mão — `SessionEditorView` (na
  janela principal) ou arrastando/redimensionando um Plano já existente
  no calendário. Nenhum ponto de entrada do `TimerEngine`/popover ganha
  a opção "Plano".
- **Integração com o Pomodoro.** O `PomodoroController` só alterna
  `.work`/`.break`; não ganha um terceiro estado.
- **Sessão "Plano" a decorrer no calendário** (`CalendarRunningBlock`).
  Como o Plano nunca é iniciado ao vivo, este componente nunca recebe
  `kind == .plan` — fica sem alterações.
- **Relatórios.** `ReportBuilder.dailyReport`/`weeklyReport` continuam a
  filtrar por `kind == .work`; o Plano fica automaticamente fora dos
  totais, tal como a Pausa já fica hoje. Sem alterações a este ficheiro.

## Modelo de dados

`Models/Session.swift`:

```swift
enum SessionKind: String, Codable {
    case work
    case `break`
    case plan
}
```

Alteração puramente aditiva — `SessionKind` persiste como `String`
(`Codable`/SwiftData), pelo que dados existentes não são afectados e não
há migração a fazer.

## Editor de sessões (`SessionEditorView.swift`)

O `Picker` de tipo (hoje segmentado "Trabalho"/"Pausa") ganha uma terceira
opção "Plano", na mesma ordem em que os casos aparecem no enum:

```swift
Picker("Tipo", selection: $kind) {
    Text("Trabalho").tag(SessionKind.work)
    Text("Pausa").tag(SessionKind.break)
    Text("Plano").tag(SessionKind.plan)
}
.pickerStyle(.segmented)
```

A validação "Não podes usar datas no futuro" (`attemptSave()`) passa a só
se aplicar quando o tipo seleccionado não é Plano:

```swift
if kind != .plan {
    let now = Date()
    guard startedAt <= now, endedAt <= now else {
        errorMessage = "Não podes usar datas no futuro."
        return
    }
}
```

Nenhuma outra validação (duração > 12h, campos obrigatórios) muda —
aplicam-se da mesma forma a qualquer tipo, incluindo Plano.

## Sobreposição (`SessionStore.overlappingSession`)

Único sítio onde a regra de sobreposição é decidida, partilhado pelo
editor manual e pelo arrasto no calendário (extraído no branch anterior,
`SessionStore.swift`). Ganha um parâmetro `kind` — o tipo da sessão a
ser gravada/movida — e a sobreposição fica **silenciosa** exactamente
quando um dos dois lados é Plano e o outro não é:

```swift
static func overlappingSession(
    startedAt: Date,
    endedAt: Date,
    excluding excludedID: PersistentIdentifier?,
    kind: SessionKind,
    in sessions: [Session]
) -> Session? {
    sessions.first { candidate in
        if let excludedID, candidate.persistentModelID == excludedID {
            return false
        }
        guard startedAt < candidate.endedAt && endedAt > candidate.startedAt else {
            return false
        }
        let exactlyOnePlan = (kind == .plan) != (candidate.kind == .plan)
        return !exactlyOnePlan
    }
}
```

Tabela de resultado (aviso sim/não) por combinação de tipos:

| Novo \ Existente | Trabalho | Pausa | Plano |
|---|---|---|---|
| Trabalho | avisa | avisa | silencioso |
| Pausa | avisa | avisa | silencioso |
| Plano | silencioso | silencioso | avisa |

Os dois chamadores (`SessionEditorView.attemptSave`,
`CalendarWeekView`'s `overlapCheck` closure passado a
`CalendarSessionBlock`) passam o `kind` da sessão em causa — no editor,
o `@State kind` seleccionado no Picker; no calendário, `segment.session.kind`
(capturado no closure no momento em que é criado, sem alterar a assinatura
do closure que `CalendarSessionBlock` já usa).

## Calendário (`CalendarSessionBlock.swift`)

**Cor de preenchimento** — `fillColor` ganha um terceiro ramo explícito
(deixa de ser um `if/else` binário `.break`/resto):

```swift
private var fillColor: Color {
    switch segment.session.kind {
    case .break: return Color.gray.opacity(0.35)
    case .plan: return Color(hex: "FAE588").opacity(0.85)
    case .work: return (segment.session.task?.project?.color ?? .secondary).opacity(0.55)
    }
}
```

(Opacidade 0.85 para o Plano — mais opaco que Trabalho/Pausa porque a cor
`#FAE588` já é clara; ajustável no acabamento visual sem mudar a lógica.)

**Sem tarefa atribuída** — hoje, uma sessão de Trabalho sem tarefa mostra
contorno tracejado e o texto "Sem atribuição"; combinado com o pedido
explícito do utilizador ("nunca tracejado, só a cor amarela"):

- `isUnassignedWork` mantém-se `kind == .work && task == nil` — não se
  alarga a Plano, o contorno tracejado fica reservado a Trabalho.
- `title` ganha um terceiro ramo: sem tarefa e `kind == .plan` → "Plano"
  (em vez de "Sem atribuição").

```swift
private var title: String {
    if let taskTitle = segment.session.task?.title { return taskTitle }
    switch segment.session.kind {
    case .break: return "Pausa"
    case .plan: return "Plano"
    case .work: return "Sem atribuição"
    }
}
```

**Arrastar/redimensionar para o futuro** — `finishDrag`'s guard de "não
pode mover para o futuro" passa a ignorar sessões Plano:

```swift
if segment.session.kind != .plan, newEnd > Date() {
    showingFutureAlert = true
    return
}
```

Nenhuma outra parte do gesto de arrastar (snap, clamp horizontal aos dias
visíveis, alerta de confirmação com "De:"/"Para:", alerta de duração > 12h)
muda — aplicam-se da mesma forma a qualquer tipo, incluindo Plano.

## Testes

Sem target de testes automatizado neste projecto (decisão já tomada em
trabalho anterior nesta branch). Verificação: build Release com zero
avisos, e confirmação manual do utilizador (não é possível testar
arrasto/UI ao vivo neste ambiente) de:

- O Picker mostra "Plano" e grava/edita correctamente.
- Uma sessão Plano com data futura grava sem erro; uma sessão
  Trabalho/Pausa com data futura continua a ser rejeitada.
- Uma sessão Plano sobreposta a uma sessão Trabalho grava sem alerta;
  duas sessões Trabalho sobrepostas continuam a avisar.
- O bloco Plano aparece no calendário com a cor `#FAE588`, sem contorno
  tracejado mesmo sem tarefa, com o texto "Plano" quando sem tarefa.
- Arrastar um Plano para o dia seguinte funciona sem o alerta "Não é
  possível mover para o futuro"; arrastar uma sessão Trabalho/Pausa para
  o dia seguinte continua a mostrar esse alerta.
