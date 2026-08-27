# Theme Picker (Light/Dark/System) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Claro/Escuro/Sistema picker to Preferências → Geral that overrides the app's appearance live, across all 4 windows/panels, building on the `Theme` design-token system (v1.23.0).

**Architecture:** A new `AppTheme` preference (default `.system`, preserving current behavior) plus one function, `Theme.syncAppAppearance()`, that sets `NSApplication.shared.appearance` — AppKit propagates this to every window/panel that doesn't define its own `appearance` (confirmed: none of the app's 4 do). `Theme.Color.dynamic(light:dark:)` already resolves against the current drawing context's appearance, so it needs no changes.

**Tech Stack:** SwiftUI / AppKit (macOS 26 SDK, macOS 14 deployment target). No third-party dependencies. No automated test suite in this project (standing decision).

**Spec:** `docs/superpowers/specs/2026-08-27-theme-picker-design.md`

## Global Constraints

- No automated test suite. Every task's verification is: `xcodebuild -scheme "Xisto In Time" -configuration Release build` with **zero warnings**, plus — where the task changes visible behavior — a manual check the user performs (this environment has no reliable GUI automation for this app's borderless panels).
- Default value must be `.system`, preserving today's 100%-follow-system behavior for existing users — zero migration.
- Follow the existing `Core/Preferences.swift` enum-preference pattern exactly (see `IdleResolutionMode`) — don't invent a new pattern.
- Commits: one commit per task, Portuguese message, following existing project convention.

---

### Task 1: `AppTheme` preference + `Theme.syncAppAppearance()`

**Files:**
- Modify: `Xisto In Time/Core/Preferences.swift`
- Modify: `Xisto In Time/Core/Theme.swift`

