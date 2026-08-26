# Xisto — time tracker + pomodoro para macOS

App nativa SwiftUI que vive na menu bar. Uso pessoal, single-user, offline.
Nunca vai para a App Store.

Comunica comigo em português. Código, identificadores, nomes de ficheiros e
comentários em inglês.

---

## Ambiente

- Xcode 26.6 (build 17F113), SDK macOS 26 — o design system novo (Liquid Glass)
  aplica-se automaticamente. Não escrever workarounds para SwiftUI antigo.
- Deployment target: macOS 14.0
- Apple Silicon apenas (`arm64`). Não configurar universal binary.
- Assinatura: *Sign to Run Locally*, Team `None`. Sem notarização.
- **App Sandbox desligado** (deliberado).
- Sem dependências externas. Nada de SPM sem me perguntares primeiro.

## Comandos

Nome real do projecto/scheme: **"Xisto In Time"** (não "Xisto"). O
`.xcodeproj` fica na raiz do repo, uma pasta acima do código-fonte (que
também se chama "Xisto In Time"). Os comandos abaixo assumem que estás
nessa raiz.

Build (Release — é a versão instalada e corrida pelo Spotlight):
```bash
xcodebuild -project "Xisto In Time.xcodeproj" -scheme "Xisto In Time" \
  -configuration Release -destination 'platform=macOS' -derivedDataPath ./build build
```

Se a alteração tocar em modelos `@Model` (`Session`/`TaskItem`/`Project`) ou
em `NavigationLink`/`navigationDestination`, faz `rm -rf ./build` antes de
compilar — o `clean build` normal não limpa o cache de módulos e já
mascarou um bug real de isolamento de actor (Swift 6 concurrency + SwiftData).

Instalar e correr pelo Spotlight (repete isto sempre que alteras algo —
a app corre a partir de `~/Applications`, não da pasta de build):
```bash
pkill -f "Xisto In Time"
rm -rf "$HOME/Applications/Xisto In Time.app"
cp -R "./build/Build/Products/Release/Xisto In Time.app" "$HOME/Applications/"
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f "$HOME/Applications/Xisto In Time.app"
open "$HOME/Applications/Xisto In Time.app"
```

Isto deixa a app localizável pelo Spotlight (Cmd+Espaço, "Xisto") como uma
app instalada normal.

Depois de qualquer alteração, compila e corre desta forma antes de dizeres
que está feito. Warnings contam como problemas a resolver.

---

## Arquitectura

```
Xisto/
  Xisto_In_TimeApp.swift          Settings scene, ciclo de vida, liga os controllers todos
  Models/                  @Model SwiftData
  Core/
    TimerEngine.swift      fonte única de verdade do tempo decorrido
    SessionStore.swift     CRUD + validação de sessões
    PomodoroController.swift  ciclos trabalho/pausa, o TimerEngine não sabe nada disto
    IdleMonitor.swift      inactividade via CGEventSource
    OverlayController.swift NSPanel de fim de sessão/idle (genérico, hospeda qualquer View)
    MenuBarController.swift  NSStatusItem à mão — ver nota abaixo sobre o porquê
    MainWindowController.swift  NSWindow à mão para a janela principal
    ReportBuilder.swift    agregações diárias e semanais
    Preferences.swift      @AppStorage, tipado
  UI/
    MenuBarLabel.swift     glifo + contador — conteúdo hospedado pelo MenuBarController
    PopoverView.swift      conteúdo do popover — minimalista, ver abaixo
    PomodoroDecisionView.swift  ecrã de decisão do overlay (pomodoro)
    IdleResolutionView.swift    ecrã de decisão do overlay (idle)
    MainWindowView.swift   janela principal — sidebar + detalhe, ver abaixo
    ProjectsView.swift     lista de projectos, criar/arquivar
    TasksBrowserView.swift lista de tarefas, criar/arquivar
    SessionEditorView.swift editar/criar entrada
    TaskDetailView.swift   tarefa + histórico de notas acumuladas
    ReportsView.swift      vista diária e semanal
    SettingsView.swift     preferências
```

