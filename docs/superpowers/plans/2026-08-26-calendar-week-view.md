# Vista Semanal de Calendário — Plano de Implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Nova aba "Calendário" (primeira na sidebar) na janela principal, mostrando as sessões da semana numa grelha dia×hora, com arrastar-para-mover e arrastar-para-redimensionar que actualizam a sessão correspondente.

**Architecture:** SwiftUI puro (sem `NSViewRepresentable`), consistente com o resto das views de conteúdo da app (`ReportsView`, `TaskDetailView`). Uma view de topo (`CalendarWeekView`) reaproveita `ReportBuilder.weekDays` e o padrão de navegação semanal já usado em `ReportsView`. Os blocos de sessão (`CalendarSessionBlock`) usam `DragGesture` local (baseado em `translation`, não em coordinate space partilhado) para mover/redimensionar, escrevendo no SwiftData só ao soltar. A lógica de sobreposição é extraída de `SessionEditorView` para `SessionStore`, partilhada pelos dois.

**Tech Stack:** Swift 6 / SwiftUI / SwiftData, macOS 26 SDK, sem dependências externas.

**Spec:** `docs/superpowers/specs/2026-08-26-calendar-week-view-design.md`

## Global Constraints

- Sem testes automatizados — o projecto não tem target de testes e o CLAUDE.md proíbe mexer no `project.pbxproj` sem perguntar primeiro (decisão tomada explicitamente com o utilizador durante o brainstorming). Cada tarefa termina com build + instalação + verificação manual, nunca com testes automatizados.
- **Build & Instalar** (repetir depois de cada tarefa, comandos exactos do CLAUDE.md):
  ```bash
  xcodebuild -project "Xisto In Time.xcodeproj" -scheme "Xisto In Time" \
    -configuration Release -destination 'platform=macOS' -derivedDataPath ./build build
  ```
  ```bash
  pkill -f "Xisto In Time"
  rm -rf "$HOME/Applications/Xisto In Time.app"
  cp -R "./build/Build/Products/Release/Xisto In Time.app" "$HOME/Applications/"
  /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f "$HOME/Applications/Xisto In Time.app"
  open "$HOME/Applications/Xisto In Time.app"
  ```
  Warnings contam como problemas a resolver. Se uma tarefa tocar em `@Model` ou em `NavigationLink`/`navigationDestination`, faz `rm -rf ./build` antes do build acima (mascarou um bug real de isolamento de actor no passado) — indicado explicitamente nas tarefas onde se aplica.
- Português no chat/commits, inglês no código/identificadores/comentários — como em todo o resto do repo.
- Zero rede, zero dependências novas.
- Não tocar em `project.pbxproj`, signing, entitlements — nada nesta feature precisa disso (não há novo target).
- Commits pequenos, um por tarefa.

## Decisões de UX assumidas neste plano (a confirmar ao rever)

- `MainWindowSection.calendar` fica **primeiro** no enum (ordem = ordem na sidebar) e passa a ser a **secção seleccionada por omissão** ao abrir a janela principal (antes era `.sessions`). Se preferires manter `.sessions` como default, é uma troca de uma linha (`selection: MainWindowSection? = .sessions`) — sinaliza se for esse o caso.
- Ícone `calendar`, cor `teal` (as outras já usam blue/green/orange/purple).
- Grelha: 56pt por hora (1344pt de altura total), colunas de dia com 130pt, gutter de horas com 44pt — valores de arranque, ajustáveis visualmente sem mudar a arquitectura.

---

### Task 1: Preferência `calendarSnapMinutes`

**Files:**
- Modify: `Xisto In Time/Core/Preferences.swift:19` (PreferencesKey), `:36` (PreferencesDefault)

**Interfaces:**
- Produces: `PreferencesKey.calendarSnapMinutes: String`, `PreferencesDefault.calendarSnapMinutes: Int = 15`

- [ ] **Step 1: Adicionar a chave e o default**

Em `PreferencesKey` (depois da linha 19, junto a `reportsShowWeekend`):
```swift
    static let reportsShowWeekend = "reportsShowWeekend"
    static let calendarSnapMinutes = "calendarSnapMinutes"
```

Em `PreferencesDefault` (depois da linha 36):
```swift
    static let reportsShowWeekend = true
    static let calendarSnapMinutes = 15
```

- [ ] **Step 2: Build & instalar** (comandos em Global Constraints)

Não precisa de `rm -rf ./build` — não toca em `@Model` nem navegação.

- [ ] **Step 3: Verificar**

A app continua a compilar e a abrir normalmente (esta tarefa não tem UI própria ainda — só a chave existe).

- [ ] **Step 4: Commit**

```bash
git add "Xisto In Time/Core/Preferences.swift"
git commit -m "feat: preferência calendarSnapMinutes"
```

---

### Task 2: Painel "Calendário" nas Preferências

**Files:**
- Modify: `Xisto In Time/UI/SettingsView.swift`

**Interfaces:**
- Consumes: `PreferencesKey.calendarSnapMinutes`, `PreferencesDefault.calendarSnapMinutes` (Task 1)

- [ ] **Step 1: Adicionar a aba ao `TabView`**

Depois da aba `ReportsSettingsPane` (linha 29-32), adicionar:
```swift
                ReportsSettingsPane()
                    .tabItem {
                        Label("Relatórios", systemImage: "chart.bar")
                    }

                CalendarSettingsPane()
                    .tabItem {
                        Label("Calendário", systemImage: "calendar")
                    }
```

- [ ] **Step 2: Definir a nova pane**

No fim do ficheiro, depois de `ReportsSettingsPane` (linha 166), adicionar:
```swift
private struct CalendarSettingsPane: View {
    @AppStorage(PreferencesKey.calendarSnapMinutes)
    private var calendarSnapMinutes = PreferencesDefault.calendarSnapMinutes

    private let options = [5, 15, 30]

    var body: some View {
        Form {
            Section {
                Picker("Encaixar (snap) ao arrastar", selection: $calendarSnapMinutes) {
                    ForEach(options, id: \.self) { minutes in
                        Text("\(minutes) min").tag(minutes)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
```

