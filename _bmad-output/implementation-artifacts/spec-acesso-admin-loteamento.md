---
title: 'Acesso de membros e administradores de loteamento ao fluxo da construtora e hierarquia'
type: 'bugfix'
created: '2026-11-20'
status: 'in-review'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: 'd9de413668729ab6d9b7c8dfe68e473f9dda7e05'
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Um usuário com vínculo de Operário na construtora e papel de **Admin do loteamento** (ou membro ativo em `construtoras/{cId}/obras/{oId}/members/{uid}`) recebe "Acesso Negado" ao abrir a construtora porque `/construtoras/:cId` redireciona para `/construtoras/:cId/loteamentos`, onde o `AccessGuard` e as `firestore.rules` exigem permissão global na construtora e ignoram o vínculo por loteamento/obra.

**Approach:** Alinhar o roteamento de entrada, o `AccessGuard`, as listagens/telas da hierarquia (`loteamentos`, `quadras`, `lotes`, `etapas`, `equipes`), o vínculo entre `obras` e `loteamentos` e as `firestore.rules` para que membros atribuídos a um loteamento/obra acessem diretamente `/loteamentos` filtrado pelos seus vínculos, com poder de gestão estrutural conforme seu papel de loteamento.

## Boundaries & Constraints

**Always:**
- Isolamento multi-tenant e por loteamento: Operário da construtora só lê/opera os loteamentos em que possui vínculo ativo, nunca outros loteamentos da construtora.
- Paridade entre UI (`AccessGuard` e gates de ação nas telas), backend (`setMembership`, consolidação Python) e `firestore.rules` (alteração em `firestore.rules` delegada a `firestore-rules-author`).
- Preservar `trustedDevProvider`, limpeza de cache offline em revogação (`read_cache.dart`), preservação de query/fragment em redirects e labels em pt-BR.

**Never:**
- Conceder permissão global na construtora (`construtora_members`) para contornar acesso por loteamento.
- Quebrar rotas obra-scoped existentes (`/construtoras/:cId/obra/:oId/...`), `collectionGroup('members')` ou fluxos de importação DXF/DWF/PDF.

**Decisions:**
- **D1 — Vínculo `obras` ↔ `/loteamentos`:** Novos/importados loteamentos em `/loteamentos` espelham o documento em `construtoras/{cId}/obras/{loteamentoId}` com o mesmo ID. `AtribuirObraDialog` lista `/loteamentos` unificados com `obras` (e `setMembership` garante o doc em `obras/{id}` se ainda não existir). `Loteamento` aceita campo opcional `obraId` para fallback de registros legados com IDs divergentes (ex.: CAOL VIDA NOVA).
- **D2 — Tela inicial pós-construtora:** Ao tocar na construtora em `Minhas Construtoras`, Operário com vínculo em loteamento(s) também entra em `/construtoras/:cId/loteamentos`, vendo **apenas os loteamentos vinculados** a ele, com acesso à hierarquia (`quadras`/`lotes`/`etapas`/`equipes`) e atalho para o Painel do Loteamento (`/construtoras/:cId/obra/:obraId`).
- **D3 — Poderes do `Admin do loteamento`:** Pode editar os dados do próprio loteamento vinculado e criar/editar/excluir `quadras`, `lotes`, `etapas` e `equipes` dentro dele (além dos módulos operacionais da obra). Criar ou excluir novos loteamentos na construtora continua restrito a Admin/Owner da construtora.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
| :--- | :--- | :--- | :--- |
| ADMIN_LOTEAMENTO | Operário na construtora + `Admin` na obra/loteamento `L1` | Entra em `/loteamentos` vendo só `L1`; abre Painel `/obra/:oId` e cria/edita quadras/lotes/etapas de `L1` | N/A |
| CROSS_LOTEAMENTO | Operário `Admin` de `L1` tenta deep-link para `/loteamentos/L2/quadras` | `AccessGuard` retorna `AccessDeniedScreen`; Firestore retorna `permission-denied` | Bloqueio na UI e regras |
| LEGADO_OBRA_ID | `Loteamento` `L1` possui `obraId: O1` (`L1 != O1`) e membro está em `obras/O1/members` | App e `firestore.rules` resolvem o escopo efetivo (`O1`) e liberam acesso a `L1` | Fallback para `loteamentoId` se `obraId` ausente |
| OPERARIO_SEM_VINCULO | Operário na construtora sem nenhum vínculo ativo em `obras/*/members` | Entra em `/loteamentos` e vê estado vazio contextual sem acesso a dados | Sem erro `permission-denied` |