**Interfaces:**
- Produces: `AppTheme` (enum, `String, CaseIterable, Identifiable`, cases `.light`/`.dark`/`.system`, computed `label: String`) — Task 2 consumes this as the `Picker`'s selection type.
- Produces: `PreferencesKey.appTheme: String`, `PreferencesDefault.appTheme: AppTheme` — Task 2 consumes both directly in `@AppStorage(PreferencesKey.appTheme) private var appTheme = PreferencesDefault.appTheme`.
- Produces: `Preferences.appTheme() -> AppTheme` (typed reader) — consumed by `Theme.syncAppAppearance()` in this same task, and by Task 2's call site in `Xisto_In_TimeApp.swift`.
- Produces: `Theme.syncAppAppearance()` (a `static func`, no params, no return) — Task 2 calls this from two places (app launch, and the Picker's `.onChange`).

- [ ] **Step 1: Add the `AppTheme` enum to `Preferences.swift`**

Open `Xisto In Time/Core/Preferences.swift`. Find the existing `IdleResolutionMode` enum (it looks like this — for reference, don't change it):

```swift
enum IdleResolutionMode: String, CaseIterable, Identifiable {
    case ask
    case autoDiscard
    case notifyOnly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ask: "Perguntar"
        case .autoDiscard: "Descartar automaticamente"
        case .notifyOnly: "Apenas notificar"
        }
    }
}
```

Right after it, add:

```swift
enum AppTheme: String, CaseIterable, Identifiable {
    case light
    case dark
    case system

    var id: String { rawValue }

    var label: String {
        switch self {
        case .light: "Claro"
        case .dark: "Escuro"
        case .system: "Sistema"
        }
    }
}
```

- [ ] **Step 2: Add the key and default**

In the `PreferencesKey` enum, alongside the existing `idleResolutionMode` key, add:

```swift
    static let appTheme = "appTheme"
```

In the `PreferencesDefault` enum, alongside the existing `idleResolutionMode` default, add:

```swift
    static let appTheme = AppTheme.system
```

- [ ] **Step 3: Add the typed reader**

In the `Preferences` enum, find the existing `idleResolutionMode()` reader (for reference):

```swift
    static func idleResolutionMode() -> IdleResolutionMode {
        guard let raw = UserDefaults.standard.string(forKey: PreferencesKey.idleResolutionMode),
              let mode = IdleResolutionMode(rawValue: raw) else {
            return PreferencesDefault.idleResolutionMode
        }
        return mode
    }
```

Right after it, add:

```swift
    static func appTheme() -> AppTheme {
        guard let raw = UserDefaults.standard.string(forKey: PreferencesKey.appTheme),
              let theme = AppTheme(rawValue: raw) else {
            return PreferencesDefault.appTheme
        }
        return theme
    }
```

- [ ] **Step 4: Add `Theme.syncAppAppearance()` to `Theme.swift`**

Open `Xisto In Time/Core/Theme.swift`. At the very end of the file, after the closing brace of `enum Theme { ... }`, add:

```swift

extension Theme {
    /// Applies the user's theme preference to the whole app. None of the
    /// app's 4 windows/panels (main window, menu-bar popover, the shared
    /// Pomodoro/Idle overlay panel, and Settings itself) define their own
    /// `appearance` — AppKit propagates this to all of them automatically.
    /// `Theme.Color.dynamic(light:dark:)` already resolves against the
    /// current drawing context's appearance, so it needs no changes.
    ///
    /// `@MainActor` because `NSApplication.shared` is main-actor-isolated
    /// under Swift 6 strict concurrency (this project's mode) — both call
    /// sites (`Xisto_In_TimeApp.init()`, a SwiftUI `.onChange` closure)
    /// already run on the main actor, so this costs nothing there.
    @MainActor
    static func syncAppAppearance() {
        let appearance: NSAppearance?
        switch Preferences.appTheme() {
        case .light: appearance = NSAppearance(named: .aqua)
        case .dark: appearance = NSAppearance(named: .darkAqua)
        case .system: appearance = nil
        }
        NSApplication.shared.appearance = appearance
    }
}
```

`Theme.swift` already `import AppKit`, so `NSApplication`/`NSAppearance` are available without a new import.

- [ ] **Step 5: Build**

Run: `xcodebuild -scheme "Xisto In Time" -configuration Release build`
Expected: `** BUILD SUCCEEDED **`, zero warnings. Nothing calls `Theme.syncAppAppearance()` yet, and no UI exposes `AppTheme`, so this task has no visible effect — it only proves the new code compiles and the pattern matches `IdleResolutionMode`'s exactly.

- [ ] **Step 6: Commit**

```bash
git add "Xisto In Time/Core/Preferences.swift" "Xisto In Time/Core/Theme.swift"
git commit -m "$(cat <<'EOF'
feat: preferência AppTheme e Theme.syncAppAppearance()

Ainda não é chamado em lado nenhum — só a base. Segue exactamente
o padrão de IdleResolutionMode já existente.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Wire it up — apply at launch, expose in Preferências

**Files:**
- Modify: `Xisto In Time/Xisto_In_TimeApp.swift:26` (start of `init()`)
- Modify: `Xisto In Time/UI/SettingsView.swift` (`GeneralSettingsPane`)

**Interfaces:**
- Consumes: `Theme.syncAppAppearance()`, `AppTheme`, `PreferencesKey.appTheme`, `PreferencesDefault.appTheme` (Task 1).

- [ ] **Step 1: Apply the saved theme at launch, before any window/panel is created**

Open `Xisto In Time/Xisto_In_TimeApp.swift`. The `struct` conforming to `App` has an `init()` starting at line 26; its first statement today is `let schema = ...`. Add one line immediately after `init() {` and before that first statement:

```swift
    init() {
        Theme.syncAppAppearance()
        let schema = ...
```

(Keep everything else in `init()` exactly as it is — this is the only change to this file. `OverlayController`'s property initializer runs before `init()`'s body per Swift's initialization order, but it only creates the controller object, not a window — no panel actually opens until `MenuBarController` is constructed later in this same `init()`, so this ordering still guarantees the appearance is set before the first window/panel appears.)

- [ ] **Step 2: Add the Picker to `GeneralSettingsPane`**

Open `Xisto In Time/UI/SettingsView.swift`. Find `GeneralSettingsPane` (currently lines 51-72) — it looks like this today (for reference):

```swift
private struct GeneralSettingsPane: View {
    @AppStorage(PreferencesKey.notePreviewSize)
    private var notePreviewSize = PreferencesDefault.notePreviewSize

    var body: some View {
        Form {
            Section("Listas de sessões") {
                Picker("Preview da nota", selection: $notePreviewSize) {
                    ForEach(NotePreviewSize.allCases) { size in
                        Text(size.label).tag(size)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
```

Add the new `@AppStorage` property alongside the existing one, and a new `Section` alongside the existing one:

```swift
private struct GeneralSettingsPane: View {
    @AppStorage(PreferencesKey.notePreviewSize)
    private var notePreviewSize = PreferencesDefault.notePreviewSize
    @AppStorage(PreferencesKey.appTheme)
    private var appTheme = PreferencesDefault.appTheme

    var body: some View {
        Form {
            Section("Aparência") {
                Picker("Tema", selection: $appTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.label).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: appTheme) {
                    Theme.syncAppAppearance()
                }
            }

            Section("Listas de sessões") {
                Picker("Preview da nota", selection: $notePreviewSize) {
                    ForEach(NotePreviewSize.allCases) { size in
                        Text(size.label).tag(size)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
```

(The "Aparência" section goes first since it's the more fundamental preference — but this is a minor ordering choice, not load-bearing; if the actual current file has more content in this pane than shown above, add the new `Section` as the first one inside the existing `Form` and leave everything else untouched.)

- [ ] **Step 3: Build**

Run: `xcodebuild -scheme "Xisto In Time" -configuration Release build`
Expected: `** BUILD SUCCEEDED **`, zero warnings.

- [ ] **Step 4: Manual visual check (the user, not the implementer — see note below)**

This is a purely visual feature; a build alone doesn't confirm it works. Whoever runs this step should:
1. Open Preferências → Geral, confirm the new "Tema" segmented control shows Claro/Escuro/Sistema, with Sistema selected by default (fresh install / no prior preference).
2. Pick "Escuro" — confirm the main window, the menu-bar popover, and (by triggering them) the Pomodoro decision overlay and the Idle resolution overlay all switch to dark appearance immediately, without restarting the app.
3. Pick "Claro" — confirm all 4 switch back immediately.
4. Pick "Sistema" — confirm the app now tracks the Mac's own Appearance setting (toggle it in System Settings and confirm the app follows).

If a fresh subagent implements this task, it cannot perform this step itself (no reliable GUI automation for this app's borderless panels in this environment) — it must report the code as complete and explicitly hand this step to the controller/user rather than claim it as verified.

- [ ] **Step 5: Commit**

```bash
git add "Xisto In Time/Xisto_In_TimeApp.swift" "Xisto In Time/UI/SettingsView.swift"
git commit -m "$(cat <<'EOF'
feat: selector de tema em Preferências → Geral

Claro/Escuro/Sistema, aplicado de imediato via
NSApplication.shared.appearance — sem reiniciar a app.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```