- [ ] **Step 3: Build & instalar**

- [ ] **Step 4: Verificar manualmente**

Abrir Preferências (engrenagem no popover ou barra lateral da janela principal) → deve aparecer uma 5ª aba "Calendário" com um Picker de 5/15/30 min, a começar em 15. Mudar o valor e reabrir as Preferências — deve manter o valor escolhido (persistido em `UserDefaults`).

- [ ] **Step 5: Commit**

```bash
git add "Xisto In Time/UI/SettingsView.swift"
git commit -m "feat: painel de preferências do Calendário"
```

---

### Task 3: Extrair lógica partilhada para `SessionStore`

**Files:**
- Modify: `Xisto In Time/Core/SessionStore.swift`
- Modify: `Xisto In Time/UI/SessionEditorView.swift:154, 197-204, 214-220`

**Interfaces:**
- Produces:
  - `SessionStore.overlappingSession(startedAt: Date, endedAt: Date, excluding: PersistentIdentifier?, in: [Session]) -> Session?`
  - `SessionStore.rescheduleSession(_ session: Session, startedAt: Date, endedAt: Date, in context: ModelContext)`
  - `SessionStore.describe(_ session: Session) -> String`
- Consumed later by: Task 8 (drag para mover), Task 9 (redimensionar) via `overlappingSession`/`rescheduleSession`/`describe`.

- [ ] **Step 1: Adicionar `import SwiftData` (já existe) e os três métodos a `SessionStore`**

No fim de `Xisto In Time/Core/SessionStore.swift`, antes da chaveta final (depois da linha 66 `deleteCascading`):
```swift
    // MARK: - Overlap / reschedule
    //
    // Shared by SessionEditorView (manual edit) and the calendar week view
    // (drag to move/resize) — same overlap rule, one place.

    static func overlappingSession(
        startedAt: Date,
        endedAt: Date,
        excluding excludedID: PersistentIdentifier?,
        in sessions: [Session]
    ) -> Session? {
        sessions.first { candidate in
            if let excludedID, candidate.persistentModelID == excludedID {
                return false
            }
            return startedAt < candidate.endedAt && endedAt > candidate.startedAt
        }
    }

    static func rescheduleSession(_ session: Session, startedAt: Date, endedAt: Date, in context: ModelContext) {
        session.startedAt = startedAt
        session.endedAt = endedAt
        session.editedAt = Date()
        context.saveAndCheckpoint()
    }

    static func describe(_ session: Session) -> String {
        let range = "\(session.startedAt.formatted(date: .abbreviated, time: .shortened)) – \(session.endedAt.formatted(date: .omitted, time: .shortened))"
        if let title = session.task?.title {
            return "\(range) (\(title))"
        }
        return "\(range) (sem atribuição)"
    }
```

- [ ] **Step 2: Substituir `findOverlappingSession()` em `SessionEditorView` pela versão partilhada**

Em `attemptSave()` (linha 154), trocar:
```swift
        if let overlapping = findOverlappingSession() {
```
por:
```swift
        if let overlapping = SessionStore.overlappingSession(startedAt: startedAt, endedAt: endedAt, excluding: existingSession?.persistentModelID, in: allSessions) {
```

Remover a função `findOverlappingSession()` inteira (linhas 197-204).

- [ ] **Step 3: Substituir `describe(_:)` local pela versão partilhada**

Remover a função privada `describe(_:)` (linhas 214-220). Trocar a única chamada, dentro de `attemptSave()`:
```swift
            overlapDescription = describe(overlapping)
```
por:
```swift
            overlapDescription = SessionStore.describe(overlapping)
```

- [ ] **Step 4: Build & instalar**

Não toca em `@Model` (só adiciona métodos a um `enum`, e edita uma View) nem em navegação — não precisa de `rm -rf ./build`.

- [ ] **Step 5: Verificar manualmente**

Criar duas sessões com horários sobrepostos através do `SessionEditorView` (janela principal → Sessões → editar/criar) — o alerta "Sobreposição de sessões" tem de continuar a aparecer exactamente como antes. Confirmar que "Continuar mesmo assim" ainda grava.

- [ ] **Step 6: Commit**

```bash
git add "Xisto In Time/Core/SessionStore.swift" "Xisto In Time/UI/SessionEditorView.swift"
git commit -m "refactor: extrai overlap/reschedule/describe de sessões para SessionStore"
```

---

### Task 4: Expor o início da sessão a decorrer no `TimerEngine`

**Files:**
- Modify: `Xisto In Time/Core/TimerEngine.swift:133-136` (junto a `remaining`)

**Interfaces:**
- Produces: `TimerEngine.currentStartedAt: Date?`
- Consumed later by: Task 10 (bloco "a decorrer" no calendário).

- [ ] **Step 1: Adicionar a computed property**

Depois de `var remaining: TimeInterval? { ... }` (linha 133-136), adicionar:
```swift
    /// Wall-clock start of the running session, for callers that need to
    /// position it on a timeline (e.g. the calendar week view). `nil` when
    /// nothing is running.
    var currentStartedAt: Date? { startedAt }
```

- [ ] **Step 2: Build & instalar**

- [ ] **Step 3: Verificar**

Só compilar já chega — a propriedade não tem consumidor ainda (chega no Task 10). Confirmar que a app continua a arrancar e a contar sessões normalmente (não deve haver regressão no popover).

- [ ] **Step 4: Commit**

```bash
git add "Xisto In Time/Core/TimerEngine.swift"
git commit -m "feat: expõe TimerEngine.currentStartedAt"
```

---

### Task 5: `CalendarLayoutMath` — matemática pura da grelha

**Files:**
- Create: `Xisto In Time/Core/CalendarLayoutMath.swift`