**Nota importante: o ícone da barra não usa `MenuBarExtra`.** Tentámos
primeiro com `MenuBarExtra(.window)` (fases 1–8), mas o SwiftUI não dá
forma de distinguir clique esquerdo de direito nesse botão — qualquer
view personalizada metida lá dentro para apanhar o `rightMouseDown` nunca
recebe o evento. Chegámos a simplificar para "qualquer clique abre/fecha
sempre o popover, sem menu de contexto", mas voltámos atrás: clique
esquerdo no ícone (`Core/MenuBarController.swift`, `NSStatusItem` à mão,
`button.sendAction(on: [.leftMouseUp, .rightMouseUp])`) alterna o
popover; clique direito mostra um `NSMenu` pequeno ("Abrir janela" /
"Sair") via `NSMenu.popUp(positioning:at:in:)`, distinguindo os dois
através de `NSApp.currentEvent?.type`. O cabeçalho "Hoje Xh Ym" dentro do
popover também abre a janela principal, e a engrenagem ao lado abre
Preferências directamente (`SettingsLink`); "Preferências" e "Sair"
continuam também no fundo da barra lateral da janela principal.

**O popover já não é um `NSPopover`.** Com o conteúdo a variar de altura
(legenda do modo, configuração do Pomodoro, selector de tarefa), o
`NSPopover` reposicionava-se por vezes com base num tamanho desactualizado
e aparecia fora do sítio — tentámos propagar `preferredContentSize` e
depois impor um tecto de altura ao conteúdo, sem sucesso consistente. A
solução foi deixar de depender do posicionamento automático: o popover é
agora um `NSPanel` próprio (`Core/MenuBarController.swift`, `styleMask:
[.borderless, .nonactivatingPanel]`, `isMovableByWindowBackground = true`),
que se arrasta clicando numa área livre e memoriza essa posição
(`Preferences.popoverOrigin`/`setPopoverOrigin`) — na primeira vez, ou se a
posição guardada deixar de caber em nenhum ecrã ligado, calcula-se uma por
baixo do ícone. Como um `NSPanel` não fecha sozinho ao clicar fora,
`MenuBarController` instala dois `NSEvent` monitors (global e local)
enquanto está visível para replicar esse comportamento. `PopoverView.swift`
ganhou o próprio fundo (`.regularMaterial` com cantos arredondados), já
que deixou de haver o balão do `NSPopover` a dar-lho. Um
`AppDelegate` (`Core/AppDelegate.swift`, ligado via
`@NSApplicationDelegateAdaptor`) implementa
`applicationShouldHandleReopen` para relançar a janela principal ao abrir
a app pelo Spotlight (ou pelo Dock) enquanto já está a correr. Por associação, a
janela principal também passou a ser gerida à mão
(`MainWindowController.swift`, um `NSWindow` simples) em vez de uma
`Window` scene do SwiftUI — assim que o popover e a janela deixam de
viver dentro de uma `Scene`, coisas como `@Environment(\.modelContext)`
têm de ser aplicadas manualmente (`.environment(\.modelContext, ...)`) ao
construir cada `NSHostingController`/`NSHostingView`. A `Settings` scene
continua a ser SwiftUI puro — é a única que sobra em
`Xisto_In_TimeApp.body` — e abre-se com `SettingsLink` (a API pública do
macOS 14+; o truque do selector privado `showSettingsWindow:` já não
funciona sem aviso no SDK actual).

### Duas superfícies — não é tudo no popover

A app **não vive inteira na menu bar**. Há duas superfícies distintas, com
responsabilidades diferentes:

