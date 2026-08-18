# Changelog

Todas as alterações relevantes deste projecto são documentadas aqui.

O formato segue [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/), e o
versionamento segue [SemVer](https://semver.org/lang/pt-BR/): `major.minor.patch`,
onde major é para alterações estruturais/breaking, minor para novas
funcionalidades, e patch para correcções de bugs.

## [1.1.0] - 2026-08-18

### Adicionado

- Nas listas de sessões (aba Sessões e dentro de uma tarefa), as linhas
  deixaram de abrir o editor ao clicar em qualquer ponto — passam a
  mostrar, só em hover, um ícone de editar e um de apagar (este último com
  confirmação). Acrescentado também um indicador na linha para sessões que
  têm nota escrita.

## [1.0.2] - 2026-08-18

### Corrigido

- O campo de nota da sessão passou a aparecer assim que a sessão começa
  (popover e janela principal), em vez de só depois de parar — a nota é
  escrita ao longo da sessão e fica guardada quando esta termina, seja qual
  for o caminho (Parar, Pomodoro ou idle).
- Corrigido um crash ao carregar em "Apagar sessão": a vista de edição por
  ID usava `modelContext.model(for:)`, que devolvia uma instância inválida
  da sessão já apagada; passou a usar uma `@Query` reactiva.

## [1.0.1] - 2026-08-18

### Corrigido

- Modo Pomodoro: o contador deixou de arrancar sempre em 0:00 — parado, mostra
  a duração configurada (ex. 25:00); a correr, passou a contar a decrescer até
  0:00 em vez de subir. Tocar no contador antes de começar define uma duração
  só para esse pomodoro, sem alterar as Preferências. Selecionar o modo
  Pomodoro repõe qualquer valor personalizado anterior. O glifo da menu bar
  segue a mesma contagem decrescente.

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
