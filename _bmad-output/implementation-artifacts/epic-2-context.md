# Epic 2 Context: Arquitetura PWA e Sincronização (Offline-First Web)

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Estabelecer a infraestrutura de aplicação Web Progressiva (PWA) e motor de sincronização offline-first para o SIGO no navegador, garantindo que o shell da aplicação, ativos estáticos e SDKs sejam armazenados de forma imutável e atômica, permitindo carregamento cold offline sem dependência de CDNs externas, com persistência transacional local (IndexedDB) e fila durável de operações com integridade de anexos e revalidação de autorização.

## Stories

- Story 2.1: Service Worker e PWA
- Story 2.2: Cache do Aplicativo
- Story 2.3: Persistência Local IndexedDB
- Story 2.4: Fila de Sincronização
- Story 2.5: Armazenamento Local de Blobs
- Story 2.6: Particionamento de Cache
- Story 2.7: Isolamento de Operações
- Story 2.8: Sync Engine
- Story 2.9: Endpoints Transacionais
- Story 2.10: Idempotência de Comandos
- Story 2.11: Execução de Autorização
- Story 2.12: Indicador de Sincronização
- Story 2.13: Sistema de Carimbo (Watermark)
- Story 2.14: Versionamento e Migração

## Requirements & Constraints

- A aplicação deve ser instalável como PWA via `manifest.json` com ícones padronizados (192, 512, maskable) e exibição standalone.
- O Service Worker deve gerenciar o cache de shell (`sigo-shell-<hash>`) e ativos locais sem tocar diretamente no cache de dados de negócio.
- No build de produção (`tool/build_pwa.sh`), os SDKs Firebase e CanvasKit devem ser embutidos localmente (`--no-web-resources-cdn`), impedindo falhas em inicialização offline.
- Em desenvolvimento (`flutter run -d chrome`), o service worker deve operar sem travar recargas nem lançar exceções não tratadas no console.
- Persistência e fila durável no IndexedDB devem preservar payloads e anexos (bytes em base64/blobs) mesmo em quedas de rede, fechamento de aba ou troca de sessão.
- Falhas de autorização (`authorization_rejected`) ou conflitos de dados devem ser mantidos isolados para auditoria administrativa sem loops infinitos de retentativa.

## Technical Decisions

- **Estratégia de Build Web:** Flutter Web com `--no-web-resources-cdn --pwa-strategy=none`, gerando ativos locais empacotados por `prepare_pwa.py`.
- **Service Worker:** `sigo-sw.js` gerado atomicamente com chave versionada `sigo-shell-<sha256>`, cacheando `index.html`, `flutter_bootstrap.js`, `canvaskit` e scripts locais do Firebase.
- **Fila e Armazenamento Local:** `queue.js` e `operation_queue.dart` comunicando via JavaScript interop (`sigoQueue`), gerenciando estados `pending`, `syncing`, `synced`, `failed`, `conflict`, `authorization_rejected`.
- **Roteamento em Cache:** Requisições `navigate` no Service Worker respondem com `index.html` para suporte a rotas GoRouter sem dependência de rede.

## UX & Interaction Patterns

- Experiência mobile-first em navegadores desktop e móveis (Chrome/Safari).
- Tela de carregamento/splash e transição suave do shell PWA.
- Operações de cadastro (como Diário de Obra e Almoxarifado) devem permitir gravação e feedback imediato mesmo em modo desconectado.

## Cross-Story Dependencies

- Story 2.1 (Service Worker e PWA) é a fundação obrigatória para o empacotamento offline e ciclo de vida do cache que sustenta as Stories 2.2 a 2.14.
- Conecta-se diretamente aos contratos de dados de C3 (Financeiro) e C4 (Estoque) e aos testes ponta a ponta de navegador PWA (`functions/test/pwa-browser.cjs`).

---
# Adendo: Processamento Geométrico Assíncrono (Backend Python)

## Goal
O arquivo enviado é traduzido perfeitamente de CAD para um modelo geográfico navegável no backend de forma assíncrona, com áreas problemáticas analisadas, isoladas e devolvidas como um Rascunho Imutável (GeoJSON). Isso evita bloqueios de thread no cliente e prepara os dados topológicos para revisão.

## Stories Adicionais
- Story 2.1b: Gatilho OnFinalize e Extração de Geometria Bruta
- Story 2.2b: Algoritmo Espacial Point-in-Polygon
- Story 2.3b: Heurística de Ambiguidades e Persistência do Rascunho (GeoJSON)

## Requirements & Constraints (Backend)
- O processamento da geometria (parsing e testes topológicos) nunca deve ocorrer no cliente web para não bloquear a thread principal, deve ser executado no backend.
- O pipeline deve usar Cloud Functions em Python (Gen 2; 3.11+) com `ezdxf` e `shapely`.
- O processamento inicia via trigger `OnFinalize` no Cloud Storage.
- Lotes com identificação ambígua devem receber a propriedade estendida `"status": "ambiguo"`.
- O payload de saída para o Flutter deve ser estritamente em formato GeoJSON, armazenado no Firestore na coleção temporária `loteamentos_drafts`.

## Technical Decisions (Backend)
- **Async Pipeline & Immutable Drafts (AD-4):** O Flutter faz upload direto para o Cloud Storage e escuta o rascunho. O backend faz todo o processamento e não realiza inserções em massa no banco de dados raiz ainda, apenas grava um rascunho GeoJSON no `loteamentos_drafts`.
- **Parser Boundary and Stack (AD-3):** O backend realiza a leitura do .dxf via `ezdxf` e o teste Point-in-Polygon via `shapely` de forma isolada.
- **Ambiguity Resolution (AD-5):** A Cloud Function deve aplicar heurísticas iniciais para tentar extrair os nomes/números e se falhar/houver dúvidas, marcar como "ambiguo" para delegar a resolução humana na UI.

## Cross-Story Dependencies (Backend)
- Story 2.2b depende das geometrias extraídas na Story 2.1b.
- Story 2.3b depende do cálculo Point-in-Polygon concluído na Story 2.2b para associar Lotes a Quadras e montar o GeoJSON final.
- Epic 3 (Flutter UI) depende inteiramente do documento GeoJSON gerado ao final da Story 2.3b.
