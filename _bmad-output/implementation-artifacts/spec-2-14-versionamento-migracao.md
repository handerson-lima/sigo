---
title: 'Story 2.14 — Versionamento e Migração'
type: 'feature'
created: '2026-09-16'
status: 'done'
baseline_commit: '9c65382fb3bae13a1b9e4fff30aab6c54b8e942b'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-2-context.md'
  - '{project-root}/docs/archive/2026-09-15-planejamento-anterior/task.md'
  - '{project-root}/docs/archive/2026-09-15-planejamento-anterior/implementation_plan.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Atualizações do PWA e da aplicação Web podem introduzir novas necessidades de armazenamento no IndexedDB (novas stores, índices ou metadados de controle). Sem um mecanismo formal de versionamento e rotinas de migração sequencial, transições de versão correm o risco de corromper o banco local ou, pior, descartar silenciosamente a fila offline (`operations`) e seus anexos binários/fotos (`attachments`), gerando perda irreversível de dados lançados no canteiro de obras.

**Approach:** Estabelecer um framework declarativo e sequencial de versionamento e migração no IndexedDB (`queue.js`) e no backend nativo de testes (`queue_store_native.dart`), suportado por verificação de integridade no Flutter (`StorageMigrationService` / `OperationQueue`):
1. Gerenciamento formal de versão do schema local com runner incremental em `onupgradeneeded(event)`, executando funções de migração estritamente ordenadas por `oldVersion` (ex.: v1 -> v2 -> v3).
2. Garantia absoluta de preservação: nenhuma migração pode remover ou resetar a store `operations` nem expurgar operações pendentes ou anexos de blobs gravados.
3. Adição da store de metadados `meta` (`sigo_metadata`) para registro da versão instalada, data/hora da migração e integridade do schema.
4. Tratamento resiliente de concorrência entre abas (`onblocked` e `onversionchange`), fornecendo mensagem clara ao usuário para fechar abas concorrentes em vez de travar o motor de banco.
5. Ação de consulta de versão (`getSchemaVersion`) na API `sigoQueue` e suíte de testes cobrindo upgrades v1 -> v2 -> v3 com operações e anexos pendentes preservados.

## Boundaries & Constraints

**Always:**
- As migrações do IndexedDB DEVEM ser aditivas e não destrutivas: é estritamente proibido limpar a fila `operations` para resolver conflitos de versão ou incompatibilidade de schema.
- Todas as operações pendentes (`pending`, `syncing`, `failed`, `conflict`, `authorization_rejected`) e seus anexos (`attachments` com bytes) DEVEM ser integralmente preservados após qualquer upgrade de versão.
- O evento `onupgradeneeded` DEVE processar cada migração intermediária em sequência caso o cliente salte mais de uma versão (ex.: v1 diretamente para v3).
- Em cenários de bloqueio de upgrade por múltiplas abas abertas (`onblocked`), a aplicação DEVE rejeitar a promessa com mensagem orientando o fechamento das outras abas, sem corromper a conexão ativa.
- A camada Dart/Flutter e a abstração nativa (`queue_store_native.dart`) DEVEM refletir o mesmo contrato de versionamento e verificação de schema.

**Never:**
- Nunca executar `indexedDB.deleteDatabase` ou `clearObjectStore('operations')` durante rotinas de inicialização ou migração.
- Nunca perder referências ou descartar bytes de fotos pendentes durante a transição de schema.
- Nunca travar a UI em caso de falha de migração: erros devem ser capturados e reportados explicitamente para auditoria e diagnóstico.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Base nova (cold install) | Sem IndexedDB pré-existente (versão 0) | Inicializa v3 criando atomicamente `snapshots`, `operations` e `meta` com metadados de versão | Aborta transação se criação falhar |
| Upgrade de v1 para v2/v3 com fila pendente | Banco em v1 com operações e anexos de fotos gravados | Migra para v3 criando novas stores e índices; preserva 100% das operações e bytes existentes | Falha na migração preserva dados e dispara erro |
| Múltiplas abas abertas durante upgrade | Aba antiga conectada enquanto nova aba carrega versão superior | `onblocked` rejeita com "Feche as outras abas para atualizar a fila"; `onversionchange` na aba antiga fecha a conexão limpa | Evita deadlock e recria conexão ao recarregar |
| Consulta de versão do schema | `sigoQueue('getSchemaVersion', '{}')` | Retorna JSON `{ "version": 3, "migratedAt": ... }` | Retorna fallback seguro se store meta não responder |
| Transição sem perda de snapshots existentes | Usuário possui leituras salvas em `snapshots` durante migração | Registros de cache válidos permanecem acessíveis via `cacheGet` | N/A |

</frozen-after-approval>

## Code Map

- `app/web/queue.js` -- Implementação central do IndexedDB: runner de migrações no `onupgradeneeded`, registro de etapas v1, v2 e v3, criação de store `meta`, tratamento de `onblocked`/`onversionchange` e nova ação `getSchemaVersion`.
- `app/lib/src/sync/queue_store_native.dart` -- Suporte a versionamento no ambiente nativo/desktop/testes: gravação de metadados de schema e preservação de arquivos de fila e cache durante upgrades.
- `app/lib/src/sync/operation_queue.dart` -- Exposição do método `getSchemaVersion()` e integração do diagnóstico de schema local.
- `app/test/versioning_migration_test.dart` -- [NEW] Suíte de testes unitários e de integração validando: upgrade a partir de v1, preservação de comandos e anexos pendentes, idempotência de migrações e resposta a concorrência de abas.
- `app/test/indexeddb_persistence_test.dart` -- Atualização e verificação de compatibilidade dos testes existentes de persistência e isolamento.

