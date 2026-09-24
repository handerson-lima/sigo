# Epic 11 Context: Drill-down do Dashboard

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

O usuário navega pela hierarquia estrutural após o login para detalhar os componentes da construção, permitindo visualização granular das informações. O objetivo principal é viabilizar o roteamento e a navegação através de uma nova estrutura de 5 níveis de drill-down.

## Stories

- Story 11.1: Navegação Loteamento → Quadra → Lote
- Story 11.2: Navegação Lote → Setor → Equipe

## Requirements & Constraints

- A hierarquia de navegação deve contemplar exatamente 5 níveis: Loteamentos -> Quadras -> Lotes -> Setores -> Equipes.
- O estado de navegação precisa ser capturado diretamente na URL para permitir deep-linking e breadcrumbs, sem dependência de estado em memória.
- A atribuição de permissões deve permitir leituras locais em níveis granulares da hierarquia.

## Technical Decisions

- **Modelo de Dados (Firestore):** O banco de dados deve modelar os 5 níveis usando subcoleções estritas: `loteamentos/{id}/quadras/{id}/lotes/{id}/setores/{id}/equipes/{id}` sob a construtora raiz.
- **Roteamento (GoRouter):** As rotas devem espelhar a estrutura de dados (ex: `/loteamentos/:lId/quadras/:qId/lotes/:loId/setores/:sId/equipes/:eId`) utilizando parâmetros de rota (`path parameters`).
- **Segurança (ACL):** As regras do Firestore (`firestore.rules`) precisam aplicar as validações de segurança considerando os contextos aninhados (baseado no nó atribuído).

## Cross-Story Dependencies

- As rotas e UI base do Loteamento ao Lote (Story 11.1) formam o alicerce no GoRouter e nas telas que os Níveis 4 a 5 (Story 11.2) devem expandir.
