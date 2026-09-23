# Spine Pair Review — SIGO / primeira entrega

## Overall verdict

O pacote delimita bem a primeira entrega e já oferece contrato utilizável para arquitetura: decisões do usuário, propostas de UX e funcionalidades herdadas estão separadas. A cobertura mecânica é forte; resta explicitar a saída dos overlays durante gravação e remover uma ambiguidade pequena nas margens. A análise se limita ao recorte, sem exigir jornadas de membros, custos ou outros módulos das fontes globais.

## 1. Flow coverage — strong

Pass 1: os requisitos aplicáveis das fontes globais são Escolher construtora, Identificar e atualizar lote e Cadastrar lote; preservam esses nomes em J1–J3. Navegação existente (J0), entrada em Vistorias (J4) e cadastro/troca de logo solicitado posteriormente (J5) completam o recorte. Cada J0–J5 tem protagonista nomeado, passos numerados, clímax e falha (EXPERIENCE.md:100–145). As seis superfícies S0–S5 estão mapeadas a jornadas. A herança de módulos não incluídos não constitui lacuna.

## 2. Token completeness — strong

Pass 1: extraídos 29 tokens de cor, 8 papéis tipográficos, 3 raios, 18 espaçamentos e 9 componentes do frontmatter. Os 29 valores de cor têm hexadecimal; não há tema escuro em escopo. As 78 ocorrências de referências de tokens nos três documentos representam 49 caminhos distintos, todos resolvidos no frontmatter de DESIGN.md. Tipografia usa fontSize/lineHeight/fontWeight; família Material e unidades lógicas são explicitadas (DESIGN.md:163–182). Pares de contraste e metas estão declarados em Colors e na evidência auxiliar. Não foi realizada certificação de interface renderizada.

## 3. Component coverage — strong

Pass 1: SigoLayout, ConstrutoraCard, LoteCard, ActionButton, DataSurface, StatusFeedback, FormField, LogoEditor e DetailOverlay possuem regras visuais (DESIGN.md:204–216) e comportamentais (EXPERIENCE.md:45–57). Badge, dropdown, drawer e indicadores são partes desses componentes ou controles Material herdados, sem necessidade de inventar componentes novos para completar a tabela. Não há nome contratual órfão.

## 4. State coverage — adequate

Pass 1: S0 contempla carregamento/contexto, foco, offline e proteção; S1 contempla carga, dados, vazio por perfil, erro e falha da imagem; S2 contempla carga/dados/vazio/erro, cache e permissão; S3 contempla validação/envio/sucesso/falha; S4 inclui sucesso parcial/incerto; S5 inclui seleção/prévia/inválido/envio/confirmação/falha/offline/revogação. Foco e teclado são regras transversais. A matriz distingue erro de vazio e cache de confirmação remota.

### Findings

- **R1 — medium:** A saída durante gravação não tem regra operacional inequívoca. DetailOverlay diz que fechar descarta edições; LogoEditor diz que Cancelar conserva publicação; Esc fecha quando não invalida operação pendente, mas não se define se Cancelar, Voltar, arraste ou barreira ficam bloqueados durante envio. Em especial, um upload já submetido pode publicar após o usuário interpretar Cancelar como cancelamento da operação (EXPERIENCE.md:56–57, 70, 78, 84; DESIGN.md:215–216). *Fix:* fixar política de saída durante envio para S4/S5 e distinguir cancelar seleção de cancelar operação submetida. Uma baseline possível é impedir dismiss/Cancelar enquanto a confirmação está pendente, anunciar o motivo e oferecer saída segura quando houver falha/resultado incerto; eventual cancelamento real depende de viabilidade explícita. Não prometer interrupção de gravação.

## 5. Visual reference coverage — strong

Pass 1: inventário de mockups contém construtoras-desktop-refinado-v1.png, construtoras-mobile-refinado-v1.png, lotes-desktop-refinado-v1.png e lotes-mobile-refinado-v1.png. Todos têm links inline e propósito/ajustes na tabela de DESIGN.md:218–227. Os dois imports, sigo_logo_light.png e sigo_logo_dark.png, estão ligados na seção de marca (139), com contexto de uso. Não há wireframes nem arquivos órfãos nesses diretórios. A precedência das spines sobre os mocks está expressa (137); EXPERIENCE remete a DESIGN. Tabelas para Novo Lote, Atualizar lote e logo foram aceitas pelo usuário e não representam déficit de imagens.

## 6. Bloat & overspecification — strong

Pass 2: os documentos mantêm recorte pequeno e tabelas apropriadas. HANDOFF agrega escopo, aceite e dependências sem reproduzir jornadas extensas. A repetição curta de medidas e limites críticos em tokens/tabelas facilita extração e não prejudica consumo. Não há detalhamento arquitetural prematuro de storage/API.

## 7. Inheritance discipline — adequate

Pass 1/2: todas as dez entradas de sources resolvem. Os links locais dos três documentos resolvem. Vocabulário de fase/status e os três títulos herdados de jornadas permanecem consistentes. O pacote resolve expressamente o breakpoint >800/≤800 e a existência dos quatro mocks frente a fontes antigas. A logo deixa de possibilidade futura para escopo confirmado; Dev/Painel Dev e proprietário/admin da construtora são delimitados. Nomes de componentes e referências de tokens coincidem entre as spines. Pendências de modelo/storage/mapeamento de papéis estão corretamente destinadas à arquitetura, sem confundir capacidade atual com contrato novo.

### Findings

- **R2 — low:** “Margem útil total do conteúdo” pode significar soma esquerda+direita, enquanto tokens page-mobile 16 e page-desktop 32 também podem ser implementados como inset por lado. O parágrafo evita padding duplicado do shell/tela, mas não resolve essa unidade (DESIGN.md:184–192). *Fix:* escrever explicitamente “inset por lado” ou “soma dos dois lados”, mantendo a regra de não duplicar shell e tela.

## 8. Shape fit — strong

Pass 2: DESIGN apresenta todas as seções canônicas na ordem prescrita. EXPERIENCE contém Foundation, Information Architecture, Voice and Tone, Component Patterns, State Patterns, Interaction Primitives, Accessibility Floor e Key Flows. Responsive & Platform está presente para mobile/desktop. Não há referência a produto externo que exija Inspiration; os conceitos visuais próprios têm tabela específica com decisões e exclusões. HANDOFF é justificável como ponte de recorte/aceite para arquitetura.

## Mechanical notes

- Verificação local de caminhos e referências feita por extração textual de chaves/indentação; sem instalar dependências. Não constitui validação por parser YAML completo.
- Não há diagramas Mermaid no pacote.
- Status in-progress é correto durante esta revisão; fechamento deve refletir triagem dos achados, sem declarar implementação ou aprovação de pixels pelo usuário.
- Fontes globais são referência parcial, não lista de funcionalidades obrigatórias nesta entrega.
- Contagem: critical 0; high 0; medium 1 (R1); low 1 (R2).