**Interfaces:**
- Produces:
  - `struct CalendarSessionSegment: Identifiable` com campos `id: String`, `session: Session`, `day: Date`, `segmentStart: Date`, `segmentEnd: Date`, `isSessionStart: Bool`, `isSessionEnd: Bool`, `lane: Int`, `laneCount: Int`.
  - `CalendarLayoutMath.snap(_ date: Date, toMinutes: Int, calendar: Calendar = .current) -> Date`
  - `CalendarLayoutMath.yOffset(for date: Date, day: Date, hourHeight: CGFloat, calendar: Calendar = .current) -> CGFloat`
  - `CalendarLayoutMath.segments(for sessions: [Session], days: [Date], calendar: Calendar = .current) -> [CalendarSessionSegment]`
- Consumed later by: Task 6/7 (`CalendarWeekView`), Task 8/9 (`CalendarSessionBlock`), Task 10 (`CalendarRunningBlock`, via `yOffset`).

- [ ] **Step 1: Escrever o ficheiro completo**

```swift
//
//  CalendarLayoutMath.swift
//  Xisto In Time
//

import Foundation
import SwiftData

/// A session split into per-day visual pieces. A session that doesn't cross
/// midnight produces exactly one segment where `isSessionStart` and
/// `isSessionEnd` are both true. `Session` itself is never split — this is
/// rendering-only.
struct CalendarSessionSegment: Identifiable {
    let id: String
    let session: Session
    let day: Date
    let segmentStart: Date
    let segmentEnd: Date
    let isSessionStart: Bool
    let isSessionEnd: Bool
    let lane: Int
    let laneCount: Int
}

enum CalendarLayoutMath {
    /// Rounds `date` to the nearest multiple of `minutes` since the start of
    /// its own day. `minutes <= 0` returns `date` unchanged (no snap).
    static func snap(_ date: Date, toMinutes minutes: Int, calendar: Calendar = .current) -> Date {
        guard minutes > 0 else { return date }
        let interval = TimeInterval(minutes * 60)
        let dayStart = calendar.startOfDay(for: date)
        let elapsed = date.timeIntervalSince(dayStart)
        let snappedElapsed = (elapsed / interval).rounded() * interval
        return dayStart.addingTimeInterval(snappedElapsed)
    }

    /// Vertical position of `date` within its day's column, `hourHeight` points per hour.
    static func yOffset(for date: Date, day: Date, hourHeight: CGFloat, calendar: Calendar = .current) -> CGFloat {
        let dayStart = calendar.startOfDay(for: day)
        let hours = date.timeIntervalSince(dayStart) / 3600
        return CGFloat(hours) * hourHeight
    }

    /// Inverse of `yOffset` — the `Date` a vertical drag position maps to within `day`.
    static func date(forYOffset y: CGFloat, day: Date, hourHeight: CGFloat, calendar: Calendar = .current) -> Date {
        let dayStart = calendar.startOfDay(for: day)
        let hours = Double(y / hourHeight)
        return dayStart.addingTimeInterval(hours * 3600)
    }

    /// Splits every session touching any of `days` into one segment per day it
    /// touches, and assigns side-by-side lanes to segments that overlap in
    /// time within the same day (overlapping sessions are allowed, just warned
    /// about elsewhere — this only decides how to lay them out visually).
    static func segments(for sessions: [Session], days: [Date], calendar: Calendar = .current) -> [CalendarSessionSegment] {
        struct Raw {
            let day: Date
            let session: Session
            let start: Date
            let end: Date
            let isStart: Bool
            let isEnd: Bool
        }

        var raw: [Raw] = []
        for session in sessions {
            for day in days {
                let dayStart = calendar.startOfDay(for: day)
                guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }
                let segStart = max(session.startedAt, dayStart)
                let segEnd = min(session.endedAt, dayEnd)
                guard segStart < segEnd else { continue }
                raw.append(Raw(
                    day: day,
                    session: session,
                    start: segStart,
                    end: segEnd,
                    isStart: segStart == session.startedAt,
                    isEnd: segEnd == session.endedAt
                ))
            }
        }

        var result: [CalendarSessionSegment] = []
        let byDay = Dictionary(grouping: raw, by: { $0.day.timeIntervalSinceReferenceDate })
        for (_, entries) in byDay {
            let lanes = assignLanes(entries.map { ($0.start, $0.end) })
            let laneCount = (lanes.values.max() ?? 0) + 1
            for (index, entry) in entries.enumerated() {
                result.append(CalendarSessionSegment(
                    id: "\(entry.session.persistentModelID)-\(entry.day.timeIntervalSinceReferenceDate)",
                    session: entry.session,
                    day: entry.day,
                    segmentStart: entry.start,
                    segmentEnd: entry.end,
                    isSessionStart: entry.isStart,
                    isSessionEnd: entry.isEnd,
                    lane: lanes[index] ?? 0,
                    laneCount: laneCount
                ))
            }
        }
        return result.sorted { $0.segmentStart < $1.segmentStart }
    }

    /// Greedy interval-graph-coloring: earliest-start-first, each interval
    /// takes the lowest-numbered lane whose last occupant already ended.
    private static func assignLanes(_ intervals: [(start: Date, end: Date)]) -> [Int: Int] {
        var lanes: [Int: Int] = [:]
        var laneEndTimes: [Date] = []
        let ordered = intervals.enumerated().sorted { $0.element.start < $1.element.start }
        for (index, interval) in ordered {
            if let freeLane = laneEndTimes.firstIndex(where: { $0 <= interval.start }) {
                laneEndTimes[freeLane] = interval.end
                lanes[index] = freeLane
            } else {
                laneEndTimes.append(interval.end)
                lanes[index] = laneEndTimes.count - 1
            }
        }
        return lanes
    }
}
```

- [ ] **Step 2: Build & instalar**

Ficheiro novo, sem consumidores ainda — só tem de compilar.

- [ ] **Step 3: Verificar**

Build limpo, sem warnings. Sem UI para testar ainda (chega nas próximas tarefas).

- [ ] **Step 4: Commit**

```bash
git add "Xisto In Time/Core/CalendarLayoutMath.swift"
git commit -m "feat: CalendarLayoutMath — matemática pura da grelha semanal"
```

---

### Task 6: Aba "Calendário" — scaffold (navegação semanal + grelha vazia)

**Files:**
- Create: `Xisto In Time/UI/CalendarWeekView.swift`
- Modify: `Xisto In Time/UI/MainWindowView.swift:77-102` (enum), `:104-105` (default selection), `:182-197` (switch)

