---
title: 'Story 2.7 — Isolamento de Operações'
type: 'feature'
created: '2026-09-16'
status: 'done'
baseline_commit: '70b05392595ede0c8046d70e56357553661e8715'
route: 'dispatch'
review_loop_iteration: 1
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-2-context.md'
  - '{project-root}/docs/task.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Usuários do SIGO frequentemente gerenciam ou atuam em múltiplas obras e construtoras no mesmo navegador. Quando a fila local de operações armazena itens de diferentes contextos (construtoras, obras e módulos), a ausência de isolamento granular gera:
1. Contaminação visual: a interface de uma obra específica (ex: Diário da Obra A) pode exibir contadores de pendências ou falhas originadas na Obra B.
2. Bloqueio cruzado em cadeia (head-of-line blocking): falhas de permissão (`authorization_rejected`) ou conflitos em operações de uma obra poderiam suspender ou atrasar a fila de operações legítimas de outras obras.
3. Despacho fora de contexto: ausência de garantia de que a sincronização possa ser acionada especificamente para a obra onde o usuário está trabalhando no momento (`obraId`), evitando custos de rede desnecessários com outras obras inativas.

**Approach:** Implementar isolamento estrito de operações por escopo hierárquico `(uid, construtoraId, obraId, action/modulo)`:
1. Enriquecer os registros de operação com metadados explícitos de escopo (`construtoraId`, `obraId`) tanto no topo da linha persistida quanto no `payload` e na `key`.
2. Habilitar filtros por escopo nas consultas do store IndexedDB (`queue.js`) e armazenamento nativo (`queue_store_native.dart`).
3. Estender `OperationQueue` com suporte a consultas e monitoramentos escopados (`list`, `watch`, `pendingCount`, `failedCount`, `syncedCount`) e sincronização seletiva (`sync({String? onlyKey, String? construtoraId, String? obraId})`).
4. Assegurar que rejeições de autorização ou falhas em uma obra permaneçam isoladas, sem interromper ou desestabilizar o fluxo de outras obras do mesmo usuário.

## Boundaries & Constraints

**Always:**
- Toda operação enfileirada (`enqueue`) deve obrigatoriamente persistir os campos `construtoraId` e `obraId` (extraídos do payload quando aplicável ou fornecidos como parâmetros de escopo) no registro raiz da operação.
- A listagem com filtro (`list(obraId: ...)`) deve retornar estritamente as operações pertencentes ao escopo especificado do usuário ativo.
- As contagens de status (`pendingCount`, `failedCount`, `syncedCount`) devem suportar parametrização por obra para alimentar com precisão os indicadores de UI de cada obra.
- A sincronização escopada `sync(obraId: ...)` deve processar apenas as operações pertencentes àquela obra, ignorando candidatos de outras obras.
- Operações que resultem em `authorization_rejected` em uma obra devem ficar no estado de rejeição isolado na sua respectiva obra, permitindo que operações pendentes em outras obras prossigam normalmente.

**Never:**
- Nunca permitir que operações enfileiradas na Obra A sejam listadas ou contadas na interface da Obra B.
- Nunca permitir que a falha de uma operação na Obra A aborte ou trave a sincronização de itens da Obra B durante um ciclo de sincronização geral.
- Nunca permitir que um usuário acesse ou sincronize operações pertencentes a outro `uid`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Listagem escopada por obra | Usuário possui pendências na Obra 1 e Obra 2; chama `list(obraId: 'ob-1')` | Retorna exclusivamente as operações associadas à `ob-1` | Não expõe itens de `ob-2` |
| Contagem particionada na UI | Tela da Obra 1 consulta `pendingCount(obraId: 'ob-1')` | Retorna contagem precisa apenas das operações da Obra 1 | Retorna 0 se vazio |
| Sincronização escopada por obra | Usuário em modo online na Obra 1 aciona `sync(obraId: 'ob-1')` | Apenas itens da Obra 1 são reivindicados (`claim`) e executados | Itens de outras obras permanecem `pending` para seu momento |
| Rejeição de permissão isolada | Operação da Obra 1 rejeitada com `permission-denied`; Obra 2 possui operação válida | Operação da Obra 1 vai para `authorization_rejected`; ciclo continua e operação da Obra 2 conclui com `synced` | Sem bloqueio cruzado |
| Operação sem obra (escopo central/construtora) | Operação de módulo corporativo (ex: financeiro/compras central) com `obraId == null` | Identificada como escopo de construtora; filtrável por `construtoraId` | Não colide com nenhuma obra específica |

