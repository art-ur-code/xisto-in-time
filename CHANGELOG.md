# Changelog

Todas as alterações relevantes deste projecto são documentadas aqui.

O formato segue [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/), e o
versionamento segue [SemVer](https://semver.org/lang/pt-BR/): `major.minor.patch`,
onde major é para alterações estruturais/breaking, minor para novas
funcionalidades, e patch para correcções de bugs.

## [1.9.0] - 2026-08-20

### Adicionado

- Botão "Pausar"/"Retomar" a par de "Parar", em modo Livre e Pomodoro. Ao
  retomar, o início da sessão é empurrado para a frente pelo tempo em
  pausa (a mesma técnica já usada para editar o tempo decorrido à mão),
  para o tempo parado não contar na duração gravada, sem precisar de um
  campo novo no modelo de dados. Parar enquanto pausado termina a sessão
  no momento em que a pausa começou. Pausar não marca a sessão como
  interrompida (isso mantém-se reservado a sleep/wake) e a detecção de
  idle não actua enquanto pausado. O glifo da menu bar deixa de pulsar e
  muda de ícone enquanto a sessão está em pausa.

## [1.8.0] - 2026-08-20

### Alterado

- O controlo de sessão completo saiu da aba "Sessões" (secção "Nova
  sessão") e passou a viver, em versão compacta mas com a mesma
  funcionalidade (modo Livre/Pomodoro, projecto, tarefa, nota), na barra
  lateral da janela principal, sempre visível por cima da linha antes de
  "Preferências". `SessionControlView` ganhou um parâmetro `compact` para
  isto; o popover continua com a versão completa, inalterada.
- A aba "Sessões" ganhou, no lugar do controlo antigo, um card de
  estatísticas Hoje/Esta semana, igual ao já existente em Projectos e
  Tarefas.

## [1.7.0] - 2026-08-20

### Adicionado

- Botão "Começar sessão desta tarefa" no topo do `TaskDetailView`, com o
  projecto e a tarefa já pré-preenchidos. Se já houver uma sessão a decorrer
  (livre ou pomodoro), esta é parada e gravada automaticamente antes de
  arrancar a nova. Se a sessão a decorrer já for desta tarefa, o botão fica
  desactivado.

## [1.6.0] - 2026-08-19

### Adicionado

- Backups locais rotativos: em cada arranque, antes de abrir a base de dados,
  o `default.store` anterior é copiado para
  `~/Library/Application Support/Xisto Backups/`, mantendo os últimos 10.
  Sem isto, uma base de dados corrompida não tinha forma de recuperação —
  esta máquina não tem Time Machine configurado.

### Corrigido

- Perda total do histórico após um crash: nenhuma escrita (fim de sessão,
  criar/editar/arquivar projecto ou tarefa) chamava `context.save()` — tudo
  dependia do autosave implícito do SwiftData, que nunca chegou a gravar no
  ficheiro em disco ao longo de 36h de uso. `ModelContext.saveAndCheckpoint()`
  (`Core/StoreMaintenance.swift`) grava e força o merge do WAL da SQLite para
  o ficheiro principal imediatamente a seguir a cada escrita, com um timer de
  60s como rede de segurança adicional e gravação final ao terminar a app.

## [1.5.0] - 2026-08-19

### Adicionado

- Barra de menu: enquanto há uma sessão a correr associada a uma tarefa com
  projecto, mostra `"Projecto - hh:mm:ss"` em vez de só o tempo.

### Corrigido

- `MenuBarController` passou a medir e definir explicitamente a largura do
  `NSStatusItem` a partir do conteúdo SwiftUI hospedado, em vez de confiar
  no auto-dimensionamento do `.variableLength` (que só olha para
  título/imagem nativos do botão e nunca via a subview): o texto da sessão
  a correr ficava sempre cortado a zero, preso na largura do ícone parado.

## [1.4.0] - 2026-08-19

### Adicionado

- Overlay de decisão do pomodoro: terceira opção "Terminar Sessão", que
  termina a sessão actual e reinicia o cronómetro (equivalente a premir
  Parar), para quando não vou fazer pausa nem continuar a mesma tarefa.

### Corrigido

- Botões do overlay de decisão do pomodoro com feedback de hover, que não
  aparecia com os estilos nativos dentro do `NSPanel` personalizado.

## [1.3.2] - 2026-08-19

### Corrigido

- Duplo clique para abrir (Projectos, Tarefas, Sessões): o primeiro clique
  passou a acender um destaque breve na linha, para dar feedback imediato
  em vez de parecer que não aconteceu nada à espera do segundo clique.

## [1.3.1] - 2026-08-19

### Corrigido

- Nome da tarefa nas linhas de sessão limitado a uma linha (com reticências),
  em vez de poder esticar a linha em altura quando o nome é longo.

## [1.3.0] - 2026-08-18

### Adicionado

- Detalhe da tarefa: cards de "Hoje" e "Esta semana", iguais aos do
  detalhe do projecto, e um botão "Editar" (título e projecto) na
  toolbar, através de um novo `TaskFormSheet` partilhado com a criação de
  tarefas em `TasksBrowserView`.

## [1.2.0] - 2026-08-18

### Adicionado

- Preferências → Geral: novo controlo "Preview da nota" com três níveis
  (ícone / 1 linha / 2 linhas) para as listas de sessões.

### Alterado

- Abrir um projecto, uma tarefa ou uma sessão a partir de uma lista passa a
  exigir duplo clique em vez de um só — um clique simples deixou de fazer
  nada. As linhas ganharam um chevron discreto a indicar que se abrem assim.
- As listas de sessões (Sessões, dentro de uma Tarefa, dentro de um
  Projecto) passam a partilhar um único componente de linha, e a edição
  abre sempre empurrada na página (como já acontecia a partir de um
  Projecto) em vez de num popup. Os botões de editar/apagar que apareciam
  ao passar o rato (introduzidos na v1.1.0) foram removidos — apagar uma
  sessão faz-se agora sempre a partir de dentro do editor.
- O ícone de "sessão editada manualmente" (lápis) foi removido das listas;
  o ícone de nota foi substituído por um preview do texto da nota (ver
  preferência nova), salvo quando essa preferência está em "ícone".

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
