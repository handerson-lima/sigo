---
name: SIGO — Primeira entrega
status: in-progress
updated: 2026-09-23
description: Contrato de UX da primeira entrega; calibração proposta, sem implementação.
sources:
  - ../DESIGN.md
  - ../EXPERIENCE.md
  - ../.memlog.md
  - ../.working/brand-extract.md
  - ../.working/lotes-extract.md
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
  danger: '#DC2626'
typography:
  page-desktop:
    fontSize: 40px
    lineHeight: 48px
    fontWeight: 700
  page-mobile:
    fontSize: 28px
    lineHeight: 36px
    fontWeight: 700
  section:
    fontSize: 24px
    lineHeight: 32px
    fontWeight: 700
  constructor-name:
    fontSize: 20px
    lineHeight: 28px
    fontWeight: 600
  lot-name:
    fontSize: 18px
    lineHeight: 24px
    fontWeight: 600
  reading:
    fontSize: 16px
    lineHeight: 24px
    fontWeight: 400
  supporting:
    fontSize: 14px
    lineHeight: 20px
    fontWeight: 400
  action:
    fontSize: 14px
    lineHeight: 20px
    fontWeight: 600
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
---

## Brand & Style

Primeira entrega do design system SIGO: tema compartilhado, navegação existente, seleção de construtora, Mapa de Lotes, Novo Lote e atualização de fase/status. O usuário confirmou direção expressiva, contraste azul profundo/azul vivo/dourado, títulos fortes, construtoras espaçosas e lotes compactos. Praticidade no telefone orienta as adaptações.

Flutter Material 3 é o sistema herdado: sem fonte externa, controles e semântica Material permanecem onde não há diferença especificada. Os tokens são a **baseline proposta de calibração [ASSUMPTION]**, consolidada para planejamento; a aprovação estética não equivale a aprovação individual de pixels. Nenhuma implementação está autorizada por este pacote.

[EXPERIENCE.md](EXPERIENCE.md) define comportamento; [HANDOFF.md](HANDOFF.md) delimita escopo e aceite. Os dois documentos de UX prevalecem sobre imagens em qualquer conflito. Os documentos globais e de Gestão de Membros permanecem preservados.

Usar a marca oficial: [logo para fundo claro](imports/sigo_logo_light.png) e [logo para fundo escuro](imports/sigo_logo_dark.png). Manter proporção e cores originais; não redesenhar nem usar a palavra SIGO gerada nos mocks como asset. A variante escura da logo não implica tema escuro do produto.

## Colors

| Papel | Tokens e aplicação |
|---|---|
| Navegação | `{colors.sidebar}` com `{colors.sidebar-ink}`; informações secundárias em `{colors.sidebar-muted}` |
| Cabeçalho | Gradiente `{colors.header-start}` → `{colors.header-end}`; texto branco; dourado apenas fora da área textual |
| Marca | `{colors.brand-blue}` para grafismos; `{colors.brand-gold}` para faixa/acento decorativo; texto sobre dourado em `{colors.ink-primary}` |
| Superfícies | `{colors.surface-base}` no fundo, `{colors.surface-raised}` nos cards/formulários |
| Texto | `{colors.ink-primary}` e `{colors.ink-secondary}`; disabled não serve para informação necessária |
| Ações | `{colors.action-blue}` e texto branco; hover `{colors.action-hover}`, pressionado `{colors.action-pressed}` |
| Foco | `{colors.focus-light}` em claro, `{colors.focus-sidebar}` na lateral, `{colors.focus-header}` no cabeçalho; anel 2 + separação 2 |
| Controles | `{colors.border-control}` como limite essencial; `{colors.border-hairline}` só separação decorativa |
| Erro | `{colors.danger}` com descrição textual e associação ao campo |
| No prazo | `{colors.lot-on-time-ink}` sobre `{colors.lot-on-time-bg}`, ícone relógio |
| Atrasado | `{colors.lot-delayed-ink}` sobre `{colors.lot-delayed-bg}`, ícone alerta |
| Paralisado | `{colors.lot-paused-ink}` sobre `{colors.lot-paused-bg}`, ícone pausa |
| Concluído | `{colors.lot-complete-ink}` sobre `{colors.lot-complete-bg}`, ícone check |

Dourado é marca, nunca sinal único de status. Status ocupa um badge dentro do card branco; fase e status continuam independentes. A cor da empresa não altera o tema SIGO.

Meta de contraste: 4,5:1 para texto normal e 3:1 para texto grande/indicadores essenciais. [Cálculo sRGB dos pares](.working/contrast-refinement.md): branco/ação 5,75:1, branco/lateral 15,74:1, texto/status ≥6,81:1. Branco sobre dourado não atende texto normal; dourado sobre o extremo claro do cabeçalho (2,96:1) não serve para foco. Cálculo de pares não certifica telas renderizadas.

## Typography

Família padrão Material por plataforma; não tentar adivinhar a fonte dos PNGs. Tokens usam dimensões nominais lógicas, com escala de texto do dispositivo preservada.

| Uso | Token | Tamanho/entrelinha/peso |
|---|---|---|
| Página desktop | `{typography.page-desktop}` | 40/48/700 |
| Página telefone | `{typography.page-mobile}` | 28/36/700 |
| Seção/overlay | `{typography.section}` | 24/32/700 |
| Construtora | `{typography.constructor-name}` | 20/28/600 |
| Lote | `{typography.lot-name}` | 18/24/600 |
| Leitura e entrada | `{typography.reading}` | 16/24/400 |
| Fase, CNPJ, suporte | `{typography.supporting}` | 14/20/400 |
| Ação | `{typography.action}` | 14/20/600 |