</frozen-after-approval>

## Code Map

- `app/lib/src/features/construtoras/presentation/construtoras_list_screen.dart:72-92` -- Card da construtora: direcionar também não-admins ativos (ou `/construtoras/:cId` redirect) para `/loteamentos`.
- `app/lib/src/features/construtoras/routing/construtora_routes.dart:38-80` -- `ConstrutoraPaths.detail` redireciona para `/construtoras/:cId/loteamentos`.
- `app/lib/src/common_widgets/access_guard.dart:9-72` -- Quando `obraId != null` (ou escopo `loteamentoId`), resolver `obraId` efetivo e validar via `currentPermissionsProvider`. Para `/loteamentos` raiz (`loteamentoScope == false`), permitir membro ativo da construtora (lista será filtrada).
- `app/lib/src/features/obras/presentation/current_permissions_provider.dart:11-81` -- Reutilizar `construtoraPermissionProvider`, `obraDocProvider`, `currentPermissionsProvider`; adicionar helper/provider de `obraIds` ativos do usuário na construtora e resolução `loteamentoId -> obraId` efetivo.
- `app/lib/src/features/loteamentos/domain/loteamento.dart` (e `.g.dart`), `loteamento_repository.dart:20-110`, `loteamento_summary_provider.dart:160-248` -- Adicionar `obraId` opcional em `Loteamento`; espelhar em `obras/{id}` ao criar; filtrar queries de `/loteamentos`, `quadras` e `lotes` pelos `loteamentoId`/`obraId` vinculados quando o usuário não tiver permissão global na construtora.
- `app/lib/src/features/loteamentos/routing/loteamentos_routes.dart`, `quadras_routes.dart`, `lotes_routes.dart`, `etapas_routes.dart`, `equipes_routes.dart` -- Passar escopo do loteamento (`loteamentoId`) ao `AccessGuard` nas rotas filhas de `:loteamentoId`; em `lotes/novo`, manter `adminOnly: true` agora avaliado no escopo da obra/loteamento.
- `app/lib/src/features/loteamentos/presentation/loteamentos_list_screen.dart`, `quadras_list_screen.dart`, `lotes_list_screen.dart`, `lote_detail_screen.dart`, `etapas_list_screen.dart`, `equipes_list_screen.dart`, `loteamento_summary_card.dart` -- Substituir checks de construtora-admin por permissão efetiva do loteamento (`obraAdmin`), mantendo criação/importação de novo loteamento exclusiva de construtora-admin, e adicionar atalho para o Painel do Loteamento (`/obra/:oId`).
- `app/lib/src/features/obras/presentation/obra_dashboard_screen.dart`, `app/lib/src/common_widgets/sigo_sidebar.dart`, `sigo_top_bar.dart` -- Gate do card/item "Loteamentos" passa a aceitar `obra.isActive && (obra.isAdmin || modules.contains('lotes'))`; `LoteamentoSwitcher` exibe apenas loteamentos acessíveis.
- `app/lib/src/features/construtoras/presentation/membros_providers.dart` e `widgets/atribuir_obra_dialog.dart` -- Unificar lista de atribuição (`obras` + `/loteamentos` sem duplicar); `functions/src/index.ts:202-259` (`setMembership`) cria/atualiza `obras/{o}` se for um `loteamento` existente sem doc espelho; `functions-python/firestore_utils.py:490-515` cria doc espelho em `obras/{loteamento_id}` ao consolidar.
- `firestore.rules:196-268` -- Delegar a `firestore-rules-author`: `loteamentos`/`quadras`/`lotes`/`etapas`/`equipes` passam a aceitar `obraMember`/`module(..., 'lotes')` para leitura (com query filtrada) e `obraAdmin` para criação/edição/exclusão em `quadras`/`lotes`/`etapas`/`equipes` e `update` em `loteamentos`.
- Testes: `app/test/access_guard_test.dart`, `app/test/loteamento_quadra_lote_navigation_test.dart`, testes das telas da hierarquia, `functions/test/security-rules.test.cjs`.