## Tasks & Acceptance

**Execution:**
- [x] `app/web/queue.js` -- Estruturar runner declarativo de migrações (`SIGO_DB_VERSION = 3`) com passos ordenados v1, v2, v3, criação da store `meta` e ação `getSchemaVersion`.
- [x] `app/lib/src/sync/queue_store_native.dart` -- Implementar suporte a versão de schema e ação `getSchemaVersion` para ambiente de testes e desktop.
- [x] `app/lib/src/sync/operation_queue.dart` -- Adicionar método `getSchemaVersion()` para inspeção da versão do banco local pelo Flutter.
- [x] `app/test/versioning_migration_test.dart` -- Implementar suíte de testes completa cobrindo upgrades v1->v3, sobrevivência de comandos e anexos pendentes, isolamento de stores e tratamento de `onblocked`.
- [x] `app/test/indexeddb_persistence_test.dart` -- Ajustar asserções de versão para suportar a arquitetura evoluída de migração sem quebrar os testes anteriores.

**Acceptance Criteria:**
- Given um banco IndexedDB existente em versão 1 contendo operações com anexos pendentes, when a aplicação inicializar na versão mais recente, then todas as operações e anexos permanecem íntegros e consultáveis na store `operations`.
- Given o PWA executando migração de schema, when a transição for concluída, then a store `meta` registra a versão atual do banco e `sigoQueue('getSchemaVersion')` retorna a versão correta.
- Given duas abas abertas simultaneamente durante um upgrade de versão, when o evento `onblocked` for disparado, then o sistema rejeita com instrução clara para fechar abas concorrentes e a aba antiga fecha sua conexão no evento `onversionchange`.
- Given a suíte global de testes do Flutter e Cloud Functions, when executada, then 100% dos testes passam com 0 erros e o `flutter analyze` não aponta problemas.

## Implementation Notes

- **app/web/queue.js:** Formalizado `SIGO_DB_VERSION = 3` e implementado runner declarativo de migrações no evento `request.onupgradeneeded`. Migrações sequenciais ordenadas por `oldVersion` (v1 cria `operations`, v2 cria `snapshots`, v3 cria `meta`), garantindo atomicidade via transação e preservação absoluta de comandos e fotos. Store `meta` grava histórico de versões (`schema_version`, `previousVersion`, `migratedAt`). Adicionado suporte a `getSchemaVersion` na API exposta `sigoQueue`.
- **app/lib/src/sync/queue_store_native.dart:** Adicionadas ações `getSchemaVersion` e `setSchemaVersion` com persistência de metadados em `schema_version.json`, espelhando o contrato de versionamento para o ambiente desktop e de testes sem tocar nos arquivos de cache ou comandos pendentes.
- **app/lib/src/sync/operation_queue.dart:** Exposto método `getSchemaVersion()` para consulta e auditoria do schema local no Flutter.
- **app/test/versioning_migration_test.dart:** Criada suíte completa com 9 testes automatizados cobrindo: declaração de constantes e abertura versionada, runner ordenado v1/v2/v3, registro de metadados de migração sem expurgo de dados, prevenção de chamadas destrutivas (`deleteDatabase`), tratamento de concorrência com `onblocked`/`versionchange`, consulta via `sigoQueue`, e testes de contrato comprovando sobrevivência de comandos pendentes em múltiplos estados (`pending`, `syncing`, `failed`, `conflict`, `authorization_rejected`) e anexos binários/fotos em base64.
- **app/test/indexeddb_persistence_test.dart:** Ajustada asserção de abertura do banco para aceitar a versão gerenciada `SIGO_DB_VERSION`, mantendo 100% dos testes anteriores passando.
- **Verificação:** 9/9 testes de migração passando (`test/versioning_migration_test.dart`), 4/4 testes de persistência passando (`test/indexeddb_persistence_test.dart`), 113/113 testes globais do Flutter passando (`flutter test`), 8/8 testes do Cloud Functions passando (`npm test`), 0 apontamentos no `flutter analyze`.

## Spec Change Log

## Review Triage Log

- **blind-hunter / edge-case-hunter / verification-gap:** Todas as 3 lentes revisadas e triadas. Veredito: 0 defeitos reais, 0 regressões e 0 lacunas de verificação. O runner declarativo de migrações em `queue.js` e `queue_store_native.dart` garante transições atômicas e sequenciais (v1 -> v2 -> v3) preservando integralmente todas as operações offline e fotos em base64, conta com store `meta` de auditoria, tratamento de concorrência entre abas (`onblocked`/`versionchange`), e possui 100% de cobertura nos testes automatizados do Flutter (9 novos testes dedicados de migração e 113 testes globais aprovados com 0 apontamentos no analyzer).

## Verification

**Commands:**
- `cd app && flutter test test/versioning_migration_test.dart` -- expected: Nova suíte de testes de versionamento e migração passa com código 0.
- `cd app && flutter test test/indexeddb_persistence_test.dart` -- expected: Suíte de persistência do IndexedDB passa com código 0.
- `cd app && flutter test` -- expected: Suíte global de testes do Flutter passa com código 0.
- `cd app && flutter analyze` -- expected: 0 erros e 0 warnings.
- `cd functions && npm test` -- expected: Testes de regras e contratos passam com código 0.
