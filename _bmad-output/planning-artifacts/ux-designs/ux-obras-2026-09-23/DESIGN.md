---
name: SIGO — Design system global
status: in-progress
updated: 2026-09-23
description: Rascunho de design e planejamento para discussão; sem implementação.
sources:
  - ../ux-obras-2026-09-21/DESIGN.md
  - ../ux-obras-2026-09-21/EXPERIENCE.md
  - ../../epics.md
  - ../../architecture/architecture-obras-2026-09-21/ARCHITECTURE-SPINE.md
  - ../../architecture/architecture-epic-5/ARCHITECTURE-SPINE.md
colors:
  surface-base: '#F8FAFC'
  surface-raised: '#FFFFFF'
  ink-primary: '#0F172A'
  ink-secondary: '#475569'
  ink-disabled: '#94A3B8'
  brand-blue: '#2196F3'
  brand-gold: '#FCA906'
  action-blue: '#1565C0'
  sidebar: '#082344'
  sidebar-ink: '#FFFFFF'
  sidebar-muted: '#CBD5E1'
  header-start: '#0D47A1'
  header-end: '#1565C0'
  action-hover: '#0D47A1'
  action-pressed: '#0B3A82'
  focus-light: '#1565C0'
  focus-sidebar: '#FCA906'
  focus-header: '#FFFFFF'
  border-control: '#64748B'
  lot-on-time-bg: '#F0FDF4'
  lot-on-time-ink: '#166534'
  lot-delayed-bg: '#FEF2F2'
  lot-delayed-ink: '#991B1B'
  lot-paused-bg: '#FFF7ED'
  lot-paused-ink: '#9A3412'
  lot-complete-bg: '#EFF6FF'
  lot-complete-ink: '#1E40AF'
  border-hairline: '#E2E8F0'
  owner-bg: '#FEF3C7'
  owner-border: '#F59E0B'
  owner-ink: '#92400E'
  admin-bg: '#EFF6FF'
  admin-border: '#BFDBFE'
  admin-ink: '#1E40AF'
  pending-bg: '#FFF7ED'
  pending-border: '#FDBA74'
  pending-ink: '#9A3412'
  danger: '#DC2626'
typography:
  family: Material padrão por plataforma; sem fontFamily explícita no projeto.
  page-desktop:
    font-size: 40px
    line-height: 48px
    font-weight: 700
  page-mobile:
    font-size: 28px
    line-height: 36px
    font-weight: 700
  section:
    font-size: 24px
    line-height: 32px
    font-weight: 700
  constructor-name:
    font-size: 20px
    line-height: 28px
    font-weight: 600
  lot-name:
    font-size: 18px
    line-height: 24px
    font-weight: 600
  reading:
    font-size: 16px
    line-height: 24px
    font-weight: 400
  supporting:
    font-size: 14px
    line-height: 20px
    font-weight: 400
  action:
    font-size: 14px
    line-height: 20px
    font-weight: 600
  title:
    note: Flutter Material titleLarge; herança de membros 20 semibold.
  item:
    note: Flutter Material titleMedium; herança de membros 16.
  body:
    note: Flutter Material bodyMedium; herança de membros 14.
  meta:
    note: Flutter Material bodySmall; herança de membros 12.
  badge:
    note: Flutter Material labelSmall; herança de membros 11 bold.
rounded:
  sm: 8px
  md: 12px
  lg: 16px
spacing:
  '1': 4px
  '2': 8px
  '3': 12px
  '4': 16px
  '5': 24px
  '6': 32px
  '7': 40px
  '8': 48px
  page-mobile: 16px
  page-desktop: 32px
  constructor-padding-mobile: 20px
  constructor-padding-desktop: 24px
  constructor-gap: 16px
  constructor-grid-gap: 24px
  lot-padding: 16px
  lot-gap: 8px
  lot-grid-gap: 16px
  touch-min: 48px