**Interfaces:**
- Consumes: `ReportBuilder.weekDays(containing:showWeekend:)` (existente), `PreferencesKey`/`PreferencesDefault.reportsShowWeekend` e `.calendarSnapMinutes` (Task 1), `SessionRoute` (existente em `MainWindowView.swift`).
- Produces: `CalendarWeekView` — `init(path: Binding<NavigationPath>)`. Consumido por `MainWindowView.detailContent` já nesta tarefa, e por Task 7 (que lhe acrescenta os blocos de sessão).

- [ ] **Step 1: Registar a secção no enum e no switch**

Em `MainWindowSection` (`MainWindowView.swift:77-102`), substituir por:
```swift
enum MainWindowSection: String, CaseIterable, Identifiable {
    case calendar = "Calendário"
    case sessions = "Sessões"
    case projects = "Projectos"
    case tasks = "Tarefas"
    case reports = "Estatísticas"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .calendar: "calendar"
        case .projects: "folder.fill"
        case .tasks: "checklist"
        case .sessions: "list.bullet.clipboard.fill"
        case .reports: "chart.bar.fill"
        }
    }

    var tint: Color {
        switch self {
        case .calendar: .teal
        case .projects: .blue
        case .tasks: .green
        case .sessions: .orange
        case .reports: .purple
        }
    }
}
```

Mudar a selecção por omissão (linha 105) de:
```swift
    @State private var selection: MainWindowSection? = .sessions
```
para:
```swift
    @State private var selection: MainWindowSection? = .calendar
```

No `switch selection` de `detailContent` (linhas 184-196), acrescentar o novo caso:
```swift
        switch selection {
        case .calendar:
            CalendarWeekView(path: $path)
        case .projects:
            ProjectsView(path: $path)
        case .tasks:
            TasksBrowserView(path: $path)
        case .sessions:
            AllSessionsView(path: $path)
        case .reports:
            ReportsView()
        case .none:
            Text("Selecciona uma secção")
                .foregroundStyle(.secondary)
        }
```

- [ ] **Step 2: Escrever o scaffold de `CalendarWeekView`**

```swift
//
//  CalendarWeekView.swift
//  Xisto In Time
//

import SwiftUI
import SwiftData

struct CalendarWeekView: View {
    @Binding var path: NavigationPath

    @Query(sort: \Session.startedAt) private var allSessions: [Session]

    @AppStorage(PreferencesKey.reportsShowWeekend)
    private var showWeekend = PreferencesDefault.reportsShowWeekend
    @AppStorage(PreferencesKey.calendarSnapMinutes)
    private var snapMinutes = PreferencesDefault.calendarSnapMinutes

    @State private var referenceDate = Date()

    private let hourHeight: CGFloat = 56
    private let dayColumnWidth: CGFloat = 130
    private let gutterWidth: CGFloat = 44
    private let headerHeight: CGFloat = 22

    private var days: [Date] {
        ReportBuilder.weekDays(containing: referenceDate, showWeekend: showWeekend)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            weekNavigator

            ScrollView([.vertical, .horizontal]) {
                HStack(alignment: .top, spacing: 0) {
                    timeGutter
                    HStack(alignment: .top, spacing: 1) {
                        ForEach(days, id: \.self) { day in
                            VStack(spacing: 0) {
                                dayHeader(for: day)
                                dayColumn(for: day)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .navigationTitle("Calendário")
    }

    private var weekNavigator: some View {
        HStack {
            Button {
                referenceDate = Calendar.current.date(byAdding: .day, value: -7, to: referenceDate) ?? referenceDate
            } label: {
                Image(systemName: "chevron.left")
            }
            if let first = days.first, let last = days.last {
                Text("Semana de \(first.formatted(date: .abbreviated, time: .omitted)) – \(last.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline.bold())
                    .frame(minWidth: 220)
            }
            Button {
                referenceDate = Calendar.current.date(byAdding: .day, value: 7, to: referenceDate) ?? referenceDate
            } label: {
                Image(systemName: "chevron.right")
            }
            Button("Esta semana") { referenceDate = Date() }
                .font(.caption)
        }
    }

    private var timeGutter: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: headerHeight)
            ForEach(0..<24, id: \.self) { hour in
                Text(String(format: "%02d:00", hour))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: gutterWidth, height: hourHeight, alignment: .top)
            }
        }
    }

    private func dayHeader(for day: Date) -> some View {
        Text(day.formatted(.dateTime.weekday(.abbreviated).day()))
            .font(.caption.bold())
            .frame(height: headerHeight)
    }

    private func dayColumn(for day: Date) -> some View {
        ZStack(alignment: .topLeading) {
            hourGridLines
        }
        .frame(width: dayColumnWidth, height: hourHeight * 24)
        .background(Color.primary.opacity(0.02))
    }

    private var hourGridLines: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { _ in
                Rectangle()
                    .fill(Color.secondary.opacity(0.15))
                    .frame(height: 1)
                    .frame(height: hourHeight, alignment: .top)
            }
        }
    }
}
```

Nota: `allSessions` já está declarado (vai ser usado a partir da Task 7) — deixa o warning de "unused" passar por agora, é resolvido na próxima tarefa.

- [ ] **Step 3: Build & instalar**

Esta tarefa mexe em `MainWindowView.swift`, que tem `navigationDestination` — faz `rm -rf ./build` antes de compilar (regra do CLAUDE.md), depois o build normal.

- [ ] **Step 4: Verificar manualmente**

Abrir a janela principal (clicar no cabeçalho "Xisto" no popover, ou Cmd+Espaço "Xisto"). A sidebar deve mostrar "Calendário" primeiro, com ícone de calendário a teal, **já seleccionado por omissão**. A área de detalhe mostra o navegador de semana ("Semana de ...") e uma grelha vazia com horas 00:00–23:00 na coluna esquerda e 5 ou 7 colunas de dia (conforme a preferência "Mostrar fim-de-semana" em Relatórios/Calendário). Scroll vertical e horizontal devem funcionar. Os botões ‹ › e "Esta semana" devem mudar a semana mostrada.