- **Popover da menu bar** (`PopoverView.swift`, mostrado por
  `MenuBarController` num `NSPanel` próprio — ver nota acima) —
  minimalista, para interacções rápidas de segundos: tempo decorrido,
  botão Começar/Parar, um selector
  do projecto/tarefa já existentes (sem criar nem arquivar nada aqui), a
  nota opcional ao fechar a sessão, e o cabeçalho "Xisto" que abre a
  janela principal. Nada de navegação em profundidade, nada de CRUD, nada
  de listas extensas — se precisa de scroll ou de um formulário, não é
  para o popover.
- **Janela principal** (`MainWindowView.swift`, mostrada por
  `MainWindowController` num `NSWindow` simples) — é onde vive a gestão:
  criar/editar/arquivar projectos e tarefas, `TaskDetailView`, edição de
  sessões (`SessionEditorView`), `ReportsView`, e Preferências/Sair no
  fundo da barra lateral. Abre-se clicando no cabeçalho "Xisto" do
  popover.

Regra prática para decidir onde algo vive: se é "consultar/agir em
segundos sem tirar as mãos do teclado/rato da tarefa actual", é popover.
Se é "gerir, organizar, rever histórico", é janela principal.

### Modelo de dados

Hierarquia de três níveis: `Project` → `TaskItem` → `Session`.

- `Project` — name, colour, archived (Bool)
- `TaskItem` — title, externalRef (opcional, ex. `MC2-T374`), project (relação),
  archived (Bool), createdAt
- `Session` — startedAt, endedAt, task (relação **opcional**), kind
  (`.work` / `.break`), note (opcional), interrupted (Bool), editedAt (opcional)

**Nota sobre o nome `TaskItem`:** não usar `Task`. Colide com o `Task` da
concurrency do Swift e obriga a desambiguar com `_Concurrency.Task` por todo o
lado. `TaskItem` no modelo, "tarefa" no UI.

**Sessões soltas são normais, não um erro.** Posso premir start sem escolher
nada e atribuir a tarefa mais tarde. Consequências:
- `Session.task` é opcional em todo o código. Nada assume que existe.
- Os reports mostram um bucket **"Sem atribuição"** em destaque, não escondido.
- Atribuir uma tarefa a uma sessão solta faz-se editando a sessão
  (`SessionEditorView`, na janela principal) — sem ecrã dedicado de
  atribuição em lote (removido deliberadamente).

**Arquivo é sempre manual.** Nunca inferir que um projecto ou tarefa está
concluído por inactividade. Itens arquivados desaparecem dos selectores mas
continuam nos reports históricos.

### Notas acumuladas na tarefa

A nota é escrita por sessão, mas a leitura principal é ao nível da tarefa:
`TaskDetailView` mostra todas as notas das sessões daquela tarefa em ordem
cronológica, com data e duração de cada uma. É um diário de progresso.
A nota é pedida quando a sessão termina, nunca a bloquear — se eu não escrever
nada, a sessão grava-se sem nota.

Regra: uma sessão só é gravada quando termina. Nada de escrever no SwiftData
a cada segundo.

---

## Edição de entradas

**Qualquer sessão é editável e apagável, e posso criar sessões à mão** (para
trabalho feito longe do computador, ou quando me esqueci de premir start).
Editáveis: início, fim, tarefa, tipo, nota, flag de interrompida.

O `SessionEditorView` é o mesmo componente para editar e para criar.

Validação:
- `endedAt > startedAt`, obrigatório. Rejeitar.
- Datas no futuro: rejeitar.
- **Sobreposições são permitidas, mas avisadas.** Um alerta a dizer com que
  sessão colide e a pedir confirmação. Nunca bloquear em silêncio nem
  reordenar automaticamente — sou eu que sei o que quero.
- Duração acima de 12h: pedir confirmação.

`editedAt` é preenchido em qualquer alteração manual. Os reports marcam essas
entradas discretamente (ícone ou itálico), para eu saber o que foi medido e o
que foi escrito à mão. Não é auditoria, é confiança nos meus próprios números.