Nome, fase, mensagens e botões quebram linha; não encurtar a informação para manter altura. Usar caixa normal. Status pode usar peso 600. A escala maior diminui colunas antes de reduzir legibilidade.

## Layout & Spacing

As medidas `px` dos tokens representam unidades lógicas (dp/sp), não pixels dos mocks. O shell conserva a regra observada: **desktop acima de 800; drawer até 800 inclusive**. Isso resolve, nesta entrega, a hipótese divergente `<800/≥800` do rascunho global sem alterar o breakpoint atual. Sidebar conserva largura expandida 250 e recolhida 72 e destinos existentes.

| Medida | Telefone | Desktop |
|---|---|---|
| Margem útil total do conteúdo | `{spacing.page-mobile}` | `{spacing.page-desktop}` |
| Padding ConstrutoraCard | `{spacing.constructor-padding-mobile}` | `{spacing.constructor-padding-desktop}` |
| Espaço interno / grid construtoras | `{spacing.constructor-gap}` / `{spacing.constructor-grid-gap}` | mesmos tokens |
| Padding / espaço / grid lotes | `{spacing.lot-padding}` / `{spacing.lot-gap}` / `{spacing.lot-grid-gap}` | mesmos tokens |
| Alvo interativo | `{spacing.touch-min}` | `{spacing.touch-min}` |

Margem total não soma padding duplicado do shell e da tela. Até 800: coluna única; acima: tantas colunas quanto couberem na largura útil, com mínimo desejado 320 para construtoras e 280 para lotes. Esses mínimos são limitados à largura disponível: nunca causar rolagem horizontal. Card não tem proporção ou altura fixa. Em desktop estreito com sidebar pode haver somente uma coluna.

Cabeçalho tem título/contexto e ações existentes; altura por conteúdo, sem espaço vertical vazio obrigatório. No telefone o grafismo é discreto e cede espaço à tarefa. Novo Lote fica como ação existente acessível; pode ocupar linha própria, sem bloquear cards. Nenhuma barra de busca é acrescentada.

## Elevation & Depth

Superfícies claras e sombra suave Material em repouso; elevação não comunica status. Hover não move cards. Overlay herda barreira e elevação Material. Não copiar halos, sombras em texto ou manchas geradas nas imagens.

## Shapes

`{rounded.sm}` para ações/campos, `{rounded.md}` para cards/área de identidade, `{rounded.lg}` para borda superior do overlay. Ícones Material; status e fase não usam imagem decorativa. Logo preserva proporção com ajuste contain.

## Components

| Componente | Especificação visual |
|---|---|
| SigoLayout | Lateral profunda, topo expressivo e conteúdo claro; item ativo identificado por fundo, ícone e texto; marca oficial apropriada ao fundo; não copiar menu ilustrativo |
| ConstrutoraCard | Branco, raio 12; área de identidade 64 telefone/88 desktop; nome, CNPJ quando existente e ação visual Acessar construtora. No telefone identidade ao lado do nome se couber; desktop identidade acima. Iniciais como baseline proposta; nome nunca depende da marca |
| LoteCard | Branco, raio 12, pequeno acento azul/dourado; nome → fase → status → ações Atualizar lote/Vistorias. Status ao lado do nome apenas se couber integralmente; senão em linha própria. Sem área decorativa de logo |
| ActionButton | Primário azul/branco; secundário branco com texto/borda azul; alvo ≥48; ocupado mantém rótulo e adiciona indicador Material; estado desabilitado mantém identificação |
| DataSurface | Lista/formulário sobre base clara; formulário em coluna com largura máxima proposta 640, limitado ao espaço útil; altura livre e rolagem vertical |
| StatusFeedback | Texto e ícone, cores semânticas para erro/status; progresso Material com rótulo; mensagens não ficam sobre o acento dourado |
| FormField | Rótulo persistente, corpo 16, borda identificável; erro junto ao campo; dropdown Material sem truncar valor selecionado |
| DetailOverlay | Edição existente em bottom sheet nos dois formatos; largura máxima proposta 640 no desktop, largura disponível no telefone; padding24, conteúdo rolável e área segura/teclado respeitados |

### Referências visuais e diferenças contratuais

| Referência | Decisão que ilustra | Ajustes obrigatórios |
|---|---|---|
| [Construtoras desktop](mockups/construtoras-desktop-refinado-v1.png) | Cabeçalho marcante e cards espaçosos | Remover busca; manter destinos/rótulos reais; usar marca oficial, iniciais e CNPJ real quando disponível |
| [Construtoras telefone](mockups/construtoras-mobile-refinado-v1.png) | Uma coluna, identidade ao lado do nome | Remover busca; nome e ações refluem; sem sombras no texto |
| [Lotes desktop](mockups/lotes-desktop-refinado-v1.png) | Cards compactos e duas ações | Nome/fase/status reais; preservar contexto e permissões, não reproduzir menu fictício |
| [Lotes telefone](mockups/lotes-mobile-refinado-v1.png) | Leitura rápida e status legível | Ações/status podem empilhar; não fixar composição lateral do raster em largura pequena |

As quatro imagens são estudos com dados fictícios, não protótipos funcionais nem fonte de novos requisitos. Formulários, drawer expandido, teclado e estados excepcionais são especificados pelas tabelas; não possuem mock próprio neste pacote.

## Do's and Don'ts

- Manter marca azul/dourado expressiva e leitura clara; não pintar todo o lote pela cor de status.
- Preservar funcionalidades, destinos e autorizações; não importar busca, Minha conta ou indicadores de imagens sem existência comprovada.
- Usar iniciais sem imagem disponível; não inventar propriedade logo, upload ou URL remota.
- Deixar cards crescerem com texto; não reduzir alvos para ganhar densidade.
- Não incluir percentual, foto, prazo ou responsável no lote sem dados/escopo próprios.
