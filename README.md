# Xisto In Time

App nativa em SwiftUI, para macOS, que vive na menu bar: time tracker com
suporte a pomodoro.

Uso pessoal, single-user, offline. Nunca vai para a App Store.

## Requisitos

- macOS 14.0+
- Xcode 26.6 (build 17F113), SDK macOS 26
- Apple Silicon (`arm64`)

## Build

```bash
xcodebuild -project "Xisto In Time.xcodeproj" -scheme "Xisto In Time" \
  -configuration Release -destination 'platform=macOS' -derivedDataPath ./build build
```

## Instalar e correr

A app corre a partir de `~/Applications`, não da pasta de build:

```bash
pkill -f "Xisto In Time"
rm -rf "$HOME/Applications/Xisto In Time.app"
cp -R "./build/Build/Products/Release/Xisto In Time.app" "$HOME/Applications/"
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f "$HOME/Applications/Xisto In Time.app"
open "$HOME/Applications/Xisto In Time.app"
```

Fica localizável pelo Spotlight (Cmd+Espaço, "Xisto"), sem ícone no
Dock/Cmd+Tab (`LSUIElement`, propositado).

## Arquitectura

Duas superfícies distintas:

- **Popover da menu bar** — interacções rápidas: começar/parar sessão,
  escolher projecto/tarefa já existentes, nota opcional ao fechar.
- **Janela principal** — gestão: projectos, tarefas, edição de sessões,
  relatórios, preferências.

Modelo de dados em três níveis: `Project` → `TaskItem` → `Session`, persistido
em SwiftData. Sessões sem tarefa atribuída são normais, não um erro.

Detalhes completos de arquitectura, regras e decisões de produto estão em
[`CLAUDE.md`](./Xisto%20In%20Time/CLAUDE.md).

## Versionamento

Segue [SemVer](https://semver.org/lang/pt-BR/) (`major.minor.patch`). A versão
actual está em [`VERSION`](./VERSION), no [`CHANGELOG.md`](./CHANGELOG.md), nas
git tags (`vX.Y.Z`), e é visível no rodapé das Preferências da app.