- [ ] **Step 5: Commit**

```bash
git add "Xisto In Time/UI/CalendarWeekView.swift" "Xisto In Time/UI/MainWindowView.swift"
git commit -m "feat: aba Calendário — navegação semanal e grelha vazia"
```

---

### Task 7: Renderizar sessões como blocos estáticos + duplo clique para editar

**Files:**
- Create: `Xisto In Time/UI/CalendarSessionBlock.swift`
- Modify: `Xisto In Time/UI/CalendarWeekView.swift` (`dayColumn(for:)`, adicionar `visibleSessions`/`segmentsByDay`)

**Interfaces:**
- Consumes: `CalendarLayoutMath.segments(for:days:)`, `CalendarSessionSegment` (Task 5).
- Produces: `CalendarSessionBlock` — `init(segment: CalendarSessionSegment, hourHeight: CGFloat, columnWidth: CGFloat, onOpenEditor: @escaping (Session) -> Void)` (versão estática; os parâmetros de drag chegam na Task 8). Consumido por `CalendarWeekView.dayColumn(for:)`.

- [ ] **Step 1: Adicionar o cálculo de sessões visíveis e segmentos a `CalendarWeekView`**

Depois de `private var days: [Date] { ... }`:
```swift
    private var visibleSessions: [Session] {
        guard let first = days.first, let last = days.last else { return [] }
        let calendar = Calendar.current
        let rangeStart = calendar.startOfDay(for: first)
        guard let rangeEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: last)) else { return [] }
        return allSessions.filter { $0.startedAt < rangeEnd && $0.endedAt > rangeStart }
    }

    private var segmentsByDay: [TimeInterval: [CalendarSessionSegment]] {
        Dictionary(grouping: CalendarLayoutMath.segments(for: visibleSessions, days: days)) { $0.day.timeIntervalSinceReferenceDate }
    }
```

- [ ] **Step 2: Ligar os blocos em `dayColumn(for:)`**

Trocar:
```swift
    private func dayColumn(for day: Date) -> some View {
        ZStack(alignment: .topLeading) {
            hourGridLines
        }
        .frame(width: dayColumnWidth, height: hourHeight * 24)
        .background(Color.primary.opacity(0.02))
    }
```
por:
```swift
    private func dayColumn(for day: Date) -> some View {
        ZStack(alignment: .topLeading) {
            hourGridLines
            ForEach(segmentsByDay[day.timeIntervalSinceReferenceDate] ?? []) { segment in
                CalendarSessionBlock(
                    segment: segment,
                    hourHeight: hourHeight,
                    columnWidth: dayColumnWidth,
                    onOpenEditor: { session in
                        path.append(SessionRoute(id: session.persistentModelID))
                    }
                )
            }
        }
        .frame(width: dayColumnWidth, height: hourHeight * 24)
        .background(Color.primary.opacity(0.02))
    }
```

- [ ] **Step 3: Escrever `CalendarSessionBlock` (versão estática, sem drag)**

```swift
//
//  CalendarSessionBlock.swift
//  Xisto In Time
//

import SwiftUI
import SwiftData

/// Static presentation of one session segment: color, break/unassigned/edited
/// styling, and double-click to open the full editor. Drag-to-move and
/// drag-to-resize are added on top of this in later tasks.
struct CalendarSessionBlock: View {
    let segment: CalendarSessionSegment
    let hourHeight: CGFloat
    let columnWidth: CGFloat
    let onOpenEditor: (Session) -> Void

    private var baseY: CGFloat {
        CalendarLayoutMath.yOffset(for: segment.segmentStart, day: segment.day, hourHeight: hourHeight)
    }

    private var baseHeight: CGFloat {
        max(4, CalendarLayoutMath.yOffset(for: segment.segmentEnd, day: segment.day, hourHeight: hourHeight) - baseY)
    }

    private var laneWidth: CGFloat {
        (columnWidth - 4) / CGFloat(segment.laneCount)
    }

    private var isUnassignedWork: Bool {
        segment.session.kind == .work && segment.session.task == nil
    }

    private var fillColor: Color {
        if segment.session.kind == .break { return Color.gray.opacity(0.35) }
        return (segment.session.task?.project?.color ?? .secondary).opacity(0.55)
    }

    private var borderColor: Color {
        segment.session.task?.project?.color ?? .secondary
    }

    private var title: String {
        if let taskTitle = segment.session.task?.title { return taskTitle }
        return segment.session.kind == .break ? "Pausa" : "Sem atribuição"
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(fillColor)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(borderColor, style: StrokeStyle(lineWidth: isUnassignedWork ? 1 : 0, dash: isUnassignedWork ? [4, 3] : []))
            )
            .overlay(alignment: .topLeading) {
                Text(title)
                    .font(.caption2)
                    .italic(segment.session.editedAt != nil)
                    .lineLimit(1)
                    .padding(3)
            }
            .frame(width: max(20, laneWidth - 2), height: baseHeight)
            .offset(x: CGFloat(segment.lane) * laneWidth + 2, y: baseY)
            .onTapGesture(count: 2) {
                onOpenEditor(segment.session)
            }
    }
}
```

- [ ] **Step 4: Build & instalar**

Não toca em `@Model` nem `navigationDestination` directamente (só usa `SessionRoute` já existente) — não precisa de `rm -rf ./build`.

- [ ] **Step 5: Verificar manualmente**

Com sessões já existentes na semana actual (usar dados reais ou criar algumas via `SessionEditorView`), abrir a aba Calendário: os blocos devem aparecer no dia/hora certos, com a cor do projecto, pausas a cinzento, sessões sem tarefa com contorno tracejado, sessões editadas manualmente em itálico. Duas sessões sobrepostas no mesmo dia devem aparecer lado a lado (lanes), não uma por cima da outra. Duplo clique num bloco deve navegar para o `SessionEditorView` dessa sessão (empurra na `NavigationStack`, tal como a partir de outras listas). Uma sessão que atravesse a meia-noite deve aparecer como dois blocos, um em cada dia.

