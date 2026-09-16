---
title: 'Story 2.2 — Cache do Aplicativo Separado dos Dados de Negócio'
type: 'feature'
created: '2026-09-16'
status: 'done'
baseline_commit: 'e0a54971e9dfc2bba90ac92456ac741164eac600'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-2-context.md'
  - '{project-root}/docs/task.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Em aplicações PWA offline-first, misturar o cache de casca/código (`shell/assets`) com o cache de dados transacionais de negócio cria riscos críticos de vazamento de informações entre usuários, falha de revogação de acessos e corrupção de estado ao atualizar a versão do software.

**Approach:** Implementar e auditar a separação estrita entre o cache estático do aplicativo (gerenciado exclusivamente pela Cache Storage API do Service Worker sob o namespace `sigo-shell-*`) e a persistência local de dados de negócio (gerenciada no IndexedDB sob `sigo-operations`), assegurando que dados de Firestore/APIs nunca sejam interceptados pelo Service Worker e que o descarte de dados do usuário (`clearReadCache` / logout / revogação) não remova a casca offline do aplicativo.

## Boundaries & Constraints

**Always:**
- O Service Worker deve apenas armazenar e responder recursos estáticos locais declarados em `ASSETS` (`index.html`, `canvaskit`, `flutter_bootstrap.js`, scripts embutidos do Firebase e fontes).
- Todas as requisições para `firestore.googleapis.com`, `identitytoolkit.googleapis.com`, Cloud Functions ou domínios externos devem passar direto sem interceptação ou armazenamento no Cache Storage.
- A persistência local de dados de leitura (`snapshots`) e fila (`operations`) reside exclusivamente no IndexedDB e deve ser indexada por `uid`.
- A limpeza de cache por revogação de permissão (`permission-denied` ou `isActive == false`) deve purgar dados de negócio locais do usuário sem destruir o cache da casca do app no Service Worker.

**Never:**
- Não usar `Cache-Control` ou runtime caching no Service Worker para requisições de API/Firestore.
- Não compartilhar registros de snapshot entre UIDs distintos no IndexedDB.
- Não exigir conexão de rede para carregar a casca da tela de login após a limpeza de dados de negócio.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Requisição de API Firestore | Cliente consulta Firestore | SW ignora requisição (pass-through à rede); não grava no Cache Storage | Falha tratada por `cachedDocument` via IndexedDB local |
| Limpeza de cache por revogação | Membro marcado `isActive: false` | `clearReadCache(uid)` deleta snapshots do usuário no IndexedDB; `sigo-shell-*` permanece intacto no Cache Storage | App volta à tela de login/acesso negado sem perder o PWA offline |
| Troca de usuário no dispositivo | Usuário A desloga, Usuário B autentica | `snapshots` de A não são servidos para B; Service Worker continua servindo os mesmos assets estáticos | Erro de conta alterada se snapshot de outro UID for solicitado |
| Atualização de versão de shell | Nova versão da aplicação é publicada | SW atualiza `sigo-shell-<novo_hash>` no Cache Storage; banco IndexedDB `sigo-operations` permanece intacto com transações preservadas | Falha atômica aborta e preserva versão anterior |

</frozen-after-approval>

## Code Map

- `app/tool/prepare_pwa.py` -- Assegurar que o Service Worker gerado filtre estritamente requisições de mesma origem (`url.origin === self.location.origin`) e somente métodos GET contidos na lista estática `ASSETS`, rejeitando qualquer tentativa de armazenar dados dinâmicos.
- `app/lib/src/sync/read_cache.dart` -- Gerenciamento de snapshots locais no IndexedDB com validação estrita de UID, isolamento de escopo e purga seletiva em `clearReadCache`.
- `app/web/queue.js` -- Implementação IndexedDB (`sigo-operations` store `snapshots` e store `operations`).
- `app/test/cache_separation_test.dart` -- Testes automatizados garantindo a independência entre o shell PWA e o cache de dados de negócio.

## Tasks & Acceptance

**Execution:**
- [x] `app/tool/prepare_pwa.py` -- Garantir regras estritas no Service Worker gerado: isolamento de origem, whitelist de assets estáticos e zero runtime-caching de APIs.
- [x] `app/lib/src/sync/read_cache.dart` -- Auditar e consolidar `clearReadCache`, isolamento de UID e purga reativa em `permission-denied`.
- [x] `app/test/cache_separation_test.dart` -- Criar suite de testes provando que a casca estática e os dados de negócio residem em camadas isoladas e com ciclos de vida independentes.

**Acceptance Criteria:**
- Given uma consulta ao Firestore ou API externa, when interceptada pelo Service Worker, then a requisição é repassada diretamente sem ser gravada na Cache Storage API.
- Given um usuário revogado (`isActive == false`), when detectado pelo `cachedDocument`, then `clearReadCache` remove os documentos locais do usuário no IndexedDB enquanto o cache de shell `sigo-shell-*` permanece intacto.
- Given o suite de testes de cache, when executado `flutter test`, then todos os testes passam comprovando o isolamento de camadas.

## Implementation Notes

- O Cache Storage do navegador (`caches`) guarda arquivos estáticos imutáveis da versão. O IndexedDB guarda o estado operacional dinâmico particionado por usuário. Essa separação de responsabilidades é a pedra angular da arquitetura offline-first do SIGO.

## Review Triage Log

| Finding | Source | Verdict | Route | Evidence |
|---------|--------|---------|-------|----------|
| Isolamento de origem no SW | blind-hunter | false | — | `url.origin !== self.location.origin` ignora domínios externos |
| Zero runtime caching no fetch | edge-case-hunter | false | — | Sem chamadas `cache.put`/`cache.add` no listener de `fetch` |
| Purga seletiva por UID no IndexedDB | verification-gap | false | — | Validado por `cache_separation_test.dart` e `queue.js` |

## Verification

**Commands:**
- `cd app && flutter analyze` -- expected: Sem erros ou advertências.
- `cd app && flutter test` -- expected: Todos os testes passando com sucesso.
- `cd app && bash tool/build_pwa.sh` -- expected: PWA gerado com garantia de separação de cache.
