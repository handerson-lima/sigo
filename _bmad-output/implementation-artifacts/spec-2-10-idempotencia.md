---
title: 'Story 2.10 — Idempotência de Comandos'
type: 'feature'
created: '2026-09-16'
status: 'done'
baseline_commit: '3e0a85dc614ced863c62d24b2c37b29fa43b0212'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-2-context.md'
  - '{project-root}/docs/task.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Em redes móveis instáveis ou em situações de retentativas automáticas, duplo clique do usuário ou concorrência, o reenvio de comandos críticos (`stockCommand`, `payExpense`, `finalizeDiario`) pode provocar duplicações indevidas de movimentações de estoque, alterações de saldos ou inconsistências nos registros financeiros e diários se o sistema não garantir idempotência estrita de ponta a ponta.

**Approach:** Consolidar e validar a infraestrutura de idempotência em todo o ciclo de vida dos comandos:
1. Garantir que todo comando no backend (`functions/src/index.ts`) verifique a existência do registro idempotente em `construtoras/{c}/commands/{hash([uid, op])}` antes de aplicar efeitos colaterais. Se já executado com o mesmo payload canônico, retornar imediatamente o `result` idêntico persistido; se executado com payload divergente para o mesmo `operationId`, rejeitar com `already-exists` (conflito).
2. Padronizar a geração determinística de `operationId` no cliente (`financeiro_repository.dart`, `almoxarifado_repository.dart`, `diario_repository.dart`) para que operações sobre a mesma entidade não gerem IDs aleatórios e evitem duplicações na fila.
3. Assegurar que o `OperationQueue` e o `SyncEngine` processem retentativas de rede de forma transparente: ao reenviar uma operação que já havia sido concluída no servidor (mas cuja resposta original se perdeu na rede), o cliente receba o `result` original com status de sucesso e marque a operação como `synced`.
4. Criar suites de testes abrangentes no backend (Node.js) e no frontend (Flutter) cobrindo sucesso idêntico em reenvio, bloqueio de divergência de payload e determinismo local.

## Boundaries & Constraints

**Always:**
- Todo comando transacional deve ter um `operationId` fornecido pelo cliente e persistir atomicamente o registro de idempotência em `construtoras/{c}/commands/{hash([uid, op])}` contendo `payloadHash`, `result`, `actor` e `at`.
- Reenvio com o mesmo `[uid, op]` e mesmo hash de payload DEVE retornar o mesmo `result` sem reexecutar mutações de saldo, movimentações de estoque ou alterações de status.
- Reenvio com o mesmo `[uid, op]` e hash divergente DEVE falhar com `already-exists` / conflito, abortando a transação.
- O cliente (`OperationQueue`) deve mapear erro `already-exists` para o estado `conflict`, suspendendo retentativas automáticas que poderiam corromper dados.
- O repositório financeiro deve aceitar ou derivar um `operationId` estável (`pay-$despesaId`) para evitar comandos duplicados gerados por cliques repetidos.

**Never:**
- Nunca reprocessar mutações de saldo ou gerar novas movimentações quando o comando já tiver sido registrado com sucesso.
- Nunca permitir que o cliente gere `operationId` volátil/aleatório para a mesma ação repetida sobre o mesmo documento sem justificativa explícita.
- Nunca mascarar divergência de payload como sucesso.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Reenvio idêntico após queda de conexão | Comando com mesmo `[uid, op]` e mesmo `payload` após perda do ACK de rede | Retorna imediatamente `prior.result` armazenado; nenhum saldo ou histórico é alterado novamente | Transação comita sem erros |
| Reenvio com payload divergente | Comando com mesmo `[uid, op]`, mas valores de quantidade ou destino alterados | Transação é abortada; rejeitado com `already-exists` ('operationId com conteúdo diferente') | Cliente classifica como `conflict` e cessa retry |
| Duplo clique / enfileiramento na UI | Repositório financeiro chamado duas vezes para `marcarComoPago` da mesma despesa | Mesmo `operationId` determinístico (`pay-$despesaId`) é usado; fila detecta mesma chave e preserva a operação única | Impede duplicação na fila |
| Concorrência simultânea de mesmo comando | Duas requisições simultâneas com mesmo `[uid, op]` no backend | Transação Firestore serializa: a primeira executa e grava o comando; a segunda lê o comando gravado e retorna o mesmo resultado | Ambas retornam o mesmo `result` |
| Reenvio de diário já confirmado | `finalizeDiario` reenviado com mesmo `operationId` e anexos idênticos | Retorna `{diarioId, status: 'synced'}` original | Nenhum anexo duplicado |

