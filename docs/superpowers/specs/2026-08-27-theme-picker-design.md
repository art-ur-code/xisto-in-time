# Selector de tema (Claro/Escuro/Sistema) — design

Data: 2026-08-27
Estado: aprovado, a aguardar plano de implementação

## Objectivo

Uma preferência em Preferências → Geral que deixa escolher Claro, Escuro
ou Sistema (default). A app hoje segue 100% a aparência do sistema, sem
nenhum ponto de override — isto introduz o primeiro. Constrói-se sobre o
design system (`Theme.swift`, v1.23.0): `Theme.Color.dynamic(light:dark:)`
já resolve contra a aparência do contexto de desenho corrente, por isso
não precisa de nenhuma alteração — só é preciso um sítio que decida qual
é essa aparência.

## Fora de âmbito (nesta versão)

- **Cor de destaque escolhível.** `Theme.Color.accent` já lê uma
  preferência (`themeAccentColorHex`) mas nenhuma UI a escreve — fica
  assim. Fora de âmbito desta versão; quando for feito, `accentHex`
  precisa de passar de `UserDefaults.standard.string(forKey:)` para
  `@AppStorage` (ou equivalente observável), para que escrever a
  preferência invalide a UI — apontado na revisão final do design
  system, não resolvido aqui porque nada escreve essa chave ainda.
- **Paletas alternativas / temas customizados.** Só Claro/Escuro/Sistema.
- **Animação de transição entre temas.** A mudança é instantânea (o
  AppKit já trata disto ao mudar `NSApplication.shared.appearance`), sem
  nenhuma transição customizada a construir.

## Modelo de dados (`Core/Preferences.swift`)

Novo enum, no mesmo ficheiro, seguindo exactamente o padrão de
`IdleResolutionMode` (linhas 62-76 hoje):

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

`PreferencesKey`: `static let appTheme = "appTheme"`.
`PreferencesDefault`: `static let appTheme = AppTheme.system`.

Leitor tipado, seguindo o padrão de `idleResolutionMode()` (linhas
132-138 hoje) — necessário porque `Theme.syncAppAppearance()` (abaixo)
corre fora de uma `View` SwiftUI, sem acesso a `@AppStorage`:

```swift
static func appTheme() -> AppTheme {
    guard let raw = UserDefaults.standard.string(forKey: PreferencesKey.appTheme),
          let theme = AppTheme(rawValue: raw) else {
        return PreferencesDefault.appTheme
    }
    return theme
}
```

## Aplicar a aparência (`Core/Theme.swift`)

Um único ponto novo, colado à `enum Theme` existente (não dentro de
`Theme.Color` — é sobre a app, não sobre um token):

```swift
extension Theme {
    /// Aplica a preferência de tema à app inteira. As 4 janelas/painéis
    /// actuais (janela principal, popover da menu bar, painel partilhado
    /// do Pomodoro/Idle, e a própria janela de Preferências) não definem
    /// `appearance` própria — o AppKit propaga isto automaticamente a
    /// todas elas. `Theme.Color.dynamic(light:dark:)` já resolve contra
    /// a aparência do contexto de desenho corrente, por isso não precisa
    /// de nenhuma alteração.
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

Chamado em dois sítios:

1. **`Xisto_In_TimeApp.swift`**, logo no início do `init()` (linha 26,
   antes de `let schema = ...`) — `Theme.syncAppAppearance()`. Corre
   antes de `OverlayController`/`MenuBarController`/`MainWindowController`
   serem criados, para a primeira janela já nascer com a aparência
   certa (sem "flash" da aparência errada).
2. **`UI/SettingsView.swift`**, `GeneralSettingsPane` — ver abaixo.

## Preferências → Geral (`UI/SettingsView.swift`)

`GeneralSettingsPane` ganha uma nova `Section`, seguindo o padrão
segmentado já usado em `CalendarSettingsPane` para `use24Hour`:

```swift
@AppStorage(PreferencesKey.appTheme)
private var appTheme = PreferencesDefault.appTheme

// dentro do Form existente:
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
```

## Testes

Sem suite automatizada (decisão já assente). Build Release com zero
avisos é necessário mas não suficiente — isto é uma funcionalidade
inteiramente visual, por isso a confirmação fica com o utilizador:
mudar entre Claro/Escuro/Sistema nas Preferências e confirmar que a
janela principal, o popover da menu bar, e os overlays de Pomodoro/Idle
(disparando-os manualmente) mudam de aparência imediatamente, sem
precisar reiniciar a app.