- [ ] **Step 6: Commit**

```bash
git add "Xisto In Time/UI/CalendarSessionBlock.swift" "Xisto In Time/UI/CalendarWeekView.swift"
git commit -m "feat: renderiza sessões no calendário, duplo clique abre o editor"
```

---

### Task 8: Arrastar para mover

**Files:**
- Modify: `Xisto In Time/UI/CalendarSessionBlock.swift`
- Modify: `Xisto In Time/UI/CalendarWeekView.swift` (`dayColumn(for:)` — passar `overlapCheck`/`onCommit`)

**Interfaces:**
- Consumes: `SessionStore.overlappingSession`, `SessionStore.rescheduleSession`, `SessionStore.describe` (Task 3); `CalendarLayoutMath.snap` (Task 5).
- Produces: `CalendarSessionBlock.init` ganha `snapMinutes: Int`, `overlapCheck: (Date, Date, PersistentIdentifier?) -> Session?`, `onCommit: (Session, Date, Date) -> Void`. Consumido por Task 9 (redimensionar reaproveita o mesmo `onCommit`/`overlapCheck`).

- [ ] **Step 1: Passar as novas dependências a partir de `CalendarWeekView`**

Em `dayColumn(for:)`, no `CalendarSessionBlock(...)`, acrescentar os três parâmetros novos:
```swift
                CalendarSessionBlock(
                    segment: segment,
                    hourHeight: hourHeight,
                    columnWidth: dayColumnWidth,
                    snapMinutes: snapMinutes,
                    overlapCheck: { start, end, excluding in
                        SessionStore.overlappingSession(startedAt: start, endedAt: end, excluding: excluding, in: allSessions)
                    },
                    onCommit: { session, start, end in
                        SessionStore.rescheduleSession(session, startedAt: start, endedAt: end, in: modelContext)
                    },
                    onOpenEditor: { session in
                        path.append(SessionRoute(id: session.persistentModelID))
                    }
                )
```
Adicionar `@Environment(\.modelContext) private var modelContext` a `CalendarWeekView` (ainda não existe nesta view).

- [ ] **Step 2: Reescrever `CalendarSessionBlock` com o gesto de mover**

Substituir o ficheiro inteiro por:
```swift
//
//  CalendarSessionBlock.swift
//  Xisto In Time
//

import SwiftUI
import SwiftData

struct CalendarSessionBlock: View {
    let segment: CalendarSessionSegment
    let hourHeight: CGFloat
    let columnWidth: CGFloat
    let snapMinutes: Int
    let overlapCheck: (Date, Date, PersistentIdentifier?) -> Session?
    let onCommit: (Session, Date, Date) -> Void
    let onOpenEditor: (Session) -> Void

    @State private var moveTranslation: CGSize = .zero
    @State private var isOverlapping = false
    @State private var showingOverlapAlert = false
    @State private var overlapDescription = ""
    @State private var showingLongDurationAlert = false
    @State private var pendingStart = Date()
    @State private var pendingEnd = Date()

    /// Multi-day sessions only move vertically within their own segment —
    /// moving one horizontally would be ambiguous about which day "wins".
    private var canMoveAcrossDays: Bool { segment.isSessionStart && segment.isSessionEnd }

    private var baseY: CGFloat {
        CalendarLayoutMath.yOffset(for: segment.segmentStart, day: segment.day, hourHeight: hourHeight)
    }

    private var baseHeight: CGFloat {
        max(4, CalendarLayoutMath.yOffset(for: segment.segmentEnd, day: segment.day, hourHeight: hourHeight) - baseY)
    }

    private var laneWidth: CGFloat {
        (columnWidth - 4) / CGFloat(segment.laneCount)
    }

    private var isUnassignedWork: Bool {
        segment.session.kind == .work && segment.session.task == nil
    }

    private var fillColor: Color {
        if segment.session.kind == .break { return Color.gray.opacity(0.35) }
        return (segment.session.task?.project?.color ?? .secondary).opacity(0.55)
    }

    private var borderColor: Color {
        isOverlapping ? .red : (segment.session.task?.project?.color ?? .secondary)
    }

    private var title: String {
        if let taskTitle = segment.session.task?.title { return taskTitle }
        return segment.session.kind == .break ? "Pausa" : "Sem atribuição"
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(fillColor)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(borderColor, style: StrokeStyle(lineWidth: isOverlapping ? 2 : (isUnassignedWork ? 1 : 0), dash: (!isOverlapping && isUnassignedWork) ? [4, 3] : []))
            )
            .overlay(alignment: .topLeading) {
                Text(title)
                    .font(.caption2)
                    .italic(segment.session.editedAt != nil)
                    .lineLimit(1)
                    .padding(3)
            }
            .frame(width: max(20, laneWidth - 2), height: baseHeight)
            .offset(x: CGFloat(segment.lane) * laneWidth + 2 + (canMoveAcrossDays ? moveTranslation.width : 0), y: baseY + moveTranslation.height)
            .onTapGesture(count: 2) {
                onOpenEditor(segment.session)
            }
            .gesture(moveGesture)
            .alert("Sobreposição de sessões", isPresented: $showingOverlapAlert) {
                Button("Cancelar", role: .cancel) { resetTranslation() }
                Button("Continuar mesmo assim") { checkDurationThenCommit() }
            } message: {
                Text("Esta sessão sobrepõe-se a: \(overlapDescription)")
            }
            .alert("Sessão muito longa", isPresented: $showingLongDurationAlert) {
                Button("Cancelar", role: .cancel) { resetTranslation() }
                Button("Continuar mesmo assim") { commit() }
            } message: {
                Text("Esta sessão passaria a durar mais de 12 horas. Tens a certeza?")
            }
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                moveTranslation = canMoveAcrossDays ? value.translation : CGSize(width: 0, height: value.translation.height)
                let (start, end) = candidateRange()
                isOverlapping = overlapCheck(start, end, segment.session.persistentModelID) != nil
            }
            .onEnded { _ in
                let (start, end) = candidateRange()
                finishDrag(newStart: start, newEnd: end)
            }
    }

    /// Translation → candidate (start, end), snapped and clamped to never land in the future.
    private func candidateRange() -> (Date, Date) {
        let calendar = Calendar.current
        let dayDelta = canMoveAcrossDays ? Int((moveTranslation.width / columnWidth).rounded()) : 0
        let timeDeltaSeconds = Double(moveTranslation.height / hourHeight) * 3600
        let duration = segment.session.endedAt.timeIntervalSince(segment.session.startedAt)

        let shifted = segment.session.startedAt.addingTimeInterval(timeDeltaSeconds)
        let dayShifted = calendar.date(byAdding: .day, value: dayDelta, to: shifted) ?? shifted
        let snapped = CalendarLayoutMath.snap(dayShifted, toMinutes: snapMinutes, calendar: calendar)
        let clampedStart = min(snapped, Date().addingTimeInterval(-duration))
        return (clampedStart, clampedStart.addingTimeInterval(duration))
    }

    private func finishDrag(newStart: Date, newEnd: Date) {
        guard newStart != segment.session.startedAt || newEnd != segment.session.endedAt else {
            resetTranslation()
            return
        }
        pendingStart = newStart
        pendingEnd = newEnd
        if let overlapping = overlapCheck(newStart, newEnd, segment.session.persistentModelID) {
            overlapDescription = SessionStore.describe(overlapping)
            showingOverlapAlert = true
            return
        }
        checkDurationThenCommit()
    }

    private func checkDurationThenCommit() {
        if pendingEnd.timeIntervalSince(pendingStart) > 12 * 3600 {
            showingLongDurationAlert = true
            return
        }
        commit()
    }

    private func commit() {
        onCommit(segment.session, pendingStart, pendingEnd)
        resetTranslation()
    }

    private func resetTranslation() {
        moveTranslation = .zero
        isOverlapping = false
    }
}
```