</frozen-after-approval>

## Code Map

- `app/lib/src/sync/operation_queue.dart` -- Enriquecimento dos metadados de escopo em `enqueue`, adição de parâmetros de filtro em `list`, `watch`, `pendingCount`, `failedCount`, `syncedCount` e suporte a `obraId`/`construtoraId` em `sync`.
- `app/web/queue.js` -- Suporte a parâmetros opcionais de filtro (`construtoraId`, `obraId`, `action`) na ação `list` das transações do IndexedDB.
- `app/lib/src/sync/queue_store_native.dart` -- Suporte aos parâmetros de filtro de escopo no driver nativo para testes e mobile.
- `app/test/operation_isolation_test.dart` -- Nova suite de testes unitários automatizados validando o isolamento de operações, listagens/contagens particionadas, sincronização escopada e não-bloqueio cruzado em falhas.

## Tasks & Acceptance

**Execution:**
- [x] `app/web/queue.js` -- Atualizar ação `list` para suportar filtros opcionais de escopo (`construtoraId`, `obraId`, `action`).
- [x] `app/lib/src/sync/queue_store_native.dart` -- Atualizar ação `list` nativa para suportar filtros de escopo.
- [x] `app/lib/src/sync/operation_queue.dart` -- Persistir campos raiz `construtoraId` e `obraId` no `enqueue`, adicionar parâmetros de escopo em `list`, `watch`, `pendingCount`, `failedCount`, `syncedCount`, e filtrar no `sync`.
- [x] `app/test/operation_isolation_test.dart` -- Implementar bateria de testes unitários cobrindo todos os cenários da matriz de I/O e edge cases.

**Acceptance Criteria:**
- Given operações gravadas para múltiplas obras e construtoras, when `list` ou contadores forem consultados com filtro de `obraId`, then apenas os itens da respectiva obra são retornados.
- Given uma operação da Obra A que falhe com rejeição de autorização, when a sincronização for executada, then operações pendentes da Obra B são processadas e sincronizadas normalmente sem bloqueio.
- Given a sincronização acionada com `sync(obraId: ...)`, then apenas as operações associadas àquela obra são processadas no lote.

## Implementation Notes

- **queue.js & queue_store_native.dart:** A ação `list` foi enriquecida para aceitar `construtoraId`, `obraId` e `action`, filtrando tanto no registro raiz quanto no `payload` interno com retrocompatibilidade garantida.
- **operation_queue.dart:** Enfileiramento agora grava `construtoraId` e `obraId` no registro raiz. Métodos `list`, `watch`, `sync` e os novos `scopedPendingCount`, `scopedFailedCount`, `scopedSyncedCount` suportam escopo específico por obra e construtora.
- **operation_isolation_test.dart:** Criada suíte com 4 testes unitários cobrindo suporte ao filtro de escopo no JS, listagem e contagens particionadas por obra, sincronização seletiva por partição e isolamento de falhas por permissão sem bloqueio cruzado em cadeia.
- **Verificação:** 61/61 testes Dart passando (`flutter test`), 0 issues no `flutter analyze`, e 5/5 testes Chromium Playwright passando no navegador.

## Spec Change Log

- 2026-09-16: Criação, aprovação e conclusão da implementação da Story 2.7.

## Review Triage Log

- Nenhum issue impeditivo ou regressão identificada durante a revisão e execução das baterias de testes.
