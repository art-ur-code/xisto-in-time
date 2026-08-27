# Tipo de Sessão "Plano" — Plano de Implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Acrescentar `SessionKind.plan` — um terceiro tipo de sessão para planear o dia, editável só à mão (nunca "a contar"), que pode ter datas no futuro, sobrepor-se em silêncio a Trabalho/Pausa, e aparece no calendário a amarelo (`#FAE588`).

**Architecture:** Alteração aditiva ao enum `SessionKind` (persiste como `String`, sem migração). A regra de sobreposição, já centralizada em `SessionStore.overlappingSession` (extraída num branch anterior), ganha um parâmetro `kind` e passa a ser a única fonte de verdade da regra "Plano vs resto = silencioso". `SessionEditorView` e `CalendarSessionBlock` tornam a sua validação de "datas no futuro" condicional ao tipo, cada um no seu próprio caminho de código (não há um sítio partilhado para essa regra específica).

**Tech Stack:** Swift 6 / SwiftUI / SwiftData, macOS 26 SDK, sem dependências externas.

**Spec:** `docs/superpowers/specs/2026-08-27-plan-session-kind-design.md`

## Global Constraints

- Sem testes automatizados neste projecto — verificação é build Release com zero avisos, seguida de confirmação manual do utilizador (não é possível testar UI/arrasto ao vivo neste ambiente de execução).
- Comentários/identificadores em inglês, mensagens de commit em português.
- Build (Release): `xcodebuild -project "Xisto In Time.xcodeproj" -scheme "Xisto In Time" -configuration Release -destination 'platform=macOS' -derivedDataPath ./build build`
- Instalar/correr: `pkill -f "Xisto In Time"; rm -rf "$HOME/Applications/Xisto In Time.app"; cp -R "./build/Build/Products/Release/Xisto In Time.app" "$HOME/Applications/"; /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f "$HOME/Applications/Xisto In Time.app"; open "$HOME/Applications/Xisto In Time.app"`
- Nenhuma tarefa deste plano cria/move sessões reais na base de dados como forma de testar — a base de dados é a do utilizador em produção (caminho fixo, sem separação teste/produção, com incidente de perda de dados já documentado no CLAUDE.md). Verificação por leitura de código, não por manipular dados reais.
- Fora de âmbito (ver spec): iniciar Plano "ao vivo" (popover/TimerEngine/Pomodoro), `CalendarRunningBlock`, `ReportBuilder`/Relatórios — nenhum destes ficheiros é tocado por este plano.

---

### Task 1: Modelo — acrescentar `SessionKind.plan`

**Files:**
- Modify: `Xisto In Time/Models/Session.swift:11-14`

**Interfaces:**
- Produces: `SessionKind.plan` (caso novo do enum existente). Consumido pelas Tasks 2, 3 e 4.

- [ ] **Step 1: Acrescentar o caso ao enum**

Em `Xisto In Time/Models/Session.swift`, trocar:
```swift
enum SessionKind: String, Codable {
    case work
    case `break`
}
```
por:
```swift
enum SessionKind: String, Codable {
    case work
    case `break`
    case plan
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild -project "Xisto In Time.xcodeproj" -scheme "Xisto In Time" -configuration Release -destination 'platform=macOS' -derivedDataPath ./build build
```
Esperado: `** BUILD SUCCEEDED **`, zero avisos. Alteração puramente aditiva a um enum `String, Codable` — não há `switch` exaustivo sobre `SessionKind` em nenhum sítio do código actual (confirmado por grep antes deste plano), por isso nada parte.

- [ ] **Step 3: Commit**

```bash
git add "Xisto In Time/Models/Session.swift"
git commit -m "feat: acrescenta SessionKind.plan ao modelo"
```

---

### Task 2: Editor de sessões — Picker "Plano" + datas futuras permitidas

**Files:**
- Modify: `Xisto In Time/UI/SessionEditorView.swift:60-64` (Picker), `:148-152` (validação de datas futuras)

**Interfaces:**
- Consumes: `SessionKind.plan` (Task 1)

- [ ] **Step 1: Acrescentar a opção "Plano" ao Picker de tipo**

Trocar:
```swift
Picker("Tipo", selection: $kind) {
    Text("Trabalho").tag(SessionKind.work)
    Text("Pausa").tag(SessionKind.break)
}
.pickerStyle(.segmented)
```
por:
```swift
Picker("Tipo", selection: $kind) {
    Text("Trabalho").tag(SessionKind.work)
    Text("Pausa").tag(SessionKind.break)
    Text("Plano").tag(SessionKind.plan)
}
.pickerStyle(.segmented)
```