components:
  ConstrutoraCard:
    min-width-preferred: 320px
    logo-area-mobile: 64px
    logo-area-desktop: 88px
    background: '{colors.surface-raised}'
    foreground: '{colors.ink-primary}'
    radius: '{rounded.md}'
  LoteCard:
    min-width-preferred: 280px
    background: '{colors.surface-raised}'
    foreground: '{colors.ink-primary}'
    radius: '{rounded.md}'
  SigoLayout:
    background: '{colors.surface-base}'
  ActionButton:
    background: '{colors.action-blue}'
    foreground: '{colors.surface-raised}'
    radius: '{rounded.sm}'
  DataSurface:
    background: '{colors.surface-raised}'
    radius: '{rounded.md}'
  StatusFeedback:
    foreground: '{colors.ink-secondary}'
  FormField:
    foreground: '{colors.ink-primary}'
  DetailOverlay:
    radius: '{rounded.lg}'
  MemberRow:
    foreground: '{colors.ink-primary}'
  RoleChip:
    radius: '{rounded.md}'
  ObraVinculoRow:
    foreground: '{colors.ink-primary}'
  AtribuirObraDialog:
    radius: '{rounded.lg}'
  ConfirmDestructiveDialog:
    action-color: '{colors.danger}'
  EvidenceField:
    radius: '{rounded.sm}'
  CostSummary:
    background: '{colors.surface-raised}'
---

## Brand & Style

**Rascunho para discussão.** Confirmado pelo usuário: praticidade no telefone e uma experiência visual impressionante no desktop. Este planejamento global é separado do trabalho de Gestão de Membros e não altera seus contratos.

**Direção confirmada mais recente:** o usuário escolheu a alternativa **mais expressiva (conceito B)**, com azul e dourado em maior destaque. Construir a nova paleta a partir da cor da logo SIGO e do azul existente no projeto; tornar os cards de construtoras mais interessantes, considerando logo da empresa. A referência verde-petróleo de membros é histórica e não constitui a base global proposta.

Flutter Material permanece o sistema herdado. A extração do projeto identificou `Colors.blue` como seed do tema, superfícies claras e sidebar escura; a logo SIGO tem símbolo dourado tonal. A direção escolhida usa azul com presença marcante na navegação e no cabeçalho, acentos dourados expressivos e superfícies claras para leitura. O usuário confirmou manter o contraste da imagem, títulos com a mesma presença visual, construtoras espaçosas e lotes compactos. Os valores numéricos abaixo são a calibragem proposta [ASSUMPTION], não uma extração exata ou nova aprovação de cada token. Preservar a logo oficial SIGO; a imagem gerada não aprova seu redesenho.

![Conceito B — referência desktop expressiva escolhida](mockups/conceito-b-expressivo.png)

A seleção de construtora é a referência conceitual inicial: sidebar azul profundo, cabeçalho amplo em azul, acentos dourados e grid de cards claros com área de logo e ação azul. Slogan, empresas e logos fictícias são ilustrativos; fotografias, grafismos e controles mostrados não constituem automaticamente conteúdo final ou novos recursos aprovados. O conceito A permanece como alternativa histórica em `.working/conceito-a-sobrio.png`.

As fontes originais cobrem membros e épico 5; inspeção complementar cobre tema/logo/cards atuais. Não representam inventário completo do SIGO. Este documento governa o visual; [EXPERIENCE.md](EXPERIENCE.md) governa comportamento. Em conflito com artefatos visuais, os dois documentos prevalecem. Ver [extrato de marca](.working/brand-extract.md) para evidências locais e limitações.

## Colors

| Token | Origem e papel no rascunho |
|---|---|
| `{colors.brand-blue}` | `#2196F3`: valor de Colors.blue usado como seed em main.dart; não equivale necessariamente à primary gerada. [ASSUMPTION] Cor de marca e detalhes gráficos |
| `{colors.brand-gold}` | `#FCA906`: amostra raster provisória da logo, não especificação oficial monocromática. [ASSUMPTION] Destaque pontual, com texto escuro |
| `{colors.action-blue}` | `#1565C0`: [ASSUMPTION] azul mais escuro proposto para ação com texto branco; não foi identificado como primary efetiva do app |
| `{colors.surface-base}` / `{colors.surface-raised}` | Neutros herdados; fundo e superfície |
| `{colors.ink-primary}` / `{colors.ink-secondary}` | Texto principal e secundário herdados |