## Tasks & Acceptance

**Execution:**
- [x] `app/lib/src/features/loteamentos/domain/loteamento.dart` + `loteamento_repository.dart` + `loteamento_summary_provider.dart` -- Adicionar `obraId` opcional, espelho em `obras` na criação e queries escopadas por vínculos para não-admins -- evitar `permission-denied` em queries por construtora.
- [x] `app/lib/src/features/obras/presentation/current_permissions_provider.dart` + `app/lib/src/common_widgets/access_guard.dart` -- Resolver escopo efetivo (`loteamentoId` / `obraId`) e suportar acesso por loteamento nas rotas filhas + acesso à lista filtrada de `/loteamentos` -- respeitar D1/D2/D3.
- [x] `app/lib/src/features/{loteamentos,quadras,lotes,etapas,equipes}/routing/*_routes.dart` + `construtoras_list_screen.dart` -- Roteamento de entrada e passagem do escopo `:loteamentoId` ao `AccessGuard` -- impedir bypass entre loteamentos.
- [x] `app/lib/src/features/{loteamentos,quadras,lotes,etapas,equipes}/presentation/*.dart`, `obra_dashboard_screen.dart`, `sigo_sidebar.dart`, `sigo_top_bar.dart` -- Alinhar gates de UI com `obraAdmin` e adicionar acesso ao Painel `/obra/:oId` -- paridade UI x regras.
- [x] `app/lib/src/features/construtoras/presentation/membros_providers.dart`, `atribuir_obra_dialog.dart`, `functions/src/index.ts`, `functions-python/firestore_utils.py` -- Unificar listagem de atribuição e espelhamento automático `loteamentos` ↔ `obras` -- garantir vínculo único daqui em diante.
- [x] `firestore.rules` + `functions/test/security-rules.test.cjs` -- Delegar a `firestore-rules-author` atualização das regras da hierarquia e adicionar testes da matriz I/O.
- [x] `app/test/**` -- Cobrir matriz I/O em `access_guard_test.dart`, `loteamento_quadra_lote_navigation_test.dart` e testes das telas modificadas.

**Acceptance Criteria:**
- Given Operário da construtora atribuído como `Admin do loteamento` em `L1`, when acessa a construtora, then abre `/loteamentos` vendo apenas `L1`, navega para `/loteamentos/L1/quadras`, cria/edita quadras/lotes/etapas e acessa o Painel `/obra/:oId`.
- Given mesmo usuário, when tenta acessar `/loteamentos/L2/...` (onde não tem vínculo), then vê `AccessDeniedScreen` na UI e o Firestore nega leitura/escrita.
- Given Operário sem nenhum vínculo de loteamento, when entra em `/loteamentos`, then vê estado vazio sem erro de permissão.

## Implementation Notes

## Spec Change Log

## Review Triage Log

## Verification

**Commands:**
- `cd app && flutter analyze && flutter test` -- expected: zero erros e suíte verde.
- `cd functions && npm test` (com Firestore Emulator se disponível) -- expected: testes de functions e security-rules verdes.
