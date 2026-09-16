---
title: 'Story 2.3 — Persistência Local IndexedDB'
type: 'feature'
created: '2026-09-16'
status: 'done'
baseline_commit: '1d35e471eae4b3371c20e429494fc52f3d5a3906'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-2-context.md'
  - '{project-root}/docs/task.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Operações em campo e consultas offline exigem armazenamento persistente local no navegador que sobreviva a recargas, fechamento de abas e reinicializações de dispositivo, garantindo isolamento estrito de registros entre usuários e prevenindo perda de comandos em fila ou leituras cacheadas.

**Approach:** Estruturar, tipar e blindar a camada de persistência local IndexedDB (`sigo-operations` v2) contendo as objectStores `snapshots` (leituras cacheadas) e `operations` (fila transacional durável), assegurando reconexão sob demanda resiliente a trocas de versão, índices eficientes por `uid` e preservação atômica de integridade local.

## Boundaries & Constraints

**Always:**
- O banco de dados IndexedDB no navegador deve se chamar `sigo-operations` com versão controlada (mínimo v2) e criação idempotente das stores `snapshots` (`keyPath: 'key'`) e `operations` (`keyPath: 'key'`).
- O schema da store `snapshots` armazena `{ key, uid, value }`, onde `key` é indexada de forma única e `value` contém o payload de documento serializado.
- O schema da store `operations` armazena `{ key, uid, state, payload, attachments, attempts, lease, leaseUntil, nextAttemptAt, error, createdAt }`.
- A manipulação de conexões deve suportar reabertura automática e graceful handling de `onversionchange` (fechando conexão para não bloquear upgrades de outras abas) e reabrindo na próxima chamada sem falhar com conexão encerrada.
- O isolamento entre usuários é mandatório: leituras de `snapshots` e listagens de `operations` filtram rigorosamente pelo `uid` autenticado da sessão atual.
- Limpezas de cache de leitura (`cacheClear`) descartam apenas registros de `snapshots` do `uid` especificado, sem afetar `operations` pendentes nem snapshots de outras contas.

**Never:**
- Nunca excluir registros da store `operations` em caso de erro de rede ou falha de autorização (permanecem retidos com `state: 'authorization_rejected'` ou `state: 'failed'` para auditoria).
- Nunca permitir que uma chamada a `sigoQueue` cause unhandled promise rejection que quebre a aplicação Flutter Web.
- Nunca misturar chaves de documentos ou estados de fila entre instâncias de usuários diferentes no mesmo navegador.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Armazenar e recuperar snapshot | `cachePut` com key e uid válidos | Registro gravado no `snapshots`; `cacheGet` retorna exatamente o `value` armazenado | Erro de cota/transação rejeita Promise com mensagem tratável |
| Isolamento de UID no snapshot | UID 'alice' grava snapshot; UID 'bob' tenta ler com mesma key | `cacheGet` retorna `null` para 'bob' | Sem vazamento de dados entre contas |
| Limpeza seletiva de cache | `cacheClear` para 'alice' | Todos os registros de 'alice' em `snapshots` são removidos; registros de 'bob' e fila `operations` de 'alice' permanecem intactos | Transação atômica em readwrite |
| Inserção idempotente na fila | `insert` com mesma key de operação já existente | Retorna a operação existente sem duplicar nem sobrescrever estado em andamento | Operação preservada |
| Reconexão após `versionchange` | Outra aba dispara upgrade e aciona `onversionchange` | Conexão anterior fecha graciosamente; próxima chamada reabre conexão transparentemente | Não lança erro de conexão fechada |

</frozen-after-approval>

## Code Map

