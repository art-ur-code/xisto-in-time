# Design system — design

Data: 2026-08-27
Estado: aprovado, a aguardar plano de implementação

## Objectivo

Substituir as cores, tamanhos de fonte, espaçamentos e raios de canto hoje
espalhados pelo código (39 `Color(hex:)` literais, 35 tamanhos de fonte
numéricos ad-hoc, padding/spacing/raios sem nome) por um sistema de tokens
central, `Theme`, e migrar todo o código existente para o usar. Isto não
muda a aparência da app (é um refactor visual 1:1 em modo claro) — o
objectivo é preparar o terreno para um tema escuro automático e, mais
tarde, uma cor de destaque escolhível pelo utilizador.

## Fora de âmbito (nesta versão)

- **UI de selecção de tema.** Não há nenhum ecrã novo nas Preferências
  nesta versão — só a infra-estrutura (a preferência `themeAccentColorHex`
  fica com um valor por omissão fixo, sem interface para a mudar).
- **Alternar manualmente claro/escuro dentro da app.** A app continua a
  seguir a aparência do sistema (`NSColor` dinâmico) — não há
  `.preferredColorScheme` nem um selector "Claro/Escuro/Automático".
- **Ícones/imagens/SF Symbols com variante de tema.** Fora de âmbito;
  SF Symbols já se adaptam sozinhos ao `.foregroundStyle` que usam.
- **Auditoria de contraste/acessibilidade (WCAG).** Os valores de modo
  escuro propostos abaixo são escolhas razoáveis por inspecção, não
  verificados formalmente contra um rácio de contraste mínimo.

## Arquitectura

Um único ficheiro novo, `Core/Theme.swift`, com um `enum Theme` e três
sub-namespaces: `Theme.Color`, `Theme.Font`, `Theme.Spacing`,
`Theme.Radius` (quatro no total).

Cada cor é um papel semântico (`Theme.Color.accent`, não
`Theme.Color.blue`), implementado com `NSColor(name:dynamicProvider:)`
envolvido em `Color(nsColor:)`:

```swift
private func dynamicColor(light: String, dark: String) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return NSColor(Color(hex: isDark ? dark : light))
    })
}
```

Isto resolve-se sozinho contra a aparência actual em qualquer sítio onde a
`Color` é usada (constantes, `extension`, computed properties fora de uma
`View`) — ao contrário de `@Environment(\.colorScheme)`, que só funciona
dentro do corpo de uma `View`. É por isto que `SessionKindStyle.swift`
(uma `extension SessionKind`, sem acesso a `Environment`) só pode ganhar
suporte a tema escuro através deste mecanismo, não do `@Environment`.

`Theme.Color.accent` lê uma preferência persistida:

```swift
private static var accentHex: String {
    UserDefaults.standard.string(forKey: "themeAccentColorHex") ?? "007AFF"
}
static var accent: Color { dynamicColor(light: accentHex, dark: "0A84FF") }
```

(Nesta versão, `accentHex` nunca é escrito por nenhuma UI — fica só o
ponto de extensão. Quando existir um selector de cor de destaque, essa
UI só precisa de escrever essa uma chave.)

**Variantes "claras" (tinta) são derivadas por opacidade, não por hex
próprio**, sempre que a proporção observada no código actual confirma que
é isso que já acontece: `SessionKindStyle.lightColor` de cada tipo é,
dentro de ~1-2 pontos de arredondamento, a sua `color` a ~12-15% de
opacidade sobre branco (verificado a partir dos hex actuais: `DFEEFF` ≈
`007AFF` a 12%; `FFF4D6` ≈ `E8A300` a ~13%). Isto tem uma vantagem
concreta para o tema escuro: uma tinta derivada por opacidade herda
automaticamente o comportamento claro/escuro da cor base (sobre um fundo
escuro dá uma tinta escura, não um azul-claro ilegível), enquanto um hex
fixo como `DFEEFF` não adaptaria nada sozinho.

## `Theme.Color` — tabela de papéis