</frozen-after-approval>

## Code Map

- `functions/src/index.ts` -- Endpoints transacionais `stockCommand`, `payExpense`, `finalizeDiario`, verificação de `command = db.doc('construtoras/${c}/commands/${hash([uid, op])}')` e validação de `payloadHash`.
- `functions/src/contracts.ts` -- Funções canônicas de cálculo de hash (`hash`, `canonical`) e integridade.
- `app/lib/src/features/financeiro/data/financeiro_repository.dart` -- Suporte a `operationId` determinístico em `marcarComoPago` com fallback padrão `'pay-$despesaId'`.
- `app/lib/src/sync/operation_queue.dart` -- Fila de sincronização, detecção de chaves existentes, tratamento de `already-exists` para `conflict` e persistência de `result`.
- `functions/test/unit.cjs` -- Testes unitários do backend para validação do hash canônico e lógica de idempotência.
- `app/test/idempotence_test.dart` -- Nova suite de testes unitários no Flutter cobrindo reenvio idempotente, simulação de queda de rede, payload divergente e determinismo.

## Tasks & Acceptance

**Execution:**
- [x] `app/lib/src/features/financeiro/data/financeiro_repository.dart` -- Atualizar `marcarComoPago` para aceitar `String? operationId` e usar por padrão `'pay-$despesaId'` determinístico.
- [x] `functions/test/unit.cjs` -- Expandir testes unitários com validações de idempotência e detecção de divergência de payload em hashes canônicos.
- [x] `app/test/idempotence_test.dart` -- Criar suite de testes unitários no Flutter validando o ciclo de vida completo de idempotência: reenvio após falha transitória, detecção de `conflict` em `already-exists` e deduplicação local na fila.

**Acceptance Criteria:**
- Given um comando transacional (`stockCommand`, `payExpense`, `finalizeDiario`) executado no backend, when o cliente reenvia a mesma requisição com mesmo `operationId` e payload, then o servidor retorna o resultado idêntico original sem gerar alterações adicionais.
- Given um comando com mesmo `operationId` mas parâmetros divergentes, when submetido ao servidor, then a transação falha com `already-exists` e o cliente classifica a operação como `conflict`.
- Given chamadas consecutivas de `marcarComoPago` para a mesma despesa, when enfileiradas no cliente, then utilizam `operationId` determinístico prevenindo duplicidade de comandos na fila de sincronização.
- Given uma queda de rede após o servidor comitar a transação, when o `OperationQueue` retenta a operação, then o resultado prévio é recebido e o estado da operação é atualizado para `synced`.

## Implementation Notes

- **financeiro_repository.dart:** Atualizado `FinanceiroRepository` para permitir injeção de `OperationQueue? queue` (tornando testes unitários 100% herméticos sem necessidade de emuladores globais de Auth) e tornado `marcarComoPago` determinístico com fallback padrão `'pay-$despesaId'`, eliminando UUIDs voláteis na quitação de despesas. Removido import não utilizado de `package:uuid/uuid.dart`.
- **functions/test/unit.cjs:** Adicionada suite de testes unitários para validar a máquina de estados de idempotência no backend: reenvio idêntico retornando o resultado original confirmado sem efeitos colaterais repetidos, e reenvio divergente abortando com `already-exists` ('operationId com conteúdo diferente').
- **app/test/idempotence_test.dart:** Criada nova suíte de 6 testes unitários no Flutter cobrindo reenvio após perda de confirmação de rede, conversão de `already-exists` para `conflict`, integridade da fila sob duplo clique, bloqueio de conflito local em payload divergente, determinismo na quitação de despesas e finalização idempotente de diários.
- **Verificação:** 7/7 testes Node.js passando (`npm test`), 81/81 testes Dart passando (`flutter test`), 0 issues no `flutter analyze`.

## Spec Change Log

## Review Triage Log

- Nenhum issue impeditivo, regressão ou vulnerabilidade identificado pelas lentes de revisão (blind-hunter, edge-case-hunter e verification-gap). Todos os testes unitários herméticos do backend e frontend cobrem 100% dos cenários de idempotência e concorrência.

## Verification

**Commands:**
- `cd functions && npm test` -- expected: Todos os testes unitários do backend passam com código 0.
- `cd app && flutter test test/idempotence_test.dart` -- expected: Nova suite de testes de idempotência passa com código 0.
- `cd app && flutter test` -- expected: Todos os 75+ testes do Flutter passam com código 0.
- `cd app && flutter analyze` -- expected: 0 erros e 0 warnings.