A direção e o contraste do conceito B estão confirmados. Todos os novos hexadecimais são [ASSUMPTION] de calibragem; a logo original continua tonal e não é recolorida para coincidir com o token dourado. Manter legibilidade e papéis estáveis entre construtoras; a logo da empresa não muda o tema global. Não usar branco sobre o azul seed ou dourado sem avaliação de contraste. Ações de perigo conservam `{colors.danger}`. Papéis locais owner/admin/pending mantêm tokens históricos no rascunho; a separação entre dourado de marca e proprietário precisa ser validada pelo texto e contexto, nunca apenas cor.

Metas: texto normal 4,5:1; texto grande e indicadores essenciais 3:1. Cálculos fornecidos pelo agente coordenador para pares herdados: texto principal/base 17,06:1; secundário/branco 7,58:1; branco/perigo 4,83:1; proprietário texto/fundo 6,37:1; administrador 8,01:1; pendente 6,88:1. Cálculos sRGB dos novos pares: branco/action-blue 5,75:1; ink-primary/dourado 9,20:1; branco/azul seed 3,12:1 e branco/dourado 1,94:1. Os dois últimos não atendem à meta de texto normal; reservar o azul escuro proposto para ação com texto branco. A avaliação não comprova conformidade da interface renderizada. Borda clara/branco 1,23:1 não basta como único limite interativo; disabled/branco 2,56:1 não serve para informação necessária habilitada.

### Paleta refinada e estados

[ASSUMPTION] Estes papéis concretizam o contraste escolhido sem copiar os pixels da imagem:

| Superfície/estado | Tokens e regra |
|---|---|
| Sidebar | `{colors.sidebar}` #082344; texto `{colors.sidebar-ink}` branco e secundário `{colors.sidebar-muted}` #CBD5E1 |
| Cabeçalho | Gradiente de `{colors.header-start}` #0D47A1 para `{colors.header-end}` #1565C0 na área de texto branco; azul seed #2196F3 somente em grafismo sem informação sobreposta |
| Marca | `{colors.brand-gold}` #FCA906 em acento gráfico, com `{colors.ink-primary}` quando houver texto; não usar dourado como sinal único de estado |
| Ação | `{colors.action-blue}` #1565C0; hover `{colors.action-hover}` #0D47A1; pressionado `{colors.action-pressed}` #0B3A82; texto branco |
| Foco | Anel 2px + separação 2px: `{colors.focus-light}` em superfícies claras, `{colors.focus-sidebar}` dourado na sidebar e `{colors.focus-header}` branco no cabeçalho. Em botão azul sobre fundo claro, separador branco + anel azul; não usar dourado sobre o extremo #1565C0 |
| Campo interativo | `{colors.border-control}` #64748B quando a borda for necessária para identificar o controle; hairline permanece divisor decorativo |
| No prazo | `{colors.lot-on-time-ink}` #166534 sobre `{colors.lot-on-time-bg}` #F0FDF4 |
| Atrasado | `{colors.lot-delayed-ink}` #991B1B sobre `{colors.lot-delayed-bg}` #FEF2F2 |
| Paralisado | `{colors.lot-paused-ink}` #9A3412 sobre `{colors.lot-paused-bg}` #FFF7ED |
| Concluído | `{colors.lot-complete-ink}` #1E40AF sobre `{colors.lot-complete-bg}` #EFF6FF |

Status sempre combina texto e ícone na cor de tinta do par. Hover pode realçar borda com action-blue, sem mover o card; não revela ações exclusivas. Desabilitado conserva semântica Material e não usa ink-disabled para informação necessária. Tokens owner/admin/pending continuam próprios dos papéis de membros; coincidência de hex não funde significados.