| Papel | Claro | Escuro | Substitui (hex actuais) |
|---|---|---|---|
| `accent` | preferência, default `007AFF` | `0A84FF` | `007AFF` (SessionKindStyle, SessionListRow, AllSessionsView) |
| `accentSubtle` | `accent.opacity(0.12)` | `accent.opacity(0.12)` | `EAF3FF` |
| `surfacePrimary` | `FFFFFF` | `1C1C1E` | `Color.white` |
| `surfaceHover` | `FAFAFC` | `242426` | `FAFAFC` |
| `fillSubtle` | `F1F1F4` | `2C2C2E` | `F0F0F3`, `F1F1F4`, `F4F4F7` |
| `divider` | `ECECF0` | `38383A` | `ECECF0`, `E9E9EE`, `E7E7EB` |
| `textMuted` | `8A8A90` | `98989F` | `8A8A90`, `9A9AA0`, `7C7C82` |
| `textSecondary` | `6A6A70` | `B4B4BA` | `6A6A70`, `5A5A60` |
| `textFaint` | `C4C4C9` | `48484A` | `C4C4C9` |
| `inkStrong` | `2A2A2F` | `F0F0F2` | `2A2A2F`, `1C1C1E` |
| `badgeTodayText` | `B05800` | `FFB454` | `B05800` |
| `badgeTodayBackground` | `FFD6D6` | `4A2020` | `FFD6D6` |
| `sessionWork` | = `accent` | = `accent` | `007AFF` (SessionKindStyle) |
| `sessionWorkLight` | = `sessionWork.opacity(0.12)` | idem | `DFEEFF` |
| `sessionBreak` | `A0A0A6` | `8E8E93` | `A0A0A6` |
| `sessionBreakLight` | = `sessionBreak.opacity(0.15)` | idem | `EEEEF1` |
| `sessionBreakText` | = `textSecondary` | idem | `71717A` |
| `sessionPlan` | `E8A300` | `E8A300` | `E8A300`, `FAE588` (`SessionRow.swift:40`, ver nota abaixo) |
| `sessionPlanLight` | = `sessionPlan.opacity(0.13)` | idem | `FFF4D6` |
| `sessionPlanText` | `A87000` | `D4A64C` | `A87000` |

**Nota — inconsistência encontrada:** `SessionRow.swift:40` (usado por
`ProjectDetailView`/`TaskDetailView`) ainda tem `Color(hex: "FAE588")` —
a cor de Plano *antes* de ter sido unificada para `E8A300` no resto da
app. A migração deste ficheiro para `Theme.Color.sessionPlan` corrige
este esquecimento como efeito direto, sem trabalho extra.

**Cores que não mudam:** `Color.accentColor` (controlo nativo a seguir o
accent do sistema, não o nosso `accent`), `.primary`, `.secondary`,
`.thinMaterial`/`.regularMaterial`, `.separator`, `Color.clear` — já são
adaptativos por natureza; só se substitui hex fixo.

## `Theme.Font` — tabela de tamanhos

Só nomeia os 35 `.system(size:)` numéricos ad-hoc; as 61 fontes
semânticas (`.caption`, `.headline`, etc.) ficam como estão — já são uma
escala (a da Apple) e trocá-las não muda nada visualmente.

| Token | pt | Substitui | Uso típico |
|---|---|---|---|
| `micro` | 9 | 9 | glifo inline (▶) |
| `badge` | 10 | 10, 10.5 | selo pequeno maiúsculo (chip de tipo, "HOJE") |
| `caption` | 11.5 | 11, 11.5 | metadados, código externo |
| `footnote` | 12.5 | 12, 12.5 | rótulos de botão pequenos, chips |
| `subheadline` | 13 | 13, 13.5 | corpo denso (pesquisa, duração) |
| `body` | 14 | 14 | título de linha |
| `callout` | 15 | 15 | corpo maior |
| `title3` | 19 | 19 | título de secção |
| `statLarge` | 20 | 20 | número grande monoespaçado |
| `title2` | 30 | 30 | overlay (Idle) |
| `largeTitle` | 34 | 34 | overlay (Pomodoro) |

Cada token é um `CGFloat` (só o tamanho), tal como `Theme.Spacing`/
`Theme.Radius` — `weight`/`design` continuam escolhidos no call site,
exactamente como hoje, só o número passa a ter nome:

