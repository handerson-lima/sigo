---
title: 'Acesso de membros e administradores de loteamento ao fluxo da construtora e hierarquia'
type: 'bugfix'
created: '2026-11-20'
status: 'done'
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

- Implementação concluída com unificação `obras` ↔ `/loteamentos`, escopo por loteamento no `AccessGuard`, gates nas telas da hierarquia, índices compostos em `firestore.indexes.json` e regras atualizadas em `firestore.rules`.
- Ajuste final pós-revisão em produção: `watchLoteamentosByObraIds` usa leitura direta `doc(obraId)` + fallback em `construtoras/{c}/obras/{obraId}` (para obras legadas sem doc em `/loteamentos`) e `firestore.rules` separa `allow get`/`allow list` em `/loteamentos/{id}` com curto-circuito em `hierarchyObraMember`/`hierarchyObraAdmin`.
- Publicado no Firebase (`sigo-c2eb2`) via `firebase deploy --only firestore:rules,firestore:indexes`.

## Spec Change Log

## Review Triage Log

- `medium` **EC1** (`loteamento_repository.dart:110-146`) — `watchLoteamentosByObraIds` descarta `lastError` se outro stream emitir lista (mesmo vazia). Verificado no diff. → `patch`.
- `medium` **EC2** (`loteamento_repository.dart:287-296`) — `watchLoteamentosProvider` converte erro de `construtoraPermissionProvider`/`userActiveObraIdsProvider` em lista vazia em vez de propagar erro. Verificado no diff. → `patch`.
- `low` **EC3** (`sigo_sidebar.dart:28-32`) — Trailing slash em `/construtoras/c1/loteamentos/` gera `pathSegments[3] == ''` e path inválido `obras//members/`. Verificado no diff. → `patch`.
- `low` **EC4** (`sigo_top_bar.dart:80-84`) — Trailing slash em `/construtoras/c1/loteamentos/` gera `switcherScopeId == ''`. Verificado no diff. → `patch`.
- `low` **EC5** (`access_guard.dart:79-88`) — `obraDocAsync` não aguarda loading quando aplicável, podendo piscar filho antes de bloquear obra inativa. Verificado no diff. → `patch`.
- `medium` **EC6** (`current_permissions_provider.dart:168-183`) — `effectiveLoteamentoObraIdProvider` ignora `loteamentosAsync.hasError` e cai em fallback `loteamentoId`, negando legado `obraId != id`. Verificado no diff. → `patch`.
- `medium` **EC7** (`loteamentos_list_screen.dart:109-127`) — `onPainelTap` habilitado para `hasGlobalLotes` e `!isConstrutoraMember`, levando a `AccessDeniedScreen` sem vínculo na obra. Verificado no diff. → `patch`.
- `medium` **EC8** (`quadras_list_screen.dart:34-49`) — Botão `quadras-painel-loteamento-btn` sempre visível mesmo para usuário sem vínculo na obra. Verificado no diff. → `patch`.
- `low` **EC9** (`loteamento_repository.dart:161-176`) — `createLoteamento`/`createLoteamentoEmMassa` sobrescrevem `obras/{effectiveObraId}` mesmo quando `obraId` explícito aponta para obra existente. Verificado no diff. → `patch`.
- `low` **EC10** (`loteamentos_list_screen.dart:633-666`) — `_EditLoteamentoDialog` sem `maxLength` alinhado às regras do Firestore. Verificado no diff. → `patch`.
- `medium` **EC11** (`membros_providers.dart:119-137`) — `obrasELoteamentosAtivosProvider` usa `.value ?? []` de `watchLoteamentosProvider`, ocultando loading/erro. Verificado no diff. → `patch`.
- `low` **EC12** (`functions/src/index.ts:244-252`) — `membership` não consulta `loteamentos.where('obraId', '==', o)` se obra espelho estiver ausente em caso legado. Verificado no diff. → `patch`.
- `medium` **EC13** (`firestore.rules:235-285`) — `allow update` em `quadras`/`lotes`/`etapas`/`equipes` valida todos os campos com `optHierarchyStr`, podendo bloquear updates parciais em docs legados. Verificado em `firestore.rules`. → `patch`.
- `medium` **EC14** (`firestore.rules:14,213-227,314-390`) — `obraMember` não checa `obras/{o}.isActive` (divergindo do `AccessGuard`); leitura de `loteamentos`/`quadras`/`lotes` por `obraMember` é necessária ao `LoteHierarchySelector`. Verificado em `firestore.rules` e `lote_hierarchy_selector.dart`. → `patch` (checar `activeObra(c, o)`).
- `medium` **EC15** (`loteamentos_list_screen.dart:109-127`) — Mesmo problema de paridade UI×guard do botão Painel reportado em EC7/EC8. Verificado no diff. → `patch`.
- `medium` **BH1** (`loteamento_repository.dart:173-176`, `firestore.rules:99`) — `updateLoteamento` não sincroniza `name` com `obras/{effectiveObraId}`, envia `toJson()` inteiro (sobrescrevendo `Timestamp` `createdAt`) e `obras/{o}` `update` exige `admin(c)`. Verificado no código. → `patch`.
- `medium` **BH2** (`firestore.rules:235-244,314-327`) — `isValidLoteamento` não valida `proprietario*`/`responsavelTecnico*`, aceita `name` vazio/nulo, e `update` por `obraOnlyAdmin` não restringe `affectedKeys().hasOnly(...)` nem protege `createdAt`. Verificado em `firestore.rules`. → `patch`.
- `high` **BH3** (`firestore.indexes.json`) — Faltam índices compostos `(construtoraId, __name__)`/`(construtoraId, obraId)` em `loteamentos` e `(construtoraId, loteamentoId)` em `quadras` e `lotes` para produção. Verificado em `firestore.indexes.json`. → `patch`.
- `high` **BH4** (`atribuir_lotacao_lote_sheet.dart`, `equipes_list_screen.dart`, `firestore.rules:49-58`) — `ADMIN_LOTEAMENTO` sem `rh(c)` recebe `permission-denied` em `equipes`/`funcionarios` ao abrir sheets de lotação. Verificado em `firestore.rules` e `funcionario.dart`: liberar `read: if member(c)` apenas em `equipes` (sem dados sensíveis) e restringir `funcionarios` a `canRh` na UI. → `patch`.
- `medium` **BH5** (`lote_detail_screen.dart:1009-1132`) — Controles de progresso de etapa ficam habilitados sem `isAdmin`, levando a `permission-denied` para não-admin. Verificado em `lote_detail_screen.dart`. → `patch`.
- `medium` **BH6** (`loteamento_repository.dart`, `loteamento_summary_provider.dart`) — Erros silenciados (EC1/EC2) e `StreamController` não fechado em `onCancel` em `watchLoteamentosByObraIds` e `_watchLoteamentoSummaries`. Verificado no diff. → `patch`.
- `medium` **BH7** (`loteamentos_list_screen.dart`, `quadras_list_screen.dart`, `sigo_sidebar.dart`) — Botão Painel / item `Dashboard` na sidebar exposto sem `obraMember` (EC7/EC8/EC15). Verificado no diff. → `patch`.
- `high` **BH8** (`access_guard.dart:79-116`) — `obraDocProvider` dispara `permission-denied` (limpando cache em `read_cache.dart`) para usuário apenas com módulo central `lotes`, contorna `isActive == false`, não trata `om.hasError` nem verifica existência do loteamento na construtora. Verificado no diff e `read_cache.dart`. → `patch`.
- `medium` **BH9** (`functions/src/index.ts`, `membros_providers.dart`, `membros_screen.dart`) — Fallback `obraId` em `membership` (EC12), loading/erro em `obrasELoteamentosAtivosProvider` (EC11) e filtro de `MembrosScreen` ainda usando apenas `obrasAtivasProvider`. Verificado em `membros_screen.dart`. → `patch`.
- `medium` **BH10** (`obra_dashboard_screen.dart:35-38`, `sigo_sidebar.dart:91-94`) — `ObraDashboardScreen` não usa `isConstrutoraAdminMember`; `SigoSidebar` inclui `obra.isAdmin` em `canMembros`, exibindo link para `/membros` que nega acesso a `ADMIN_LOTEAMENTO`. Verificado nos arquivos. → `patch`.
- `false` **BH11** (`firestore.rules:395-402`, `firestore_utils.py:506-519`) — `loteamentos_drafts` permitindo `member(c)` é contrato existente validado em `security-rules.test.cjs` (teste 9.1), e `consolidate_approved_draft` só escreve `obras/{loteamento_id}` quando `not target_loteamento_id` (loteamento novo); overwrite em `createLoteamento` com `obraId` explícito já tratado em EC9.
- `medium` **BH12** (`app/test/**`, `functions/test/**`) — Lacunas de cobertura de testes detalhadas nos achados pré-verificados de `verification-gap` (VG1–VG7). → `patch`.
- `medium` **VG1** (`loteamento_repository.dart:71-159,283-314`, `current_permissions_provider.dart:139-164`) — Pré-verificado: `watchLoteamentosByObraIds`, `userActiveObraIdsProvider` e caminho filtrado de `watchLoteamentosProvider` sem execução real em testes. → `patch`.
- `medium` **VG2** (`loteamento_summary_provider.dart:164-390`) — Pré-verificado: `_watchLoteamentoSummaries` com `scopedLoteamentoIds` sem execução em testes. → `patch`.
- `medium` **VG3** (`functions/src/index.ts:241-271`) — Pré-verificado: fallback de `membership` criando espelho `obras/{o}` a partir de `loteamentos/{o}` sem teste em `functions/test/integration.cjs`. → `patch`.
- `low` **VG4** (`loteamento_repository.dart:161-171`) — Pré-verificado: escrita do espelho em `createLoteamento` sem asserção em `lote_etapas_atomic_test.dart`. → `patch`.
- `medium` **VG5** (`sigo_sidebar.dart:28-42,282-287`, `obra_dashboard_screen.dart:157-162`) — Pré-verificado: visibilidade de `Loteamentos` e resolução de `oId` em `/loteamentos/:id` sem verificação em `sigo_sidebar_test.dart`. → `patch`.
- `medium` **VG6** (`access_guard.dart:79-117`) — Pré-verificado: `AccessGuard` com `loteamentoId` para obra inativa, membro não-admin e fallback `centralModules` sem teste. → `patch`.
- `low` **VG7** (`sigo_top_bar.dart:312-315,371-373`) — Pré-verificado: `LoteamentoSwitcher` para loteamento legado (`obraId != id`) sem teste. → `patch`.
- `medium` **VG-Other1** (`access_guard.dart:100-116`) — Usuário com `centralModules: ['lotes']` e vínculo na obra sem `'lotes'` (ex.: só `'diario'`) é negado no `if (obra != null)` antes do fallback de `centralModules`. Verificado no diff. → `patch`.
- `medium` **VG-Other2** (`loteamento_repository.dart:110-116`) — Mesmo bug de descarte de erro em `watchLoteamentosByObraIds` de EC1. Verificado no diff. → `patch`.
- `medium` **VG-Other3** (`loteamento_repository.dart:173-176`) — Mesmo bug de dessincronização de `name` em `updateLoteamento` de BH1. Verificado no diff. → `patch`.

## Verification

**Commands:**
- `cd app && flutter analyze && flutter test` -- expected: zero erros e suíte verde.
- `cd functions && npm test` (com Firestore Emulator se disponível) -- expected: testes de functions e security-rules verdes.