- [ ] **Step 3: Build & instalar**

- [ ] **Step 4: Verificar manualmente**

Arrastar um bloco de sessão dentro do mesmo dia (muda a hora) e para outro dia (muda o dia) — a duração mantém-se. Ao arrastar por cima de outra sessão, o bloco deve ficar com contorno vermelho enquanto arrastas; ao soltar em cima dela, deve aparecer o alerta "Sobreposição de sessões" com "Continuar mesmo assim"/"Cancelar" — cancelar tem de repor a posição original sem gravar nada (confirmar saindo e voltando à aba). Arrastar uma sessão que atravessa a meia-noite: só se deve mexer verticalmente (mudar hora), nunca mudar de dia. Tentar arrastar uma sessão para o futuro (mais tarde que "agora") deve ficar travado em "agora", sem alerta. Confirmar que o `editedAt` fica marcado (itálico) depois de mover.

- [ ] **Step 5: Commit**

```bash
git add "Xisto In Time/UI/CalendarSessionBlock.swift" "Xisto In Time/UI/CalendarWeekView.swift"
git commit -m "feat: arrastar sessões no calendário para as mover"
```

---

### Task 9: Arrastar para redimensionar

**Files:**
- Modify: `Xisto In Time/UI/CalendarSessionBlock.swift`

**Interfaces:**
- Consumes: mesmos `overlapCheck`/`onCommit` de Task 8 — sem mudança de assinatura em `CalendarWeekView`.

- [ ] **Step 1: Adicionar estado e handles de redimensionar**

Em `CalendarSessionBlock`, acrescentar aos `@State` existentes:
```swift
    @State private var resizeTopTranslation: CGFloat = 0
    @State private var resizeBottomTranslation: CGFloat = 0
```

Actualizar `baseHeight`'s uso no `.frame` e no `.offset` do `body` para reflectir o redimensionamento em curso, e acrescentar os handles. Trocar:
```swift
            .frame(width: max(20, laneWidth - 2), height: baseHeight)
            .offset(x: CGFloat(segment.lane) * laneWidth + 2 + (canMoveAcrossDays ? moveTranslation.width : 0), y: baseY + moveTranslation.height)
            .onTapGesture(count: 2) {
                onOpenEditor(segment.session)
            }
            .gesture(moveGesture)
```
por:
```swift
            .frame(width: max(20, laneWidth - 2), height: max(4, baseHeight - resizeTopTranslation + resizeBottomTranslation))
            .offset(x: CGFloat(segment.lane) * laneWidth + 2 + (canMoveAcrossDays ? moveTranslation.width : 0), y: baseY + resizeTopTranslation + moveTranslation.height)
            .onTapGesture(count: 2) {
                onOpenEditor(segment.session)
            }
            .gesture(moveGesture)
            .overlay(alignment: .top) {
                if segment.isSessionStart {
                    resizeHandle(gesture: topResizeGesture)
                }
            }
            .overlay(alignment: .bottom) {
                if segment.isSessionEnd {
                    resizeHandle(gesture: bottomResizeGesture)
                }
            }
```

- [ ] **Step 2: Handle visual e gestos**

Acrescentar estes métodos à struct (perto de `moveGesture`):
```swift
    private func resizeHandle(gesture: some Gesture) -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: 8)
            .contentShape(Rectangle())
            .overlay(Capsule().fill(Color.primary.opacity(0.25)).frame(width: 24, height: 3))
            .gesture(gesture)
    }

    private var topResizeGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                resizeTopTranslation = value.translation.height
                let (start, end) = topCandidateRange()
                isOverlapping = overlapCheck(start, end, segment.session.persistentModelID) != nil
            }
            .onEnded { _ in
                let (start, end) = topCandidateRange()
                finishDrag(newStart: start, newEnd: end)
            }
    }

    private var bottomResizeGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                resizeBottomTranslation = value.translation.height
                let (start, end) = bottomCandidateRange()
                isOverlapping = overlapCheck(start, end, segment.session.persistentModelID) != nil
            }
            .onEnded { _ in
                let (start, end) = bottomCandidateRange()
                finishDrag(newStart: start, newEnd: end)
            }
    }

    private func topCandidateRange() -> (Date, Date) {
        let calendar = Calendar.current
        let timeDeltaSeconds = Double(resizeTopTranslation / hourHeight) * 3600
        let raw = segment.session.startedAt.addingTimeInterval(timeDeltaSeconds)
        let snapped = CalendarLayoutMath.snap(raw, toMinutes: snapMinutes, calendar: calendar)
        let latestAllowedStart = segment.session.endedAt.addingTimeInterval(-TimeInterval(max(snapMinutes, 1) * 60))
        return (min(snapped, latestAllowedStart), segment.session.endedAt)
    }

    private func bottomCandidateRange() -> (Date, Date) {
        let calendar = Calendar.current
        let timeDeltaSeconds = Double(resizeBottomTranslation / hourHeight) * 3600
        let raw = segment.session.endedAt.addingTimeInterval(timeDeltaSeconds)
        let snapped = CalendarLayoutMath.snap(raw, toMinutes: snapMinutes, calendar: calendar)
        let earliestAllowedEnd = segment.session.startedAt.addingTimeInterval(TimeInterval(max(snapMinutes, 1) * 60))
        let clamped = max(snapped, earliestAllowedEnd)
        return (segment.session.startedAt, min(clamped, Date()))
    }
```