- [ ] **Step 2: Tornar a validação de datas futuras condicional ao tipo**

Em `attemptSave()`, trocar:
```swift
        let now = Date()
        guard startedAt <= now, endedAt <= now else {
            errorMessage = "Não podes usar datas no futuro."
            return
        }
```
por:
```swift
        if kind != .plan {
            let now = Date()
            guard startedAt <= now, endedAt <= now else {
                errorMessage = "Não podes usar datas no futuro."
                return
            }
        }
```

- [ ] **Step 3: Build**

Mesmo comando do Task 1. Esperado: `** BUILD SUCCEEDED **`, zero avisos.

- [ ] **Step 4: Verificar manualmente**

Abrir o editor de sessões (janela principal → Sessões → criar/editar). O Picker "Tipo" mostra agora três opções: Trabalho, Pausa, Plano. Seleccionar "Plano" e escolher uma data/hora no futuro (ex.: amanhã) — deve gravar sem o erro "Não podes usar datas no futuro.". Seleccionar "Trabalho" ou "Pausa" com data no futuro continua a mostrar esse erro, como antes.

- [ ] **Step 5: Commit**

```bash
git add "Xisto In Time/UI/SessionEditorView.swift"
git commit -m "feat: editor de sessões — opção Plano e datas futuras permitidas"
```

---

### Task 3: Sobreposição — `SessionStore.overlappingSession` ganha `kind`

**Files:**
- Modify: `Xisto In Time/Core/SessionStore.swift:73-85`
- Modify: `Xisto In Time/UI/SessionEditorView.swift:154` (chamada)
- Modify: `Xisto In Time/UI/CalendarWeekView.swift:190-192` (chamada, dentro do closure `overlapCheck`)

**Interfaces:**
- Consumes: `SessionKind.plan` (Task 1)
- Produces: nova assinatura `SessionStore.overlappingSession(startedAt:endedAt:excluding:kind:in:) -> Session?` — quebra a assinatura antiga (`overlappingSession(startedAt:endedAt:excluding:in:)`, sem `kind`), por isso os dois chamadores têm de ser actualizados na mesma tarefa para o build não partir.

- [ ] **Step 1: Acrescentar o parâmetro `kind` e a regra de silêncio Plano↔resto**

Em `Xisto In Time/Core/SessionStore.swift`, trocar:
```swift
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
```
por:
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
            // Plano sobrepõe-se em silêncio a Trabalho/Pausa — é o
            // comportamento esperado ao planear em cima do que se vai
            // fazer. Trabalho↔Trabalho, Pausa↔Pausa e Plano↔Plano
            // continuam a avisar como antes.
            let exactlyOnePlan = (kind == .plan) != (candidate.kind == .plan)
            return !exactlyOnePlan
        }
    }