```swift
enum Font {
    static let micro: CGFloat = 9
    static let badge: CGFloat = 10
    static let caption: CGFloat = 11.5
    static let footnote: CGFloat = 12.5
    static let subheadline: CGFloat = 13
    static let body: CGFloat = 14
    static let callout: CGFloat = 15
    static let title3: CGFloat = 19
    static let statLarge: CGFloat = 20
    static let title2: CGFloat = 30
    static let largeTitle: CGFloat = 34
}
```

Uso: `.font(.system(size: Theme.Font.caption, weight: .semibold, design: .monospaced))`
— igual ao padrão actual, com `Theme.Font.caption` no lugar de `11.5`.

## `Theme.Spacing` / `Theme.Radius`

Já existe uma escala *de facto* razoável nos valores actuais — só falta
nomear. Outliers isolados (28, 32, 70 em espaçamento; 2, 3, 6, 16 em
raio) ficam como valores locais nesse call site, não forçados à escala.

```swift
enum Spacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 6
    static let md: CGFloat = 8
    static let base: CGFloat = 10
    static let lg: CGFloat = 12
    static let xl: CGFloat = 16
    static let xxl: CGFloat = 22
}

enum Radius {
    static let sm: CGFloat = 4
    static let md: CGFloat = 8
    static let lg: CGFloat = 12
    static let xl: CGFloat = 20
}
```

Valores intermédios sem tier exacto (14 em espaçamento; 5, 7, 10, 14 em
raio) resolvem-se caso a caso durante a migração de cada ficheiro, para o
vizinho da escala mais próximo do valor actual — decisão tomada por
ficheiro, documentada no commit desse ficheiro, não pré-decidida aqui às
cegas.

## Migração

Âmbito: migrar todo o código existente (decisão do utilizador — não é só
criar a camada de tokens e parar). Ordem por risco crescente, um commit
por ficheiro/grupo:

1. `Core/Theme.swift` — ficheiro novo, compila sozinho, sem tocar em mais
   nada.
2. `Core/SessionKindStyle.swift` — passa a delegar em `Theme.Color`
   (refactor puro: `.work`/`.break`/`.plan` continuam a devolver os
   mesmos valores em modo claro).
3. Calendário — `CalendarWeekView.swift`, `CalendarSessionBlock.swift`,
   `CalendarRunningBlock.swift`: as constantes já nomeadas
   (`hourHeight`, `minColumnWidth`, `gutterWidth`, `columnSpacing`) trocam
   por `Theme.Spacing`/`Theme.Radius` onde há tier correspondente; as
   cores (`Color.gray`, `Color.red`, `SessionKind.break.color` já vindo
   do passo 2) ficam abrangidas.
4. `SessionDayHeader.swift` → `SessionListRow.swift` → `AllSessionsView.swift`
   → `SessionRow.swift` (corrige a inconsistência do `FAE588`) →
   `SessionControlView.swift` — por ordem decrescente de nº de hex
   literais.
5. Restantes ficheiros com pelo menos uma ocorrência hardcoded:
   `TaskPickerView.swift`, `ProjectDetailView.swift`, `TaskDetailView.swift`,
   `ProjectsView.swift`, `TaskCard.swift`, `ReportsView.swift`,
   `PomodoroDecisionView.swift`, `IdleResolutionView.swift`,
   `PopoverView.swift`, `OpenOnDoubleClick.swift`, `MainWindowView.swift`.

`Core/ColorHex.swift` mantém-se sem alterações — continua a ser usado por
`Models/Project.swift` para a cor arbitrária escolhida pelo utilizador por
projecto, que é um valor de dados, não um token de tema.

## Testes

Sem suite automatizada (decisão já assente neste projecto). Por ficheiro
migrado: build Release com zero avisos + confirmação visual em modo claro
(deve ficar pixel-idêntico ao actual, é refactor, não redesign) via AX,
já que este ambiente não tem captura de ecrã.

O modo escuro é comportamento **novo** — não há "antes" para comparar, por
isso a verificação de modo escuro fica para o utilizador confirmar
manualmente no final, mudando a aparência do sistema para escura e
percorrendo: popover da menu bar, janela principal (Sessões, Calendário,
Projectos, Relatórios), e os overlays de Pomodoro/Idle.
