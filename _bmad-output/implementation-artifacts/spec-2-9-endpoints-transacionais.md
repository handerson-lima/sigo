---
title: 'Story 2.9 — Endpoints Transacionais'
type: 'feature'
created: '2026-09-16'
status: 'done'
baseline_commit: 'f2f590564a450bf0b26390b12c5aee4bb71d102c'
route: 'dispatch'
review_loop_iteration: 1
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-2-context.md'
  - '{project-root}/docs/task.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Os comandos críticos da aplicação (movimentações de estoque, quitação de despesas e finalização de diários com anexos) não podem ser executados por meio de escritas parciais ou diretas no Firestore pelo cliente. É essencial que operem exclusivamente através de endpoints transacionais atômicos no servidor (Cloud Functions) que garantam validação de autorização, integridade de dados e retorno estruturado de confirmação para a fila de sincronização (`OperationQueue`) e o `SyncEngine`.

**Approach:** Padronizar e consolidar a infraestrutura de endpoints transacionais no backend (`functions/src/index.ts`) e o canal de execução no cliente Flutter (`OperationQueue`):
1. Garantir que cada comando transacional crítico (`stockCommand`, `payExpense`, `finalizeDiario`) execute 100% de suas mutações dentro de `db.runTransaction` Firestore com reversão atômica em caso de exceção.
2. Evoluir a interface de execução da fila de operações no cliente (`QueueExecute` em `OperationQueue`) para capturar e retornar a resposta estruturada do endpoint transacional, permitindo que os repositórios e a UI acessem o resultado confirmado.
3. Padronizar o mapeamento de exceções e erros transacionais (`failed-precondition`, `already-exists`, `permission-denied`, `invalid-argument`, `unavailable`) para que o cliente classifique precisamente as operações em `conflict`, `authorization_rejected` ou `failed` (apta a retry pelo `SyncEngine`).
4. Desenvolver suites de testes herméticos no backend (Node.js) e no frontend (Flutter) validando atomicidade, tratamento de concorrência e retorno transacional.

## Boundaries & Constraints

**Always:**
- Toda mutação de dados críticos de negócio (saldo de estoque, status/data de pagamento financeiro, consolidação de diário com fotos) deve ocorrer dentro de transação Firestore atômica no backend.
- Falhas em qualquer etapa de validação (permissão, estoque insuficiente, duplicidade de anexo, despesa inexistente) devem abortar a transação sem gravar dados intermediários nem alterar saldos.
- Os endpoints transacionais devem retornar respostas com identificadores estáveis e metadados confirmados (ex: `movementId`, `quantityUnits`, `despesaId`, `diarioId`, `status: 'synced'`).
- A fila de sincronização (`OperationQueue`) deve registrar o resultado da execução transacional e propagar erros com classificação estrita (`conflict`, `authorization_rejected`, `failed`).
- Testes unitários herméticos devem cobrir os fluxos de sucesso, reversão atômica por erro e propagação de códigos de falha.

**Never:**
- Nunca permitir atualização direta de saldos (`quantityUnits`), histórico de movimentações ou confirmação de fotos por meio de escritas diretas do cliente no Firestore.
- Nunca mascarar exceções transacionais de autorização como erros genéricos ou permitir retentativa infinita em operações rejeitadas (`authorization_rejected`).
- Nunca descartar o resultado retornado pelo endpoint transacional no cliente quando este for necessário para conciliação de estado.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Movimentação de estoque válida | Chamada de `stockCommand` com payload válido e saldo suficiente | Transação atualiza `material`, cria `movimentacao`, grava `command` e retorna `{movementId, quantityUnits, quantityScale}` | Aborta transação se saldo insuficiente ou material inválido |
| Concorrência de estoque esgotando saldo | Duas requisições simultâneas de saída que excedem o saldo | Apenas uma transação obtém sucesso; a concorrente falha com `failed-precondition` | Cliente mapeia erro para estado `conflict` |
| Quitação de despesa válida | Chamada de `payExpense` com despesa pendente existente | Transação atualiza despesa para `status: 'pago'`, grava `dataPagamento` e retorna `{despesaId, status: 'pago'}` | Falha com `not-found` se inexistente ou `permission-denied` |
| Finalização de diário com anexo íntegro | Chamada de `finalizeDiario` com hash e tamanho confirmados | Transação confirma diário (`isPendingSync: false`), grava referências e retorna `{diarioId, status: 'synced'}` | Aborta com `failed-precondition` se anexo divergente ou ausente |
| Retorno transacional no cliente | `OperationQueue.sync` executa callable com sucesso | Operação recebe status `synced` e armazena resultado transacional | Registra erro detalhado em caso de falha |

