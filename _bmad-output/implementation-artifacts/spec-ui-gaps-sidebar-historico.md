---
title: 'UX/UI — Correção de Gaps na Sidebar e Visibilidade de Ajustes/Estornos'
type: 'bugfix'
created: '2026-09-17'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Na barra lateral (`sigo_sidebar.dart`), os itens de navegação da construtora (Funcionários RH, Almoxarifado, Financeiro e Membros) dependem exclusivamente de `obra != null`, ficando ocultos para administradores e membros autorizados quando acessam o painel da construtora (`/construtora/:cId`). Além disso, na tela de Almoxarifado (`almoxarifado_list_screen.dart`), o acesso a `StockHistoryScreen` (onde residem o histórico, ajustes de estoque e estornos) não possui affordance visual clara, aparentando que as Stories 3-4 e 3-5 não estão disponíveis na UI.

**Approach:** 
1. Atualizar `sigo_sidebar.dart` para consultar `construtoraPermissionProvider(cId)` caso `obra == null`, exibindo os módulos pertinentes com base nas permissões de construtora (`isAdmin`, `isOwner` ou módulos `rh`, `estoque`).
2. Em `almoxarifado_list_screen.dart`, adicionar ação explícita de histórico (`IconButton(icon: Icon(Icons.history), tooltip: 'Histórico, Ajuste e Estorno')` ou chevron indicativo) nos itens de material, garantindo acesso intuitivo às funcionalidades de ajuste e estorno.

</frozen-after-approval>

## Implementation Notes

- Modificado `app/lib/src/common_widgets/sigo_sidebar.dart`:
  - Adicionada leitura de `construtoraPermissionProvider(cId)` para fallback de escopo de construtora quando fora de uma obra específica (`oId == null`).
  - Derivadas as flags `isConstrutoraAdmin`, `canRh`, `canEstoque`, `canFinanceiro` e `canMembros` combinando privilégios de dev confiável, papel na obra e papel na construtora.
  - Aplicadas as flags nos itens de navegação global, garantindo que usuários com privilégio de construtora vejam os menus de RH, Estoque, Financeiro e Membros no painel da construtora.
- Modificado `app/lib/src/features/almoxarifado/presentation/almoxarifado_list_screen.dart`:
  - Adicionado `CircleAvatar` com `Icons.inventory_2_outlined` no leading para identidade visual do item.
  - Adicionado `IconButton` com `Icons.history` e tooltip explicativo `'Histórico, Ajustes e Estorno'` no trailing de cada linha de material, permitindo acesso imediato e transparente às funcionalidades das Stories 3-4 e 3-5.
  - Adicionados tooltips descritivos em todos os botões de ação (`'Registrar Entrada'`, `'Registrar Saída'`).
- Executado Hot Reload com sucesso via DTD no Flutter Web ativo.
- Validação estática (`flutter analyze`): 0 erros/warnings.
- Validação de testes (`flutter test`): 206/206 testes passaram com sucesso.

