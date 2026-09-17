---
title: 'UX/UI — Corrigir gaps de navegação: sidebar e dashboard'
type: 'bugfix'
created: '2026-09-17'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Várias funcionalidades já implementadas e roteadas (Almoxarifado/Estoque, Financeiro, Membros e Cadastro de Funcionários RH) não possuem entrada na sidebar (`sigo_sidebar.dart`) nem cards no dashboard (`obra_dashboard_screen.dart`), tornando-as invisíveis ao usuário final.

**Approach:** Adicionar os itens de navegação ausentes à sidebar e ao dashboard, respeitando as regras de permissão já existentes (`normalizeModule`, `isAdmin`, `obra.isActive`) e sem alterar lógica de roteamento ou AccessGuard.

## Implementation Notes

### Módulos e rotas ausentes da sidebar (nível construtora)

| Módulo | Rota | Permissão |
|---|---|---|
| Almoxarifado | `/construtora/:cId/almoxarifado` | `module: 'estoque'` |
| Financeiro | `/construtora/:cId/financeiro` | `adminOnly` |
| Membros | `/construtora/:cId/membros` | `adminOnly` |
| Funcionários (RH) | `/construtora/:cId/rh/funcionarios` | `module: 'rh'` |

### Módulos ausentes do dashboard (cards)

| Card | Rota | Condição |
|---|---|---|
| RH / Chamada Diária | `/construtora/:cId/obra/:oId/rh/chamadas` | `isAdmin \|\| modules.contains('rh')` |
| Almoxarifado | `/construtora/:cId/almoxarifado` (nível construtora, link do dash) | `isAdmin \|\| modules.contains('estoque')` |
| Financeiro | `/construtora/:cId/financeiro` | `isAdmin` |

### Arquivos e símbolos relevantes

- `app/lib/src/common_widgets/sigo_sidebar.dart` — lista de nav items divididos em "por obra" (`oId != null`) e "navegação global" (sempre). Novos items de nível construtora devem ir na seção "NAVEGAÇÃO GLOBAL".
- `app/lib/src/features/obras/presentation/obra_dashboard_screen.dart` — seção `Módulos Disponíveis` usa `Wrap + SigoModuleCard`. Basta adicionar mais `if (canX) SigoModuleCard(...)`.
- `app/lib/src/common_widgets/sigo_module_card.dart` — widget existente, só passar `icon`, `title`, `onTap`.
- `normalizeModule()` em `contracts.dart` — aliases: `'almoxarifado' => 'estoque'`, `'recursos_humanos' => 'rh'`.
- `currentPermissionsProvider` em dashboard: `activeMember.isAdmin` e `activeMember.modules.map(normalizeModule)` já disponíveis.

### Regras para a sidebar

- Itens "por obra" (`oId != null`): Chamada Diária já existe. Adicionar nenhum novo aqui (RH-funcionários é nível construtora).
- Itens "NAVEGAÇÃO GLOBAL" (abaixo da `const SizedBox(height: 24)` que separa as seções, dentro do bloco `if (oId != null)`): adicionar Almoxarifado, Financeiro e Membros condicionados a `cId != null`.
- Funcionários RH: adicionar depois de "Fila deste dispositivo", condicionado a `cId != null && (isDev || obra?.isAdmin == true || obra?.modules.map(normalizeModule).contains('rh') == true)`.

Nota: Membros e Financeiro são `adminOnly`. Checar `obra?.isAdmin == true` ou `construtoraAdmin`. Para simplificar, usar `isDev || (cId != null && obra?.isAdmin == true)` como guard para Membros e Financeiro na sidebar, já que `construtoraPermission` não está carregado no sidebar — alternativa: verificar pelo `isDev || obra?.isAdmin`. **Decisão de implementação:** usar `isDev || obra?.isAdmin == true` (já disponível em scope).

### Regras para o dashboard

- `canRh`: `activeMember.isAdmin || activeMember.modules.map(normalizeModule).contains('rh')`
- `canEstoque`: `activeMember.isAdmin || activeMember.modules.map(normalizeModule).contains('estoque')`
- Cards RH e Almoxarifado adicionados ao `Wrap` de módulos existente.
- Card Financeiro: somente `activeMember.isAdmin`.
- Links de Almoxarifado e Financeiro apontam para rotas nível construtora (`/construtora/$construtoraId/almoxarifado`).
- Link RH aponta para `/construtora/$construtoraId/obra/$obraId/rh/chamadas`.

</frozen-after-approval>
