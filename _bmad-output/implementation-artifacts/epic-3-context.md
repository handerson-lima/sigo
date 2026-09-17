# Epic 3 Context: Módulos Core - Estoque e Gestão por Lotes

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Estabelecer a gestão granular por unidades de produção (Lotes e Setores da Obra) e o controle central de estoque e movimentações no SIGO, permitindo o acompanhamento de fases executivas, status de avanço físico e a apropriação confiável de materiais por obra e lote.

## Stories

- Story 3.1: CRUD de Projetos e Lotes (Gestão de Obras e Lotes com fases e status)
- Story 3.2: Estoque - Recebimento no Almoxarifado Central (NF e insumos)
- Story 3.3: Estoque - Saída via requisição por Lote
- Story 3.4: Estoque - Ajustes auditados
- Story 3.5: Estoque - Estorno por movimentação inversa
- Story 3.6: Estoque - Rateio de despesas e frete
- Story 3.7: Monetário em centavos e escalas de estoque

## Requirements & Constraints

- Obras são aninhadas em construtoras (`construtoras/{cId}/obras/{oId}`) e Lotes são subcoleções da obra (`construtoras/{cId}/obras/{oId}/lotes/{lId}`).
- Apenas membros ativos com perfil de administrador da construtora ou administrador da obra (ou dev global confiável) podem criar e atualizar obras e lotes.
- Membros com módulo `lotes` autorizado na obra podem visualizar o mapa de lotes e seu avanço de fases.
- Exclusão física direta de obras e lotes é estritamente bloqueada pelas Security Rules (`allow delete: if false;`).
- Toda mutação deve ser resiliente a cenários offline e respeitar invariantes de integridade do Firestore e convenções do SIGO.

## Technical Decisions

- Arquitetura: Flutter Web/PWA com Riverpod para gerenciamento reativo de estado e GoRouter para roteamento declarativo protegido por `AccessGuard`.
- Modelo de Lote: ID UUID v4, nome/identificação, fase atual (`Fundação`, `Alvenaria`, `Acabamento`, `Entregue`), status (`noPrazo`, `atrasado`, `paralisado`, `concluido`) e timestamp de criação.
- Camada de Dados: `ObraRepository` e `LoteRepository` integrados com `read_cache.dart` e tolerância a indisponibilidade de rede.
- Testes: Testes unitários e de widget isolados com mocks leves dos providers Riverpod e repositórios.

## UX & Interaction Patterns

- Listagem de Obras (`ObrasListScreen`): Exibição de cards de obras da construtora, métricas e ação contextual para administradores e devs criarem novas obras via modal dialog.
- Mapa de Lotes (`LotesListScreen`): Visualização em Grid com cartões coloridos por status e FAB para novo lote.
- Edição de Lote: Modal bottom sheet ou diálogo acionado ao tocar no card do lote para atualizar fase e status em tempo real.
- Formulário de Novo Lote (`AddLoteScreen`): Validação rigorosa de nome não-vazio (sem aceitar apenas espaços), dropdown de fases e seleção de status.

## Cross-Story Dependencies

- Story 3.1 é pré-requisito fundamental para as histórias 3.2 a 3.6, pois saídas de estoque (Story 3.3), apropriações e apontamentos de diário dependem de lotes válidos e ativos pertencentes à obra correspondente.