[Evidência de contraste sRGB](.working/contrast-refinement.md): os pares textuais propostos atendem à meta numérica; branco no cabeçalho tem mínimo 5,75:1. Dourado/#1565C0 tem 2,96:1 e fica excluído do foco e de indicadores essenciais nesse fundo. Isso não valida o contraste de uma futura imagem/gradiente renderizado nem certifica a interface.

O ciano `#00B4D8` encontrado em watermark é diferente do seed; [ASSUMPTION] este rascunho prioriza o azul do tema. Tema escuro não foi solicitado/aprovado, embora exista variante escura da logo. Não criar tokens escuros por inferência.

## Typography

**Confirmado:** títulos fortes como no conceito B. **[ASSUMPTION] de calibragem:** manter a família padrão Flutter Material por plataforma, sem fonte externa; a imagem não permite identificar com segurança uma família exata. Os tokens semânticos históricos `title`, `item`, `body`, `meta` e `badge` permanecem para membros e não mudam seus contratos.

| Uso global proposto | Token | Tamanho / entrelinha / peso |
|---|---|---|
| Título principal desktop | `{typography.page-desktop}` | 40 / 48 / 700 |
| Título principal telefone | `{typography.page-mobile}` | 28 / 36 / 700 |
| Seção | `{typography.section}` | 24 / 32 / 700 |
| Nome construtora, ambos | `{typography.constructor-name}` | 20 / 28 / 600 |
| Nome lote, ambos | `{typography.lot-name}` | 18 / 24 / 600 |
| Leitura e entradas | `{typography.reading}` | 16 / 24 / 400 |
| Fase, identificação secundária, status | `{typography.supporting}` | 14 / 20 / 400; status pode usar 600 |
| Botões | `{typography.action}` | 14 / 20 / 600 |

Medidas nominais lógicas (sp no Flutter), não teto para escala do dispositivo. Títulos usam caixa normal; evitar caixa alta em nomes longos. O 11 herdado não é padrão global de informação essencial. Nome e fase refluem, ações não truncam. Valores financeiros alinham casas decimais e preservam unidade/período.

## Layout & Spacing

**Confirmado:** construtoras espaçosas e lotes mais compactos. **[ASSUMPTION] de calibragem:** conservar escala 4/8/12/16/24/32 e acrescentar 40/48; os novos tokens descrevem o global e não substituem a margem 16/24 de membros. Medidas `px` neste contrato significam unidades lógicas (dp no Flutter), não pixels físicos da imagem.

| Medida | Telefone | Desktop |
|---|---|---|
| Margem global | `{spacing.page-mobile}` 16 | `{spacing.page-desktop}` 32 |
| Separação entre seções | 24 | 32 |
| Construtora: padding | `{spacing.constructor-padding-mobile}` 20 | `{spacing.constructor-padding-desktop}` 24 |
| Construtora: distância entre grupos | `{spacing.constructor-gap}` 16 | 16 |
| Construtora: caixa reservada à logo | 64 de altura, imagem contida | 88 de altura, imagem contida |
| Construtora: espaço entre cards | 16 | `{spacing.constructor-grid-gap}` 24 |
| Lote: padding | `{spacing.lot-padding}` 16 | 16 |
| Lote: distância entre informações | `{spacing.lot-gap}` 8 | 8 |
| Lote: espaço entre cards | `{spacing.lot-grid-gap}` 16 | 16 |
| Área interativa mínima | `{spacing.touch-min}` 48 × 48 | 48 × 48 |

Altura dos cards livre. Compactar lotes reduz espaço decorativo e área de marca, preservando tamanho legível e área de ação. Sem grande imagem/área de logo nos lotes. Rodapé separado do conteúdo por 16; dois botões com intervalo 8, quebrando em coluna quando faltar largura. A densidade não cria um seletor novo nem reduz conteúdo autorizado.

