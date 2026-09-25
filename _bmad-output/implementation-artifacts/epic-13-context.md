# Epic 13 Context: Navegação Hierárquica Loteamento a Equipe

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Este epic implementa a fundação completa de dados e navegação para a nova hierarquia de domínio: Construtora → Loteamento → Quadra → Lote → Etapa → Equipe. Substitui a nomenclatura legada ("Obras", "Setores") pela terminologia correta do negócio e estabelece o esquema relacional flat no Firestore (AD-1) com rotas declarativas aninhadas no GoRouter (AD-2). O epic cobre desde a criação das coleções top-level e models até o drill-down completo de 5 níveis na UI.

## Stories

- Story 13.1: Atualizar esquema de dados raiz no Firestore (Loteamentos a Equipes)
- Story 13.2: Rotas Declarativas e Drill-down Inicial (Construtora → Loteamento → Quadra)
- Story 13.3: Ramificação Específica de Etapas por Lote
- Story 13.4: Navegação Final: Alocação de Equipe na Etapa

## Requirements & Constraints

- **Nomenclatura unificada:** Usar exclusivamente `Loteamento`, `Quadra`, `Lote`, `Etapa`, `Equipe`. Abolir `Obra` e `Setor` em todo código, UI e banco.
- **Esquema Flat (AD-1):** 5 coleções top-level no Firestore (`loteamentos`, `quadras`, `lotes`, `etapas`, `equipes`) com chaves estrangeiras (construtoraId, loteamentoId, quadraId, loteId, etapaId). Zero subcollections.
- **Rotas declarativas (AD-2):** Paths aninhados `/construtoras/:cid/loteamentos/:lid/quadras/:qid/lotes/:ltid/etapas/:etid/equipes`. Estado derivado da URL, não de singletons globais.
- **Hierarquia de etapas fixa por Lote:** Muro → Cinza/1ª → Cinza/2ª → Cinza/3ª → Branca/Acabamento (conforme hierarquia-etapas.md).
- **Segurança:** Read se member(construtoraId), Write se admin(construtoraId) em todas as coleções.
- **Ambiente de dev:** Dados legados de Obras/Setores apagados; sem scripts de migração.
- **Testes:** Cobertura unitária/widget para repositories, models, rotas e breadcrumbs.

## Technical Decisions

- **Models:** Cada entidade tem id, construtoraId, chaves de pai na hierarquia, timestamps (criadoEm, atualizadoEm). Etapa inclui campo `ordem` para ordenação fixa. Equipe inclui `responsavelId`.
- **Repositories:** Usar `StreamProvider.family` com Records para múltiplos IDs (ex: `({String construtoraId, String loteamentoId, String quadraId})`) evitando loops de AsyncLoading.
- **Routing:** Módulos de rota por feature (`loteamentos_routes.dart`, `quadras_routes.dart`, etc.) compostos no router raiz. Redirects de paths pai para listagem filha.
- **Breadcrumbs:** Componente `SigoBreadcrumbs` genérico (já existe em 11.2) derivando labels do path.
- **Security Rules:** Padrão consistente nas 5 coleções - `allow read: if isMember(construtoraId); allow write: if isAdmin(construtoraId);`.

## UX & Interaction Patterns

- **Drill-down sequencial:** Cards clicáveis em cada nível levam à listagem do nível inferior.
- **Breadcrumbs persistentes:** Permitem ascensão direta a qualquer nível ancestral.
- **Estados vazios:** "Nenhum X encontrado" com ação contextual (ex: criar primeiro Loteamento).
- **Responsivo:** Listagens em grid mobile, tabela desktop; bottom sheets mobile / dialogs desktop para detalhes.

## Cross-Story Dependencies

- 13.1 (dados) deve concluir antes de 13.2 (rotas/UI) — repositories e models são pré-requisito.
- 13.2 estabelece o padrão de roteamento e breadcrumbs que 13.3 e 13.4 estendem.
- 13.3 depende da hierarquia de etapas fixa (hierarquia-etapas.md) e do modelo de Etapa.
- 13.4 completa a navegação até Equipe; requer Etapa funcional.
- Dependência com Epic 11 (já implementado 11.1/11.2): 13.2 sobrepõe-se parcialmente a 11.1; 13.3/13.4 estendem além de 11.2 (Setor→Etapa, Equipe). Reconciliar rotas legadas `/obra` → redirect para nova árvore.