# Changelog

Todas as alterações relevantes deste projecto são documentadas aqui.

O formato segue [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/), e o
versionamento segue [SemVer](https://semver.org/lang/pt-BR/): `major.minor.patch`,
onde major é para alterações estruturais/breaking, minor para novas
funcionalidades, e patch para correcções de bugs.

## [1.0.0] - 2026-08-18

### Adicionado

- Esqueleto da app: ícone na menu bar (`NSStatusItem` à mão), popover e janela
  principal geridos manualmente, sem `MenuBarExtra`.
- Timer manual de sessões — cálculo por diferença de `Date`, sem acumular ticks.
- Persistência em SwiftData: hierarquia `Project` → `TaskItem` → `Session`.
- Projectos e tarefas, com arquivo sempre manual.
- Notas acumuladas por tarefa (diário de progresso por sessão).
- Criação e edição manual de sessões (`SessionEditorView`), com validação de
  datas, sobreposições avisadas e confirmação para durações longas.
- Pomodoro: ciclos de trabalho/pausa configuráveis.
- Overlay de decisão (fim de pomodoro / idle) via `NSPanel`.
- Detecção de inactividade (`IdleMonitor`), sem Accessibility API.
- Relatórios diário e semanal, com sessões sem atribuição e editadas em destaque.
- Preferências (`SettingsView`), com número de versão visível no rodapé.
