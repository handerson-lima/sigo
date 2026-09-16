---
title: 'Story 2.6 — Particionamento de Cache'
type: 'feature'
created: '2026-09-16'
status: 'done'
baseline_commit: '42a0039ace6dcec5e685529e5f903b2487906f42'
route: 'dispatch'
review_loop_iteration: 1
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-2-context.md'
  - '{project-root}/docs/task.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Em ambientes corporativos multi-tenant com múltiplos usuários, construtoras, obras e módulos, armazenar dados locais sem particionamento estrito gera riscos severos de colisão de dados, contaminação cruzada de cache entre obras distintas e incapacidade de purgar dados de uma obra específica sem destruir os dados legítimos das demais obras do usuário.

**Approach:** Estabelecer particionamento determinístico de cache local (IndexedDB `snapshots`) baseado na tupla hierárquica `(usuarioId, construtoraId, obraId, modulo)`, garantindo isolamento estrito entre obras e construtoras, suporte a purga seletiva de escopo (`clearReadCacheScope`) e prevenção de vazamento cruzado.

## Boundaries & Constraints

**Always:**
- As chaves de armazenamento local de snapshots devem incorporar o contexto completo do escopo: usuário, construtora e obra/módulo.
- Documentos de uma obra (ex: diários, lotes, membros de obra) devem ser isolados sob o prefixo `construtoras/<c>/obras/<o>/...` de forma que leituras da Obra A nunca acessem registros da Obra B.
- A purga de cache deve suportar tanto limpeza global do usuário (`clearReadCache(uid)`) quanto limpeza seletiva particionada por escopo (`clearReadCacheScope(uid, scopePrefix)`), por exemplo ao detectar perda de acesso em uma obra específica.
- A troca de obra na interface ou alternância de construtora deve consultar o cache correspondente ao novo escopo sem reaproveitar estados da obra anterior.

**Never:**
- Nunca permitir que registros com mesmo nome de coleção em obras diferentes compartilhem a mesma chave de snapshot.
- Nunca permitir que a purga de uma obra específica delete snapshots de outras obras onde o usuário continua com acesso ativo.
- Nunca permitir que dados de construtoras diferentes colidam no IndexedDB.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Cache de duas obras distintas | Usuário consulta Obra A e Obra B da mesma construtora | Snapshots gravados em partições isoladas; dados de A e B não se misturam | Chaves segregadas por `obraId` |
| Purga seletiva de obra revogada | Permissão na Obra A é revogada (`clearReadCacheScope`) | Apenas snapshots com escopo da Obra A são removidos; Obra B permanece intacta | Transação atômica por cursor/filtro |
| Purga global por logout | Logout ou desativação geral do usuário | Todos os snapshots de qualquer partição pertencentes ao `uid` são eliminados | Sem tocar em outros `uids` |
| Construtoras diferentes | Usuário vinculado a Construtora 1 e Construtora 2 | Dados de módulos centrais e obras particionados por `construtoraId` | Sem colisão entre tenants |

</frozen-after-approval>

## Code Map

- `app/lib/src/sync/read_cache.dart` -- Funções de leitura e snapshot (`cachedDocument`, `cachedRead`, `cachedList`), adição de `clearReadCacheScope` e padronização de chaves particionadas.
- `app/lib/src/sync/queue_store_native.dart` -- Suporte nativo a `prefix` em `cacheClear` para purga particionada.
- `app/web/queue.js` -- Suporte a filtro de `prefix` em `cacheClear` no IndexedDB para exclusão seletiva de partição.
- `app/test/cache_partition_test.dart` -- Suite de testes automatizados Dart validando o particionamento entre obras, construtoras e módulos, e a purga seletiva por escopo.

## Tasks & Acceptance

**Execution:**
- [x] `app/web/queue.js` -- Adicionar suporte a `prefix` opcional na ação `cacheClear` para permitir purga particionada no IndexedDB.
- [x] `app/lib/src/sync/queue_store_native.dart` -- Adicionar suporte a `prefix` opcional no `cacheClear` nativo.
- [x] `app/lib/src/sync/read_cache.dart` -- Implementar função `clearReadCacheScope(uid, scopePrefix)` e auditar isolamento de caminhos particionados.
- [x] `app/test/cache_partition_test.dart` -- Criar suite de testes unitários cobrindo particionamento entre obras, construtoras, módulos e purga seletiva.

**Acceptance Criteria:**
- Given dados de duas obras distintas gravados em cache, when consultados pelo mesmo usuário, then cada obra retorna estritamente seus próprios snapshots sem interferência cruzada.
- Given a revogação de acesso a uma obra específica, when `clearReadCacheScope` for executado com o escopo daquela obra, then somente os snapshots daquela obra são excluídos, mantendo intactos os dados das outras obras e da fila de operações.
- Given uma limpeza global via `clearReadCache`, when executada para o usuário, then todas as partições do usuário são removidas sem afetar snapshots de outras contas.

## Implementation Notes

- **queue.js & queue_store_native.dart:** O comando `cacheClear` agora aceita o parâmetro opcional `prefix`. Quando fornecido, apenas as entradas cujo campo `key` contenha o prefixo especificado são purgadas, preservando partições não atingidas.
- **read_cache.dart:** Implementada a função `clearReadCacheScope(uid, scopePrefix)` que invoca o `queueStore('cacheClear', ...)` parametrizado com `prefix`.
- **cache_partition_test.dart:** Criada suíte com 4 testes unitários cobrindo suporte ao prefixo no JS, isolamento de chaves entre obras e construtoras, e purga seletiva de escopo sem afetar outras partições ou contas alheias.
- **Verificação:** 57/57 testes Dart passando (`flutter test`), 0 issues no `flutter analyze`, e 5/5 testes Chromium Playwright passando no navegador.

## Spec Change Log

- 2026-09-16: Criação e aprovação da especificação; implementação completa concluída.

## Review Triage Log

- Nenhum issue impeditivo ou regressão identificada durante a revisão e execução das baterias de testes.