- [ ] **Step 3: Repor o redimensionamento junto com o resto em `resetTranslation()`**

Trocar:
```swift
    private func resetTranslation() {
        moveTranslation = .zero
        isOverlapping = false
    }
```
por:
```swift
    private func resetTranslation() {
        moveTranslation = .zero
        resizeTopTranslation = 0
        resizeBottomTranslation = 0
        isOverlapping = false
    }
```

- [ ] **Step 4: Build & instalar**

- [ ] **Step 5: Verificar manualmente**

Numa sessão de um único dia, arrastar a borda de cima para trás/frente muda só a hora de início (fim fica fixo); arrastar a borda de baixo muda só o fim. Não deve ser possível arrastar um extremo para lá do outro (a duração nunca fica ≤ 0). Numa sessão dividida pela meia-noite, o handle de cima só aparece no segmento do primeiro dia, o de baixo só no do segundo. Overlap/duração longa disparam os mesmos alertas do Task 8.

- [ ] **Step 6: Commit**

```bash
git add "Xisto In Time/UI/CalendarSessionBlock.swift"
git commit -m "feat: redimensionar sessões no calendário arrastando os extremos"
```

---

### Task 10: Sessão a decorrer

**Files:**
- Create: `Xisto In Time/UI/CalendarRunningBlock.swift`
- Modify: `Xisto In Time/UI/CalendarWeekView.swift` (`dayColumn(for:)`, novo `@Environment(TimerEngine.self)`, ticker)

**Interfaces:**
- Consumes: `TimerEngine.isRunning`, `.currentStartedAt` (Task 4), `.currentKind`, `.currentTask`; `CalendarLayoutMath.yOffset` (Task 5).

- [ ] **Step 1: Escrever `CalendarRunningBlock`**

```swift
//
//  CalendarRunningBlock.swift
//  Xisto In Time
//

import SwiftUI

/// Not backed by a `Session` — the running session only becomes one when it
/// stops (`SessionStore.recordFinishedSession`). Rendered from `TimerEngine`'s
/// live state instead, growing until "now". Never draggable.
struct CalendarRunningBlock: View {
    let day: Date
    let startedAt: Date
    let kind: SessionKind
    let taskTitle: String?
    let projectColor: Color?
    let now: Date
    let hourHeight: CGFloat

    private var y: CGFloat {
        CalendarLayoutMath.yOffset(for: startedAt, day: day, hourHeight: hourHeight)
    }

    private var height: CGFloat {
        max(4, CalendarLayoutMath.yOffset(for: now, day: day, hourHeight: hourHeight) - y)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill((projectColor ?? .accentColor).opacity(0.35))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(projectColor ?? .accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            )
            .overlay(alignment: .topLeading) {
                Text(taskTitle ?? (kind == .break ? "Pausa a decorrer" : "A decorrer…"))
                    .font(.caption2)
                    .padding(3)
            }
            .padding(.horizontal, 2)
            .frame(height: height)
            .offset(y: y)
    }
}
```

- [ ] **Step 2: Ligar em `CalendarWeekView`**

Adicionar ao topo da struct:
```swift
    @Environment(TimerEngine.self) private var timerEngine
    @State private var runningTick = Date()
```

Em `dayColumn(for:)`, depois do `ForEach(segmentsByDay[...])`:
```swift
            if timerEngine.isRunning, let startedAt = timerEngine.currentStartedAt, Calendar.current.isDate(startedAt, inSameDayAs: day) {
                CalendarRunningBlock(
                    day: day,
                    startedAt: startedAt,
                    kind: timerEngine.currentKind,
                    taskTitle: timerEngine.currentTask?.title,
                    projectColor: timerEngine.currentTask?.project?.color,
                    now: runningTick,
                    hourHeight: hourHeight
                )
            }
```

No `body`, depois de `.navigationTitle("Calendário")`:
```swift
            .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { date in
                runningTick = date
            }
```

- [ ] **Step 3: Build & instalar**

- [ ] **Step 4: Verificar manualmente**

Começar uma sessão (popover → Começar). Abrir a aba Calendário: deve aparecer um bloco tracejado a crescer a partir da hora de início até "agora" (actualiza a cada ~30s, não precisa de ser ao segundo), sem handles de redimensionar nem reagir a arrasto. Parar a sessão — o bloco tracejado desaparece e passa a aparecer como um bloco normal (sólido, arrastável) assim que a sessão é gravada.

- [ ] **Step 5: Commit**

```bash
git add "Xisto In Time/UI/CalendarRunningBlock.swift" "Xisto In Time/UI/CalendarWeekView.swift"
git commit -m "feat: mostra a sessão a decorrer no calendário"
```

---

## Nota final

As tarefas 1–7 dão uma vista de calendário totalmente funcional e navegável, só sem interactividade de arrasto. As tarefas 8–9 são as de maior risco de UX (afinar hit-testing dos handles, sensação do snap) — depois de cada uma, usa a app durante um dia normal antes de avançar, como o CLAUDE.md pede para features novas de risco.