```

- [ ] **Step 2: Actualizar a chamada em `SessionEditorView`**

Em `attemptSave()`, trocar:
```swift
        if let overlapping = SessionStore.overlappingSession(startedAt: startedAt, endedAt: endedAt, excluding: existingSession?.persistentModelID, in: allSessions) {
```
por:
```swift
        if let overlapping = SessionStore.overlappingSession(startedAt: startedAt, endedAt: endedAt, excluding: existingSession?.persistentModelID, kind: kind, in: allSessions) {
```
(`kind` é o `@State private var kind: SessionKind` já existente, reflecte a opção seleccionada no Picker no momento de gravar.)

- [ ] **Step 3: Actualizar a chamada em `CalendarWeekView`**

No closure `overlapCheck` passado a `CalendarSessionBlock` dentro de `dayColumn(for:)`, trocar:
```swift
                    overlapCheck: { start, end, excluding in
                        SessionStore.overlappingSession(startedAt: start, endedAt: end, excluding: excluding, in: allSessions)
                    },
```
por:
```swift
                    overlapCheck: { start, end, excluding in
                        SessionStore.overlappingSession(startedAt: start, endedAt: end, excluding: excluding, kind: segment.session.kind, in: allSessions)
                    },
```
(`segment` já está em scope aqui — é a variável do `ForEach(segmentsByDay[...])` que envolve esta construção de `CalendarSessionBlock`. Não é preciso mudar o tipo do closure `overlapCheck` em `CalendarSessionBlock.swift` — `segment.session.kind` fica capturado no momento em que o closure é criado, uma vez por bloco.)

- [ ] **Step 4: Build**

Mesmo comando das tarefas anteriores. Esperado: `** BUILD SUCCEEDED **`, zero avisos. Se faltar actualizar algum dos dois chamadores, o build falha por assinatura errada — sinal de que este passo ficou incompleto.

- [ ] **Step 5: Verificar manualmente**

No editor de sessões: criar uma sessão "Plano" com um intervalo que se sobrepõe a uma sessão "Trabalho" já existente — deve gravar **sem** o alerta "Sobreposição de sessões". Criar duas sessões "Trabalho" sobrepostas continua a mostrar o alerta, como antes. (Não testar isto arrastando no calendário — ver a nota de segurança de dados nas Global Constraints; usar apenas o editor, que já pede confirmação explícita ao gravar.)

- [ ] **Step 6: Commit**

```bash
git add "Xisto In Time/Core/SessionStore.swift" "Xisto In Time/UI/SessionEditorView.swift" "Xisto In Time/UI/CalendarWeekView.swift"
git commit -m "feat: sobreposição Plano vs Trabalho/Pausa fica silenciosa"
```

---

### Task 4: Calendário — cor, rótulo e datas futuras do Plano

**Files:**
- Modify: `Xisto In Time/UI/CalendarSessionBlock.swift:49-61` (`fillColor`, `title`), `:215-218` (`finishDrag`)

**Interfaces:**
- Consumes: `SessionKind.plan` (Task 1)

- [ ] **Step 1: `fillColor` — ramo explícito para Plano**

Trocar:
```swift
    private var fillColor: Color {
        if segment.session.kind == .break { return Color.gray.opacity(0.35) }
        return (segment.session.task?.project?.color ?? .secondary).opacity(0.55)
    }
```
por:
```swift
    private var fillColor: Color {
        switch segment.session.kind {
        case .break: return Color.gray.opacity(0.35)
        case .plan: return Color(hex: "FAE588").opacity(0.85)
        case .work: return (segment.session.task?.project?.color ?? .secondary).opacity(0.55)
        }
    }
```

- [ ] **Step 2: `title` — rótulo "Plano" quando sem tarefa, sem tracejado**

Trocar:
```swift
    private var title: String {
        if let taskTitle = segment.session.task?.title { return taskTitle }
        return segment.session.kind == .break ? "Pausa" : "Sem atribuição"
    }
```
por:
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

`isUnassignedWork` (contorno tracejado) não muda — continua `segment.session.kind == .work && segment.session.task == nil`, por isso um Plano sem tarefa nunca fica tracejado, como pedido.

- [ ] **Step 3: `finishDrag` — permitir Plano no futuro**

Trocar:
```swift
        guard newEnd <= Date() else {
            showingFutureAlert = true
            return
        }
```
por:
```swift
        if segment.session.kind != .plan, newEnd > Date() {
            showingFutureAlert = true
            return
        }
```

- [ ] **Step 4: Build**

Mesmo comando das tarefas anteriores. Esperado: `** BUILD SUCCEEDED **`, zero avisos.

- [ ] **Step 5: Verificar manualmente**

Com a sessão "Plano" criada na Task 2/3 (a que tem data futura), abrir a aba Calendário e navegar até ao dia correspondente (botões ‹ › ou "Agora"): o bloco deve aparecer a amarelo (`#FAE588`), sem contorno tracejado mesmo que não tenha tarefa atribuída, com o texto "Plano" se não tiver tarefa. Arrastar essa sessão para outro dia/hora ainda no futuro deve funcionar sem o alerta "Não é possível mover para o futuro"; arrastar uma sessão de Trabalho ou Pausa para o futuro continua a mostrar esse alerta.

- [ ] **Step 6: Commit**

```bash
git add "Xisto In Time/UI/CalendarSessionBlock.swift"
git commit -m "feat: calendário mostra Plano a amarelo e permite datas futuras"
```

---

## Nota final

Depois da Task 4, todos os pontos da spec estão cobertos excepto os explicitamente fora de âmbito (comparação planeado vs executado, Plano ao vivo, Relatórios). Como não há suite de testes automatizada, o utilizador deve confirmar à mão os pontos de verificação de cada tarefa antes de considerar isto fechado — em particular o comportamento de arrastar no calendário, que este ambiente de execução não consegue testar directamente.
