# Epic 1 Context: Configuração Inicial e Autenticação (RBAC)

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Estabelecer a fundação arquitetural e de segurança do SIGO em Flutter Web/PWA e Firebase, implementando controle de acesso baseado em papéis (RBAC) multi-construtora e multi-obra, garantindo que a identificação de usuários, descoberta de obras autorizadas e contexto operacional ativo sejam imediatos, isolados e precisos.

## Stories

- Story 1.1: Projeto Flutter
- Story 1.2: Configurar Firebase
- Story 1.3: Coleção Users
- Story 1.4: Subcoleção Members
- Story 1.5: Descoberta Obras
- Story 1.6: Fluxo Login
- Story 1.7: Seleção Obra
- Story 1.8: Recálculo de Módulos

## Requirements & Constraints

- Autenticação via Firebase Auth vinculada a documentos de perfil na coleção `users/{uid}`.
- O papel privilegiado de desenvolvedor global (`dev`) é validado exclusivamente no servidor via `dev_roles/{uid}.isActive == true`.
- Hierarquia de dados multi-nível: `construtoras/{cId}` e `construtoras/{cId}/obras/{oId}`.
- Associação e permissões residem em `construtoras/{cId}/construtora_members/{uid}` e `construtoras/{cId}/obras/{oId}/members/{uid}`.
- Troca de escopo de obra deve recalcular imediatamente permissões, módulos disponíveis e layout da barra lateral e dashboard sem vazamento de estado anterior nem necessidade de recarga da página.
- Se o usuário não possuir acesso a uma obra ou módulo selecionado, a aplicação deve falhar de forma fechada (deny by default), exibindo tela ou estado de acesso negado.

## Technical Decisions

- **Framework:** Flutter Web / PWA mobile-first com `flutter_riverpod` para gerenciamento de estado e `go_router` para roteamento declarativo.
- **Normalização de Módulos:** Normalizar aliases legados (`rdo` -> `diario`, `almoxarifado` -> `estoque`) via contratos em `contracts.dart`.
- **Cache e Escopo:** Provedor `currentPermissionsProvider.family<ObraMember?, ObraScope>` escopado por `(construtoraId, obraId)` e `read_cache` com isolamento por caminho.
- **Segurança:** Regras do Firestore e Storage aplicadas por construtora/obra, com exceção de suporte para dev global auditado.

## UX & Interaction Patterns

- Sidebar responsiva (`sigo_sidebar.dart`) e barra superior (`sigo_top_bar.dart`) com seletor de obra e itens de menu filtrados pelos módulos autorizados (`diario`, `lotes`, `estoque`, `financeiro`).
- Ao alternar a obra ativa no seletor, os módulos da nova obra devem ser recalculados e refletidos instantaneamente nos menus de navegação e nas telas acessadas.
- Mensagens claras de estado: sem permissão, carregando ou acesso negado.

## Cross-Story Dependencies

- Histórias 1.1 a 1.7 estabeleceram a base Flutter, Firebase, login, descoberta de construtoras e telas de seleção de obra.
- A História 1.8 fecha o ciclo do Épico 1 assegurando a integridade e atualização reativa do contexto ativo e permissões de módulos ao navegar entre obras.