Grid dimensionado pela largura útil **depois** de sidebar e margens: mínimo desejado `{components.ConstrutoraCard.min-width-preferred}` 320 e `{components.LoteCard.min-width-preferred}` 280. Se não couber, usar uma coluna com 100% da largura disponível, sem overflow; nenhuma quantidade fixa de colunas. No telefone, coluna única. Texto ampliado pode exigir menos colunas e altura maior. Nome completo e fase continuam visíveis; não impor proporção quadrada.

| Superfície | Telefone | Desktop |
|---|---|---|
| Seleção de construtora | Coluna com identidade e entrada claras | Grid espaçoso, cabeçalho azul marcante e acentos dourados |
| Mapa de Lotes | Coluna compacta com ações confortáveis | Grid compacto, identificação → fase → status → ações |
| Contexto/navegação | Barra superior e drawer herdados; obra legível | Sidebar e barra superior herdadas; contexto visível |
| Lista e detalhe | Sequencial; abrir detalhe | Detalhe próximo é hipótese; dialog de 480px é herança de membros |
| Formulário | Uma coluna, ação sem cobrir teclado | Grupos legíveis e resumo de consequência [ASSUMPTION] |
| Custos | Resumo seguido de composição [ASSUMPTION] | Comparação com contexto e composição [ASSUMPTION] |

800 é referência herdada com conflito `>800` versus `≥800`; `<800`/`≥800` continua fronteira provisória de shell, não regra para forçar várias colunas. Painel acima de 1200px permanece hipótese. Largura máxima de 960px pertence a membros e não limita painéis globais. Não fixar altura do cabeçalho com base no raster: título e conteúdo determinam altura; versão mobile ainda requer referência visual.

## Elevation & Depth

Herdar superfícies planas, lista sem sombra, card de resumo com elevação 1 e overlays Material. O conceito B escolhido acrescenta contraste entre shell azul profundo, cabeçalho azul e cards claros, com profundidade discreta. [ASSUMPTION] Sombras suaves podem separar cards do canvas; valores e efeitos exatos ainda precisam de definição. Nenhum efeito deve competir com estados operacionais.

## Shapes

Herança: `{rounded.sm}` para botões, `{rounded.md}` para chips, `{rounded.lg}` para diálogos. Avatar circular 40px em membros; ícones Material acompanhados de rótulo quando necessários à compreensão. Novas formas de marca não foram definidas.

## Components

Padrões Material não especificados mantêm os defaults da plataforma. Nomes genéricos abaixo descrevem contratos de design [ASSUMPTION], não classes novas a implementar.

| Componente | Contrato visual |
|---|---|
| ConstrutoraCard | Direção B: card claro com área de logo destacada e ação azul; acento dourado na composição. [ASSUMPTION] Logo com proporção preservada; nome como texto principal, CNPJ secundário quando disponível, borda/foco visível. Faixa gráfica superior e sombra suave são acabamento proposto, não obrigação de fotografia por empresa. Logo opcional sem corte ou recoloração; fallback com iniciais. Não acrescentar KPIs sem requisito |
| LoteCard | [ASSUMPTION] Superfície clara, nome/identificação dominante, fase em linha própria e badge de status com ícone + texto. Faixa curta azul e detalhe dourado reforçam marca; status não pinta todo o card. Rodapé com Atualizar lote e Vistorias visíveis, foco claro e alvos confortáveis. Altura adapta a nomes/fases longos; sem percentual, foto ou métrica presumidos |
| SigoLayout | Canvas claro; no desktop, sidebar azul profundo e cabeçalho azul marcante com acentos dourados conforme direção B. SigoTopBar e SigoSidebar herdados; contexto da obra separado do título da tarefa. Aplicação às demais telas ainda é hipótese |
| ActionButton | Primário com action-blue e texto branco; secundário Material; ocupado sem deslocar rótulo; foco visível |
| DataSurface | Lista plana ou superfície branca; título, conteúdo e estado separados; tabela apenas quando a comparação exigir [ASSUMPTION] |
| StatusFeedback | Ícone + texto; diferenciar carregando, local, pendente e confirmado; não depender de snackbar fugaz para estado persistente [ASSUMPTION] |
| FormField | Label persistente, valor, ajuda/erro próximo; aparência Material; obrigatório explícito |
| DetailOverlay | Cabeçalho, conteúdo rolável, ações; sheet mobile/dialog desktop herdados; tamanho acompanha conteúdo |
| MemberRow | Avatar 40px, nome, Cargo · N obras, RoleChip e chevron; nome completo disponível no detalhe |
| RoleChip | Texto e ícone por papel; proprietário âmbar, admin azul, operário neutro, pendente laranja |
| ObraVinculoRow | Nome da obra, papel, estado e menu; vazio com ação Atribuir |
| AtribuirObraDialog | Obra, papel, módulos, resumo e confirmação; hierarquia visual herdada |
| ConfirmDestructiveDialog | Alvo e consequência antes da ação em perigo; cancelar claramente separado |
| EvidenceField | [ASSUMPTION] Prévia, identificação e estado de envio juntos; ausência de evidência não se parece com upload concluído |
| CostSummary | [ASSUMPTION] Total, período/contexto, quatro parcelas do custo e atualização visíveis; números alinhados; sem gráfico decorativo |

