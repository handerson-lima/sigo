---
title: 'Story 2.1 — Service Worker e Configuração de PWA Offline-First'
type: 'feature'
created: '2026-09-16'
status: 'done'
baseline_commit: 'e9c2d83950321b7068d92ce52a9a68d5e6d2aa75'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-2-context.md'
  - '{project-root}/docs/task.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O SIGO precisa operar como PWA instalável e resiliente a falhas de rede em canteiros de obras. No estado atual, o service worker em desenvolvimento (`app/web/sigo-sw.js`) é um placeholder que lança exceção impeditiva, enquanto o empacotador de produção (`prepare_pwa.py`) precisa de validação de integridade do shell atômico (`sigo-shell-<hash>`), garantia de navegação offline para rotas SPA e manifesto PWA completo.

**Approach:** Estabelecer um Service Worker de desenvolvimento seguro (pass-through / network-first sem exceções), consolidar o ciclo de vida do cache atômico de release via `prepare_pwa.py`, garantir suporte a navegação offline (`mode === 'navigate'` servindo `index.html`) e conformidade estrita do `manifest.json` para instalação mobile/desktop.

## Boundaries & Constraints

**Always:**
- O Service Worker deve gerenciar exclusivamente o cache de casca/aplicativo (`sigo-shell-*`), ativos estáticos e scripts locais, nunca interceptando ou armazenando dados dinâmicos de negócio de APIs/Firestore.
- Em desenvolvimento (`flutter run -d chrome`), o service worker deve instalar e ativar de forma transparente sem poluir o console com erros não tratados.
- No build de produção (`tool/build_pwa.sh`), todos os recursos da aplicação (CanvasKit, Firebase SDK local) devem ser versionados e empacotados localmente sem dependência de CDNs externas.
- Requisições de navegação do browser (`event.request.mode === 'navigate'`) devem responder com `index.html` do cache ativo quando offline, permitindo que o GoRouter restaure a rota localmente.

**Never:**
- Não usar `skipWaiting()` descontrolado que corrompa abas existentes com versões divergentes de assets em memória.
- Não misturar cache de shell estático com os dados locais transacionais da fila IndexedDB (`queue.js`).
- Não reintroduzir dependências remotas via CDN em tempo de execução offline.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Cold launch offline | Dispositivo sem conexão abre PWA instalado | Service Worker responde `index.html` e assets do cache `sigo-shell-<hash>`; aplicação carrega tela de login/dashboard | Se cache ausente, erro de rede padrão |
| Navegação interna offline | Usuário recarrega `/construtora/cId/obra/oId` offline | SW intercepta request `navigate` e entrega `index.html` do cache | GoRouter assume roteamento local |
| Execução em Desenvolvimento | `flutter run -d chrome` carrega `app/web/sigo-sw.js` | SW instala sem erros, repassa requisições para a rede diretamente | Não bloqueia live-reload |
| Atualização de Versão PWA | Novo build gera `sigo-shell-<novo_hash>` | Novo cache é instalado em segundo plano; ativação remove versões antigas de shell preservando a versão corrente até recarga | Falha no download de asset aborta instalação e descarta cache incompleto |
| Instalação PWA | Usuário clica em 'Instalar Aplicativo' no navegador | `manifest.json` fornece metadados, ícones maskable e exibição standalone | N/A |

</frozen-after-approval>

## Code Map

- `app/web/sigo-sw.js` -- Service worker de desenvolvimento: substituir o lançamento de exceção por um lifecycle pass-through seguro com limpeza controlada.
- `app/web/manifest.json` -- Metadados do PWA: validar escopo (`scope`), `start_url`, `theme_color`, `background_color`, orientação e ícones maskable.
- `app/web/index.html` -- Inclusão e registro do Service Worker e scripts de bootstrap.
- `app/tool/prepare_pwa.py` -- Script de pós-build: garantir hash determinístico de versão de cache, isolamento de rotas `navigate` e empacotamento local dos assets do Firebase/CanvasKit.
- `app/tool/build_pwa.sh` -- Script de empacotamento de produção: orquestrar `flutter build web --no-web-resources-cdn --pwa-strategy=none` e execução de `prepare_pwa.py`.
- `functions/test/pwa-browser.cjs` -- Teste ponta a ponta Playwright: validar carregamento offline do PWA e navegação do shell.

## Tasks & Acceptance

**Execution:**
- [x] `app/web/sigo-sw.js` -- Implementar service worker de desenvolvimento com ciclo de vida pass-through limpo.
- [x] `app/web/manifest.json` -- Ajustar e consolidar campos do manifesto PWA (`scope`, `id`, `orientation`, metadados de instalação).
- [x] `app/tool/prepare_pwa.py` -- Hardening do worker de release para tratar navegações offline SPA e remoção de caches antigos sem interrupção de abas ativas.
- [x] `app/tool/build_pwa.sh` -- Validar flags de build offline sem CDN e permissões de execução.
- [x] `functions/test/pwa-browser.cjs` e testes locais -- Verificar execução do ciclo de vida PWA offline.

**Acceptance Criteria:**
- Given um ambiente de desenvolvimento local, when `flutter run -d chrome` é iniciado, then o `sigo-sw.js` é registrado sem lançar exceções no console do navegador.
- Given um build de produção gerado com `tool/build_pwa.sh`, when a aplicação é executada em modo offline (sem rede), then a página recarrega com sucesso a partir do cache `sigo-shell-*` e o GoRouter renderiza a interface sem requisições bloqueadas para domínios externos.
- Given o `manifest.json` do SIGO, when auditado no navegador, then atende aos requisitos de PWA instalável (`display: standalone`, `icons` válidos com versões maskable, `start_url` e `scope`).

## Implementation Notes

- O worker de desenvolvimento deve ser idempotente e não interferir no hot reload do Flutter.
- No worker de release, a estratégia atômica `cache.addAll(ASSETS)` garante que se qualquer arquivo falhar durante o download da nova versão, o cache inteiro é descartado, evitando estado de cache quebrado/parcial.

## Review Triage Log

| Finding | Source | Verdict | Route | Evidence |
|---------|--------|---------|-------|----------|
| sigo-sw.js dev sem throws | blind-hunter | false | — | Lifecycle de desenvolvimento implementado com pass-through seguro |
| manifest.json ícones maskable | blind-hunter | false | — | Ícones maskable 192 e 512 declarados e existentes em `web/icons/` |
| fallback de navegação offline | edge-case-hunter | false | — | `mode === 'navigate'` atende via `index.html` cacheado |
| integridade de assets do shell | verification-gap | false | — | Coberto por `pwa_manifest_test.dart` e `tool/build_pwa.sh` |

## Verification

**Commands:**
- `cd app && flutter analyze` -- expected: Sem erros ou advertências.
- `cd app && flutter test` -- expected: Todos os 28 testes passando.
- `cd app && bash tool/build_pwa.sh` -- expected: Build web completado e PWA preparado com hash atômico.
- `cd functions && npm test` -- expected: Testes de functions passando.