</frozen-after-approval>

## Code Map

- `functions/src/index.ts` -- Endpoints transacionais `stockCommand`, `payExpense`, `finalizeDiario` e tratamento de erros do `callable`.
- `functions/src/contracts.ts` -- Contratos e funções utilitárias de validação decimal, sanitização de identificadores e regras de módulo.
- `app/lib/src/sync/operation_queue.dart` -- Fila de operações, contrato do executor `QueueExecute`, processamento da resposta transacional e classificação de erros.
- `functions/test/unit.cjs` -- Testes unitários Node.js dos contratos e lógica dos endpoints transacionais.
- `app/test/transactional_endpoints_test.dart` -- Testes unitários herméticos no Flutter validando a execução transacional, captura de resultados e classificação de erros.

## Tasks & Acceptance

**Execution:**
- [x] `app/lib/src/sync/operation_queue.dart` -- Atualizar `QueueExecute` para retornar `Future<dynamic>` e registrar opcionalmente o resultado transacional retornado pelo callable.
- [x] `functions/src/index.ts` -- Padronizar os retornos estruturados das transações e garantir códigos uniformes de erro em todas as rotas transacionais.
- [x] `functions/test/unit.cjs` -- Adicionar testes unitários para verificação de contratos transacionais e tratamento de erros.
- [x] `app/test/transactional_endpoints_test.dart` -- Criar suite de testes unitários para validar a comunicação e o ciclo de vida da execução dos endpoints transacionais via `OperationQueue`.

**Acceptance Criteria:**
- Given um comando de estoque ou financeiro submetido pelo `OperationQueue`, when o backend executa o endpoint transacional com sucesso, then todas as mutações no Firestore ocorrem atomicamente e o resultado é retornado ao cliente.
- Given uma falha de validação ou saldo insuficiente no backend, when a transação é abortada, then nenhum documento parcial é gravado e o cliente registra a falha como `conflict`.
- Given uma tentativa de execução sem permissão adequada, when o endpoint transacional rejeita a chamada, then a operação é marcada como `authorization_rejected` e não entra em loop de retentativas.
- Given um anexo de diário com hash ou tamanho divergente, when `finalizeDiario` é chamado, then a transação falha e o diário permanece pendente de correção.

## Implementation Notes

- **operation_queue.dart:** Evoluído `QueueExecute` de `Future<void>` para `Future<dynamic>` para capturar e preservar o resultado de resposta das Cloud Functions transacionais (`stockCommand`, `payExpense`, `finalizeDiario`). Adicionado `getResult(key)` para consulta reativa do resultado confirmado e persistido no `queue_store`.
- **queue_store_native.dart & queue.js:** Atualizados para armazenar e persistir o campo `result` retornado pela transação em caso de sucesso.
- **functions/test/unit.cjs:** Adicionados testes unitários herméticos garantindo canonicidade de hashes de comando e validação de escala monetária/estoque.
- **app/test/transactional_endpoints_test.dart:** Criada suíte completa com 6 testes unitários validando respostas transacionais de estoque e financeiro, conversão de `failed-precondition` para `conflict`, `permission-denied` para `authorization_rejected`, `unavailable` para `failed` com retentativa, e isolamento por obra.
- **Verificação:** 75/75 testes Dart passando (`flutter test`), 0 issues no `flutter analyze`, 6/6 testes de unidade no Node (`npm test`), e 5/5 testes de fila no navegador Playwright (`npm run test:browser`).

## Spec Change Log

- 2026-09-16: Criação, aprovação e conclusão da implementação da Story 2.9.

## Review Triage Log

- Nenhum issue impeditivo ou regressão identificada durante a revisão e execução das baterias de testes.

## Verification

**Commands:**
- `cd functions && npm test` -- expected: Todos os testes unitários do backend passam com código 0.
- `cd app && flutter test test/transactional_endpoints_test.dart` -- expected: Bateria de testes de endpoints transacionais passa com código 0.
- `cd app && flutter analyze` -- expected: 0 erros e 0 warnings.
