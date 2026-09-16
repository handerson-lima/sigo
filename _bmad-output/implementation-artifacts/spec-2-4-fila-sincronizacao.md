---
title: 'Story 2.4 — Fila de Sincronização Durável'
type: 'feature'
created: '2026-09-16'
status: 'done'
baseline_commit: '6b7f406e9b4b965d9c790b3f940f0b6897374231'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-2-context.md'
  - '{project-root}/docs/task.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Operações executadas offline no PWA (como preenchimento de diário de obras, requisições de estoque e aprovações) precisam ser mantidas em fila local durável e processadas com garantias estritas de integridade, controle de concorrência entre abas, suspensão de retentativas em caso de negação de autorização e preservação de dados durante trocas de sessão.

**Approach:** Auditar, tipar e blindar a fila transacional `OperationQueue` com máquina de estados finitos (`pending`, `syncing`, `synced`, `failed`, `conflict`, `authorization_rejected`), isolamento de lease para concorrência multi-aba, validação de integridade de anexos por hash SHA-256 e tolerância a falhas temporárias com backoff exponencial.

## Boundaries & Constraints

**Always:**
- Cada operação na fila possui chave única determinística composta por `[uid, construtoraId, obraId, action, operationId]`.
- Enfileiramento (`enqueue`) com payload e anexos idênticos é estritamente idempotente; submissão do mesmo `operationId` com conteúdo divergente deve lançar erro imediato.
- Operações em andamento utilizam concessão de lease temporário exclusivo (`claim` com TTL de 120s), impedindo que duas abas sincronizem o mesmo registro simultaneamente.
- Em caso de rejeição de permissão no backend (`permission-denied`, `unauthorized`), a operação transiciona para `state: 'authorization_rejected'` e tem novas tentativas automáticas suspensas, evitando loops de rede e bloqueios.
- Erros de precondição ou conflito de dados (`already-exists`, `failed-precondition`, `invalid-argument`) transicionam para `state: 'conflict'` e também suspendem retentativas automáticas.
- Se o usuário ativo mudar durante o ciclo de envio de anexos ou execução da operação, o processo é abortado imediatamente sem avançar o estado para `synced`, preservando os dados da conta de origem.

**Never:**
- Nunca descartar silenciosamente uma operação com falha ou rejeição da fila; todo registro permanece auditável localmente até ação administrativa ou conclusão.
- Nunca transmitir anexos cujo tamanho em bytes ou hash SHA-256 divirja dos metadados gravados no momento da captura.
- Nunca reexecutar comandos com `state: 'synced'` após sincronização bem-sucedida confirmada.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Enfileiramento com sucesso | `enqueue('finalizeDiario', payload, attachments)` | Registro persistido em `operations` com `state: 'pending'` | Erro de cota/disco lança `StateError` descritivo |
| Submissão idempotente divergente | Mesmo `operationId` com payload diferente | Lança `StateError('Identificador já utilizado por outra operação.')` | Operação original mantida inalterada |
| Concorrência entre abas | Aba 1 e Aba 2 tentam sincronizar mesma operação | Apenas uma adquire o lease via `claim`; a outra é ignorada | Sem execução duplicada no backend |
| Rejeição de autorização | Backend retorna `permission-denied` | Operação gravada com `state: 'authorization_rejected'`, retries suspensos | Retém mensagem de erro detalhada |
| Falha temporária de rede | Queda de conexão durante upload ou execução | Operação vai para `state: 'failed'`, incrementa `attempts`, calcula backoff `nextAttemptAt` | Próximo sync tenta após intervalo de backoff |
| Troca de sessão durante sync | Usuário desloga ou troca de conta durante processamento | Lança `StateError('Conta alterada. Operação preservada.')`, aborta sem marcar `synced` | Operação permanece na conta correta |

</frozen-after-approval>

## Code Map

- `app/lib/src/sync/operation_queue.dart` -- Motor central de orquestração da fila de sincronização: métodos `enqueue`, `sync`, `list`, `watch`, gerenciamento de lease e máquina de estados.
- `app/lib/src/sync/queue_store.dart` -- Ponto de entrada de abstração de armazenamento local (`queue_store_web.dart` no navegador, `queue_store_native.dart` no nativo/testes).
- `app/web/queue.js` -- Implementação IndexedDB no cliente web: store `operations`, ações `insert`, `claim`, `finish` e `list`.
- `app/test/operation_queue_test.dart` -- Suite de testes automatizados Dart cobrindo todo o ciclo de vida da fila, concorrência de lease, transição de estados e integridade de anexos.
- `functions/test/queue-browser.cjs` -- Suite Playwright Chromium validando concorrência multi-aba, lease e persistência da fila no navegador real.

## Tasks & Acceptance

**Execution:**
- [x] `app/lib/src/sync/operation_queue.dart` -- Auditar e consolidar tratamento de estados de erro, idempotência e inspeção reativa de status.
- [x] `app/test/operation_queue_test.dart` -- Implementar suite abrangente de testes unitários validando todas as transições de estado, concorrência, integridade de hash e detecção de troca de conta.
- [x] `functions/test/queue-browser.cjs` -- Validar testes end-to-end de fila em navegador real com concorrência de duas abas.

**Acceptance Criteria:**
- Given uma operação enfileirada via `enqueue`, when `sync()` for acionado com conectividade, then os anexos são verificados via SHA-256 e o comando é executado no servidor, finalizando com `state: 'synced'`.
- Given uma falha com código `permission-denied`, when o sync processar a operação, then o estado é atualizado para `authorization_rejected` e nenhuma retentativa automática subsequente é agendada.
- Given duas abas tentando sincronizar a mesma operação pendente, when executarem `claim` concorrentemente, then exatamente uma obtém a concessão de lease e a outra aborta o processamento daquele item.
- Given um arquivo de anexo corrompido cujo hash SHA-256 divirja do metadado, when o sync tentar o envio, then o upload é interrompido e a operação transiciona para `failed` com erro explícito de integridade.

## Implementation Notes

- `app/lib/src/sync/operation_queue.dart`: adicionados getters utilitários reativos `pendingCount`, `failedCount` e `syncedCount`, além de validação estrita de `sessionUid` pós-execução e aborto imediato em trocas de conta sem corrupção de lease.
- `app/test/operation_queue_test.dart`: criada suite unitária com 7 testes cobrindo idempotência idêntica vs divergente, processamento de anexos SHA-256, erro de integridade, classificação de erros Firebase (`authorization_rejected` e `conflict`) e segurança de sessão.
- Validação completa: 47/47 testes passando no Flutter, 5/5 no Playwright Chromium e 0 warnings no `flutter analyze`.

## Spec Change Log

## Review Triage Log

| Reviewer / Layer | Finding / Scope | Verdict | Evidence / Resolution |
|---|---|---|---|
| Blind Hunter | Idempotência e integridade de comandos na fila | OK | Submissões com mesmo id e payload idêntico são idempotentes; payload divergente lança StateError imediato |
| Edge Case Hunter | Concorrência multi-aba e troca de conta durante sync | OK | Lease com TTL de 120s impede execução paralela; troca de conta aborta o comando da sessão anterior preservando dados |
| Verification Gap | Cobertura de testes unitários e de navegador real | OK | 47/47 testes Flutter aprovados, 5/5 testes Chromium Playwright aprovados |