### Cards de lotes — proposta para discussão

O usuário pediu atenção específica aos cards de lotes. A anatomia proposta é **identificação → fase atual → status operacional → ações**, conforme [extração do app](.working/lotes-extract.md). [ASSUMPTION] O acabamento segue a direção B: azul em detalhe estrutural, dourado em pequeno acento de marca e corpo branco. O lote representa trabalho em uma obra; não replica a área de logo do card da construtora.

[ASSUMPTION] Exibir **No prazo**, **Atrasado**, **Paralisado** e **Concluído**, com ícones respectivamente de relógio, alerta, pausa e check. As famílias verde, vermelho, laranja e azul são herdadas do card atual; os pares de fundo/texto/ícone agora têm tokens propostos e cálculo de contraste em Colors; a validação visual renderizada permanece pendente. Não usar o dourado de marca como estado operacional. Manter fase e status separados: uma fase não determina automaticamente conclusão nem percentual.

[ASSUMPTION] Telefone usa coluna única e ações de pelo menos 48dp, com nome e fase refluindo; desktop usa grid dimensionado pelo conteúdo, sem fixar quantidade de colunas ou proporção quadrada. O contexto de obra fica no cabeçalho da tela, dispensando repetição em todos os cards da mesma obra. A expressividade não depende de foto, responsável, percentual ou prazo: esses dados não estão prontos para apresentação no modelo consultado. `responsavelId` opcional não equivale a nome exibível. Mock visual dos lotes permanece pendente.

## Do's and Don'ts

| Fazer | Evitar |
|---|---|
| Preservar contexto de construtora, obra e tarefa | Um desktop apenas ampliado sem hierarquia definida |
| Usar texto para estado e consequência | Confundir salva localmente com confirmada no servidor |
| Manter acesso a ações por toque e teclado | Ações essenciais apenas em hover |
| Refinar a composição sem retirar legibilidade | Fonte pequena para “caber tudo” |
| Identificar hipóteses antes de aprovação | Tratar o rascunho como identidade global concluída |

**Direção desktop escolhida:** conceito B, expressivo em azul e dourado, com seleção de construtora como referência inicial. **Preferências confirmadas:** contraste do conceito B, títulos fortes, construtoras espaçosas e lotes compactos. **Calibragem proposta [ASSUMPTION]:** hexadecimais, escala tipográfica e medidas desta rodada. **Pendências:** discutir os valores, renderizar o card de lote e adaptação mobile, conferir logos reais e texto ampliado; nenhum token transforma a logo raster em especificação oficial. A escolha da direção não encerra o design system nem aprova automaticamente todos os detalhes da imagem.