Sessão a correr não é editável — parar primeiro.

---

## Detecção de idle

Requisito, não extra. O risco maior deste tipo de app é o timer ficar a correr
enquanto eu estou numa reunião ou almoçar.

Implementação: `CGEventSource.secondsSinceLastEventType(.combinedSessionState,
eventType: .anyInputEventType)`, sondado a cada 30s. Não precisa de permissões
de acessibilidade — não usar Accessibility API nem event taps para isto.

Tudo configurável nas preferências, com estes defaults:
- Detecção activa: **ligada**
- Limiar: **10 minutos** sem input
- Ao detectar idle: **perguntar** — descartar o tempo inactivo, manter o tempo
  inactivo, ou terminar a sessão no momento em que o idle começou
- Alternativas à pergunta (escolha minha nas preferências): descartar
  automaticamente, ou apenas notificar

Regra crítica: o `IdleMonitor` tem de guardar o **timestamp em que a
inactividade começou**, não só o facto de estar inactivo. Sem isso não é
possível oferecer "terminar a sessão quando eu parei".

Idle não se aplica a sessões de pausa (`.break`) nem ao tempo de espera do
overlay.

---

## Regras invioláveis

1. **O timer nunca acumula ticks.** Guardar `Date` de início e calcular por
   diferença. O `Timer` de 1s serve exclusivamente para redesenhar o UI.
2. **Sleep/wake é explícito.** Subscrever `NSWorkspace.willSleepNotification`
   e `didWakeNotification`. Se a máquina adormeceu a meio de uma sessão de
   trabalho, marcar `interrupted = true` e não contar o tempo de sono.
3. **Overlay = NSPanel**, não `Window` nem `.sheet`. Configuração obrigatória:
   `level = .screenSaver`,
   `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`,
   `isFloatingPanel = true`, `hidesOnDeactivate = false`.
4. **O overlay apresenta a decisão, sem lutar contra o sistema.** Duas acções
   explícitas: *começar pausa* ou *continuar a trabalhar*. Pode fechar com
   Esc (equivale à opção mais neutra, "continuar" — não descarta nada em
   silêncio). Não é preciso bloquear clique-fora nem tornar a janela
   impossível de fechar — isso complica a implementação sem trazer valor
   real; prefiro a app leve. O que continua inegociável: o tempo à espera da
   decisão não é atribuído a nada — quando o overlay aparece, a sessão
   anterior (trabalho ou pausa) já foi fechada com o `endedAt` correcto.
5. **Não tocar em**: signing, App Sandbox, entitlements, `LSUIElement`,
   nem no `project.pbxproj` de forma geral. Estão configurados à mão.
   Se precisares de mudar algo aí, diz-me e eu faço na GUI.
6. **Zero rede.** Sem HTTP, analytics, crash reporting ou sincronização.
7. Dados em `~/Library/Application Support/Xisto In Time/default.store` —
   **nunca** no caminho genérico por omissão do SwiftData
   (`Application Support/default.store`, sem subpasta). Sem sandbox, essa
   pasta genérica é partilhada por todas as apps sem sandbox da máquina; já
   aconteceu outra app aterrar exactamente nesse caminho e apagar por
   completo a base de dados do Xisto (v1.10.1, 2026-08-20). `StoreMaintenance`
   migra automaticamente um `default.store` antigo encontrado no caminho
   genérico, mas só se o esquema for reconhecidamente do Xisto. Não escrever
   em `~/Documents`.
8. Preferências em `UserDefaults` via `@AppStorage`, nunca no SwiftData.
9. Abrir a janela de Preferências usa a `Settings` scene padrão do SwiftUI,
   através de `SettingsLink`.

## Reports

Preciso de responder a "o que é que eu fiz hoje" e "onde foi a minha semana"
sem exportar nada.

