---
title: 'hardening credenciais seed gac'
type: 'chore'
created: '09-22-2026'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O seed em modo cloud (`functions/scripts/seed-mock.cjs`, linha 27) aceita fallback implícito para `functions/serviceAccountKey.json` quando `GOOGLE_APPLICATION_CREDENTIALS` não está definido, reduzindo a disciplina de credenciais; além disso a decisão de hardening não está registrada em `docs/decisoes.md` e não há garantia processual de que arquivos de credencial deixem de entrar no repositório no futuro.

**Approach:** Exigir `GOOGLE_APPLICATION_CREDENTIALS` obrigatoriamente no modo cloud do seed (falhar com mensagem clara se ausente, vazio ou com arquivo inexistente — remover o fallback), registrar a decisão em `docs/decisoes.md` (próximo ID D8, status `aprovado-2026-09-22`), e garantir que a chave não entre no repo no futuro mantendo/ reforçando as regras de `.gitignore` já existentes e acrescentando verificação na CI (`.github/workflows/ci.yml`) que falha se algum arquivo de credencial estiver rastreado pelo git.

</frozen-after-approval>

## Implementation Notes

- `functions/scripts/seed-mock.cjs` — removido fallback `|| path.resolve(__dirname, '../serviceAccountKey.json')`; modo cloud agora: (1) exige `GOOGLE_APPLICATION_CREDENTIALS` não vazia (com `trim`), (2) exige que o caminho seja arquivo existente (`existsSync` + `statSync().isFile()` — pega diretório), (3) lê com `JSON.parse(fs.readFileSync(...))` dentro de `try/catch` (erro claro sem stack crua), (4) `require('path')` removido por ficar sem uso. Gatilhos `--cloud` e `TARGET=cloud` documentados no cabeçalho. Caminho emulador intacto.
- `docs/decisoes.md` — linha D8 adicionada na tabela D1-D7: decisão + status `aprovado-2026-09-22` + motivo + evidência (caminhos dos artefatos) + responsável maranduteam + data 22/09/2026.
- `.gitignore` — seção 1 reforçada com `*firebase-adminsdk*.json` (padrão do nome real `<projeto>-firebase-adminsdk-<hash>.json`). Padrões prévios (`*serviceAccountKey*.json`, `*service-account*.json`, `functions/serviceAccountKey.json`) mantidos; chave local `functions/serviceAccountKey.json` continua untracked e nunca foi commitada (`git log --all` vazio para o caminho).
- `.github/workflows/ci.yml` — job `no-secrets` adicionado: falha se `git ls-files` mostrar credenciais rastreadas (mesmos padrões do `.gitignore`, com anexos `.json` corrigidos para `firebase-adminsdk` e `.env.example` permitido). Verificado localmente: OK.
- Verificação executada: seed sem env / com espaços / com diretório / com JSON inválido / com `TARGET=cloud` → todos `exit 1` com mensagem `❌ [SEED]` clara; `node --check` OK; CI one-liner local OK; `git check-ignore` OK; `scripts/check-docs.py` OK.

## Review Triage Log

- blind-1 gitignore `firebase-adminsdk*.json` sem `*` inicial não pega nome real: verdict low (grupo padrão impreciso), patch aplicado — unificado para `*firebase-adminsdk*.json`.
- blind-2 regex CI `firebase-adminsdk` sem `.json$` (falso positivo em md): verdict low (grupo padrão impreciso), patch aplicado — `(^|/)[^/]*firebase-adminsdk[^/]*\.json$`.
- blind-3 cobertura incompleta de nomes (credentials.json, google-services.json, id_rsa...): verdict maybe-false/middle como expansão de escopo, defer em deferred-work.md.
- blind-4 `|| true` engole falha de `git ls-files`: verdict low — em checkout CI limpo `git ls-files` não falha; fix adicionaria complexidade; rejected.
- blind-5 CI só nomes, sem conteúdo/histórico: verdict medium como evolução, fora do intent, defer.
- blind-6 sem contrapartida local/pre-commit/seed:cloud/runbook: verdict low como DX, defer.
- blind-7 `existsSync` aceita diretório → stack crua: verdict medium, patch aplicado — `statSync().isFile()`.
- blind-8 `require` sem try/catch em JSON malformado: verdict medium, patch aplicado — `JSON.parse` + `try/catch` com mensagem `❌ [SEED]`.
- blind-9 env só espaços não tratada como vazia: verdict low mas exigido pelo Intent ("ausente, vazio"), patch aplicado — `trim`.
- blind-10 sem teste automatizado dos caminhos de falha: verdict low/evolução, defer.
- blind-11 spec untracked/status in-progress/Implementation Notes vazias: verdict false — resolvido pelo fluxo oneshot (notes preenchidas, status `done`, spec incluída no commit).
- blind-12 D8 sem `@hash` de baseline: verdict low — decisão nova sem baseline de fonte prévia; caminhos dão rastreabilidade pós-commit; rejected (fix exigiria commit em duas fases).
- blind-13 cabeçalho não documentava `TARGET=cloud`: verdict low, patch aplicado — linha do cabeçalho atualizada.
- blind-14 inventory.cjs sugere `./service-account.json` local: verdict low (arquivo é gitignored; sugestão não coloca chave no repo), defer junto com DX.
- blind-15 `.gitignore:28` redundante + chave local presente: verdict false — redundância pré-existente inócua; chave local é necessária para uso e nunca foi commitada.
- blind-16 no-secrets não executável via package.json/self-test: verdict low, defer junto com contrapartida local.

Grouping: A patch (padrão firebase-adminsdk impreciso: blind-1+2); B patch (validação de credencial no seed: blind-7+8+9); C patch (doc cabeçalho: blind-13); D defer (escopo de nomes/conteúdo/local/DX/testes: blind-3,5,6,10,14,16); E reject low (blind-4,12); F false (blind-11,15).