- `app/web/queue.js` -- Implementação central da camada IndexedDB no navegador: gerenciamento do banco `sigo-operations`, stores `snapshots` e `operations`, reconexão sob demanda e exportação de `globalThis.sigoQueue`.
- `app/lib/src/sync/queue_store_web.dart` -- JS interop tipado via `dart:js_interop` comunicando com `sigoQueue`.
- `app/lib/src/sync/queue_store_native.dart` -- Implementação espelho para plataformas nativas e testes desktop, mantendo paridade de contrato com o IndexedDB.
- `app/lib/src/sync/read_cache.dart` -- Camada de leitura e snapshot que consome `queueStore` com isolamento de UID e expõe `clearReadCache`.
- `app/test/indexeddb_persistence_test.dart` -- Suite de testes automatizados Dart validando os contratos de persistência, schemas, isolamento e idempotência.
- `functions/test/queue-browser.cjs` -- Suite de testes em navegador real (Playwright Chromium) validando persistência do IndexedDB, concorrência e upgrade de versão.

## Tasks & Acceptance

**Execution:**
- [x] `app/web/queue.js` -- Refinar `sigo-operations` no IndexedDB com obtenção de conexão sob demanda resiliente (reabrindo caso fechada por `versionchange`), índices por `uid` e tratamento robusto de erros.
- [x] `app/lib/src/sync/read_cache.dart` -- Auditar e assegurar que as chamadas a `queueStore` manipulam tipos de dados com integridade em todas as plataformas.
- [x] `app/test/indexeddb_persistence_test.dart` -- Implementar suite de testes unitários em Dart cobrindo regras de contrato de persistência, isolamento de `uid` e operações de cache.
- [x] `functions/test/queue-browser.cjs` -- Validar suite end-to-end em navegador comprovando persistência, isolamento e resiliência a abas fechadas.

**Acceptance Criteria:**
- Given uma sessão ativa com usuário autenticado, when dados de documentos forem lidos via `read_cache.dart`, then os snapshots são persistidos na store `snapshots` do IndexedDB indexados por `uid`.
- Given uma troca de abas ou evento `versionchange`, when novas operações forem requisitadas a `sigoQueue`, then uma conexão ativa válida é utilizada ou restabelecida sem erro de conexão terminada.
- Given múltiplas operações inseridas com o mesmo identificador (idempotência), when `insert` for chamado repetidamente, then o registro original é preservado sem duplicação.
- Given a revogação de credencial ou logout com `clearReadCache`, when a limpeza for disparada, then somente a store `snapshots` do respectivo `uid` é limpa, preservando a store `operations` e os dados de outros usuários.

## Implementation Notes

- `app/web/queue.js`: refatorado para utilizar a função `getDb()`, garantindo que a referência de conexão seja renovada sob demanda sempre que um evento `onversionchange` ou fechamento de conexão ocorrer, eliminando o risco de `InvalidStateError` em trocas de versão ou abas concorrentes.
- `app/lib/src/sync/queue_store_native.dart`: corrigida verificação estrita de `uid` em `cacheGet` e adicionada verificação segura para chamadas de `cacheClear` sem `args['key']`, unificando a semântica entre native e web.
- `app/test/indexeddb_persistence_test.dart`: criada suite cobrindo a arquitetura de persistência, schema das stores `snapshots` e `operations`, isolamento de UID, idempotência de inserção e imunidade da fila a limpezas de cache de leitura.
- Validação completa: 40/40 testes passando no Flutter, 5/5 no Playwright Chromium e 0 warnings no `flutter analyze`.

## Spec Change Log

## Review Triage Log

| Reviewer / Layer | Finding / Scope | Verdict | Evidence / Resolution |
|---|---|---|---|
| Blind Hunter | Validação de lifecycle e reconexão do IndexedDB | OK | Conexão sob demanda via `getDb()` com liberação limpa em `onversionchange` |
| Edge Case Hunter | Troca de conta e `cacheClear` sem chave | OK | `cacheClear` não exige `key` e remove apenas snapshots do `uid`, preservando a fila |
| Verification Gap | Cobertura de testes unitários e de navegador real | OK | 40/40 testes Flutter aprovados, 5/5 testes Chromium Playwright aprovados |
