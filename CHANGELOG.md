# Changelog

Todas as alterações relevantes deste projecto são documentadas aqui.

O formato segue [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/), e o
versionamento segue [SemVer](https://semver.org/lang/pt-BR/): `major.minor.patch`,
onde major é para alterações estruturais/breaking, minor para novas
funcionalidades, e patch para correcções de bugs.

## [1.17.0] - 2026-08-27

### Adicionado

- Tipo de sessão "Plano" (além de Trabalho e Pausa): cria-se e edita-se à
  mão como qualquer outra sessão, pode ter datas no futuro (as únicas
  que podem), sobrepõe-se em silêncio a Trabalho/Pausa sem gerar aviso
  (planear em cima do que se vai fazer é o comportamento esperado), e
  aparece no Calendário a amarelo (`#FAE588`). Fica de fora dos totais
  de Relatórios, tal como a Pausa já ficava.
- Calendário: confirmação com "De:"/"Para:" antes de gravar qualquer
  arrasto (mover ou redimensionar), incluindo avisos de sobreposição ou
  duração longa na mesma caixa.
- Calendário: linha vermelha a marcar a hora actual, só na coluna do
  dia de hoje.
- Calendário: cabeçalhos dos dias fixos ao fazer scroll vertical.
- Calendário: botão "Esta semana" passa a "Agora" — volta à semana
  actual e faz scroll até à hora de agora.

### Corrigido

- Calendário: o botão de ir para a hora actual não fazia scroll nenhum —
  limitação do `ScrollViewReader.scrollTo` do macOS numa `ScrollView`
  combinada de dois eixos; resolvido separando em duas `ScrollView` de
  eixo único aninhadas.
- Calendário: arrastar uma sessão de Trabalho/Pausa para uma data futura
  substituía silenciosamente o destino pela hora actual, em vez de
  recusar — parecia perda de dados. Passa a recusar com uma mensagem
  clara e a repor a posição original, tal como o editor de sessões já
  fazia.

## [1.16.0] - 2026-08-26

### Adicionado

- Vista semanal de Calendário: novo separador "Calendário", primeiro na
  barra lateral e seleccionado por omissão, com uma grelha semanal das
  sessões (colunas por dia, horas na vertical). As sessões arrastam-se
  para mudar de dia/hora e redimensionam-se pelas extremidades para
  ajustar início/fim, com aviso de sobreposição e confirmação para
  sessões com mais de 12 horas — a edição continua sempre possível pelo
  editor de sessões, agora acessível também a partir de um duplo clique
  no bloco.
- Preferência "Encaixar (snap)" no painel de Calendário das Preferências,
  para arredondar o arrasto/redimensionamento a um intervalo fixo de
  minutos.

## [1.15.0] - 2026-08-26

### Adicionado

- Botão "Criar tarefa" dentro da secção "Tarefas" nos detalhes do projecto,
  já com o projecto seleccionado por omissão (mesmo formulário partilhado
  por Tarefas/Popover).
- Ícone da aplicação (`AppIcon.appiconset`), até agora vazio.

### Alterado

- Detalhes do projecto: cabeçalhos de "Tarefas" e "Sessões" passam a ter o
  mesmo estilo (título + contagem), e o bloco de Sessões ganha um cabeçalho
  próprio acima dos agrupamentos por dia — antes as sessões seguiam
  directamente da lista de tarefas sem nenhuma divisão visual clara entre
  os dois blocos.
- A app deixa de ser `LSUIElement`: passa a ter ícone no Dock e a aparecer
  no Cmd+Tab como uma app normal.

## [1.14.1] - 2026-08-25

### Corrigido

- Não era possível escrever em nenhum campo de texto do popover da barra de
  menu (nota, pesquisa de tarefa, edição do tempo decorrido). O painel do
  popover é um `NSPanel` simples com `.borderless, .nonactivatingPanel`, que
  nesta configuração reporta `canBecomeKey`/`canBecomeMain` como `false` —
  o SwiftUI continuava a atribuir um field editor e a mostrá-lo como
  `firstResponder` (por isso parecia focado ao clicar), mas a janela nunca
  chegava a ficar `key`, por isso nenhuma tecla premida entrava no campo.
  Resolvido com uma subclasse de `NSPanel` que sobrepõe essas duas
  propriedades para `true` — a única forma de as alterar, já que não há
  propriedade equivalente numa instância normal.

## [1.14.0] - 2026-08-25

### Adicionado

- Sessões e tarefas dentro de um Projecto, e sessões dentro de uma Tarefa,
  passam a seguir o mesmo padrão de card já usado nas listas principais:
  tarefas com link/arquivar/apagar, sessões agrupadas por dia com o botão
  "Começar". Estas listas partilham agora os mesmos componentes
  (`SessionRow`, `TaskCard`) e a mesma lógica de agrupamento por dia
  (`ReportBuilder.groupedByDay`, `SessionDayHeader`) que as listas principais
  "Sessões" e "Tarefas", que mantêm o aspecto inalterado.
- Lista principal de Tarefas agrupada por projecto (ordem alfabética, "Sem
  projecto" no fim quando aplicável).

## [1.13.0] - 2026-08-25

### Adicionado

- Listas de Projectos e Tarefas redesenhadas como cards maiores, no mesmo
  estilo visual da lista de Sessões.
- Novo campo opcional "Link da tarefa" (URL) em cada tarefa, editável no
  formulário de criar/editar; quando é um URL válido, aparece um botão para
  abrir directamente a partir do card na lista de Tarefas.

## [1.12.0] - 2026-08-25

### Adicionado

- Lista de Sessões agrupada por dia: cada dia tem o seu cabeçalho, com dia da
  semana, data, número de sessões e total desse dia.
- Linhas da lista de Sessões redesenhadas como cards maiores, mais fáceis de
  ler, mantendo toda a informação anterior (nota, sessão interrompida, etc.).
- Botão "Começar" em cada sessão da lista, para arrancar de imediato uma nova
  sessão em modo livre com a mesma tarefa — pára automaticamente a sessão a
  decorrer, se houver uma.

## [1.11.0] - 2026-08-20

### Adicionado

- Apagar projectos e tarefas (`ProjectsView`, `TasksBrowserView`), além das
  sessões já suportadas. Continua a ser a única forma de os remover de
  vez — arquivar continua reversível e é o caminho recomendado no dia a
  dia. Apagar é em cascata: um projecto leva as suas tarefas, e cada
  tarefa leva as suas próprias sessões, sempre com confirmação que diz
  quantas tarefas/sessões vão ser apagadas antes de acontecer. Sem
  lixeira — uma vez confirmado, é definitivo, tal como já era para
  sessões.
- Apagar sessão directamente pelo menu de contexto de qualquer lista onde
  aparece (`SessionRow`, usado em Sessões, dentro de Projecto e dentro de
  Tarefa) — antes só era possível abrindo a sessão no editor.

## [1.10.1] - 2026-08-20

### Corrigido

- Perda total da base de dados por colisão de caminho: `default.store` vivia
  em `~/Library/Application Support/default.store`, o caminho genérico que o
  SwiftData usa por omissão quando não se indica uma subpasta própria da
  app. Sem sandbox, essa pasta é partilhada por todas as apps não
  sandboxed da máquina — outra app (esquema `APIRequestModel`, nada a ver
  com o Xisto) aterrou no mesmo ficheiro e o SwiftData recriou-o do zero,
  apagando projectos, tarefas e sessões. Os dados foram recuperados a
  partir dos backups rotativos introduzidos em 1.6.0. Agora o Xisto vive
  em `~/Library/Application Support/Xisto In Time/`, isolado; instalações
  antigas migram automaticamente o `default.store` existente (e a pasta de
  backups) para lá no primeiro arranque, só se o esquema for
  reconhecidamente do Xisto.

## [1.10.0] - 2026-08-20

### Adicionado

- Modo Livre/Pomodoro no popover explica-se sozinho: segmentado a toda a
  largura, legenda por baixo (com hora de fim estimada em Pomodoro),
  configuração de Foco/Blocos visível antes de arrancar (ligada às
  preferências já existentes), pré-visualização do visor e barras de
  bloco, e um indicador "a contar" com ponto a pulsar.
- Selecção de tarefa deixou de ser dois `Picker` dependentes: entra uma
  célula de contexto ("A registar em") com um selector de busca próprio
  (recentes, projectos, filtragem com destaque, criar tarefa — e criar
  projecto na hora, se ainda não existir nenhum — sem sair do popover),
  com navegação por teclado. Rodapé "Última: tarefa · Retomar" para
  retomar num clique. Sessões soltas continuam possíveis, como sempre.
- Cabeçalho do popover passa a mostrar o total de hoje (abre a janela
  principal) e ganha um atalho directo para Preferências.
- Clique direito no ícone da menu bar mostra "Abrir janela"/"Sair";
  relançar a app pelo Spotlight enquanto já está a correr mostra a
  janela principal.
- O popover arrasta-se clicando numa área livre e memoriza a posição
  para a próxima vez.
- A janela principal memoriza posição e tamanho, e a barra lateral
  memoriza a largura.

### Corrigido

- O `NSPopover` do popover podia abrir desalinhado/fora do ecrã depois de
  o conteúdo mudar de altura (selector de tarefa, configuração do
  Pomodoro), reposicionando-se com um tamanho desactualizado. Resolvido
  substituindo-o por um `NSPanel` próprio, posicionado sempre a partir da
  posição guardada (ou calculada de novo por baixo do ícone), nunca de
  um valor antigo.

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