- **Vista diária** — timeline das sessões, total, quebra por projecto.
- **Vista semanal** — total por projecto e por tarefa, dias em colunas.
- Sessões `interrupted`, editadas manualmente e sem atribuição: todas visíveis
  e distinguíveis.
- Números em horas decimais *e* em `h:mm`.

Sem exportação CSV nesta fase. A estrutura de dados deve permitir acrescentá-la
depois sem migração.

## Como trabalhar comigo

- **Plan mode primeiro.** Apresenta o plano e espera aprovação antes de
  escrever código. Aplica-se a tudo excepto correcções triviais.
- Uma fatia de cada vez. Não avanças de fase sem eu confirmar que a anterior
  funciona.
- Commits pequenos e descritivos. Não fazer commit sem eu pedir.
- Não refactorizar código que eu não pedi para mexer.
- Se uma decisão de UX for ambígua, pergunta em vez de assumir.

## Versionamento

A partir do commit inicial (v1.0.0, 2026-08-18), o projecto segue
[SemVer](https://semver.org/lang/pt-BR/): `major.minor.patch`.

- **major** — alterações estruturais/breaking (ex.: mudança de modelo de
  dados que exige migração, remoção de uma superfície inteira).
- **minor** — novas funcionalidades (ex.: uma fase nova do roadmap, um novo
  ecrã).
- **patch** — correcções de bugs, sem funcionalidade nova.

Cada alteração relevante actualiza a versão nestes quatro sítios, em
conjunto:

1. `VERSION` (raiz do repo) — o número, sozinho.
2. `CHANGELOG.md` (raiz do repo) — entrada nova, formato
   [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).
3. `Core/AppVersion.swift` — a constante `AppVersion.current`, mostrada no
   rodapé das Preferências (`SettingsView`).
4. Uma git tag `vX.Y.Z` no commit correspondente.

Não avanço a versão sozinho sem confirmar contigo o tipo de bump
(major/minor/patch) quando não for óbvio.

## O que tu não consegues verificar

Compilar não é validar. Quando terminares algo que envolva isto, diz-me
explicitamente o que devo testar:

- Aspecto e comportamento do glifo na menu bar
- Overlay por cima de apps em fullscreen (o caso crítico)
- Comportamento em multi-monitor
- Sleep/wake e mudança de Space
- Detecção de idle (só testável esperando de verdade)
- Xcode Previews não renderizam `MenuBarExtra` nem `NSPanel`

---

## Roadmap

Trabalhar por esta ordem. Não saltar fases.

1. **Esqueleto** — `MenuBarExtra` estilo `.window`, glifo estático, popover
   vazio. Confirmar que arranca sem aparecer no Dock.
2. **Timer manual** — start/stop de sessões soltas, contador na menu bar,
   tempo correcto após sleep.
3. **Persistência** — modelos SwiftData, gravar sessões terminadas, lista do
   histórico do dia.
4. **Projectos e tarefas** — hierarquia, selector no popover, nota ao fechar,
   atribuição posterior de sessões soltas, `TaskDetailView`.
5. **Edição** — `SessionEditorView` com validação, criar/editar/apagar.
6. **Pomodoro** — ciclos 25/5, pausa longa de 15 ao fim de 4, configurável.
7. **Overlay** — NSPanel com decisão forçada. Fase de maior risco;
   esperar validação minuciosa.
8. **Idle** — `IdleMonitor` + preferências.
9. **Reports** — vistas diária e semanal.
10. **Extras** — atalhos globais, exportação CSV.

A fase 5 traz a `SettingsView` mínima; as fases 6 e 8 acrescentam-lhe secções.

## Decisões em aberto

- Formato da semana nos reports: semana ISO (segunda a domingo) ou 7 dias a
  contar de hoje?
- Ao atribuir em lote sessões soltas, agrupar por proximidade temporal ou
  listar uma a uma?
- Pausas contam como tempo trabalhado nos totais? Assumir **não**, mas
  mostradas separadamente.
