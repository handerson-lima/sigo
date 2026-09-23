---
title: 'Infraestrutura Segura para Gestão de Logos'
type: 'feature'
created: '2026-09-23'
status: 'done'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred: []
baseline_revision: '4ab8840df46244d3114a859f7d695ac33c374bd6'
---

<intent-contract>

## Intent

**Problem:** O sistema permite a gestão de logotipos de construtoras, porém não possui regras seguras no backend (Firestore e Storage) para governar o upload (validação de tamanho, tipo de arquivo) e processamento adequado para prevenir ataques via imagens maliciosas ou muito grandes.

**Approach:** Implementar no `firestore.rules` permissões adequadas, adicionar no `storage.rules` regras rigorosas de upload (limite de 2 MiB, apenas JPEG/PNG/WEBP), e criar uma Cloud Function (`onFinalize` trigger no Storage) que processa as imagens via `sharp`, removendo metadados nocivos, garantindo limite seguro, e salvando o resultado tratado.

## Boundaries & Constraints

**Always:** Manter a proteção no servidor (limites de tamanho no Storage e sanitização na Cloud Function). Apenas administradores da construtora podem enviar ou atualizar o logotipo. Proteger contra loops de trigger (a função não deve processar arquivos já processados).

**Never:** Não confiar na validação client-side para restrições de tamanho ou tipo. Não permitir o armazenamento de metadados nocivos (EXIF, localização).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Upload de arquivo acima de 2 MiB | Arquivo > 2 MiB e `request.auth.uid` admin | Rejeitado por regras de storage | Firebase Storage retorna "Permission denied" |
| Upload de arquivo não-imagem | Arquivo tipo application/pdf, etc. | Rejeitado por regras de storage | Firebase Storage retorna "Permission denied" |
| Upload válido de logo | Imagem válida (<= 2 MiB, jpeg/png/webp) | Storage trigger processa com `sharp`, elimina EXIF e ressalva limpo | N/A |
| Upload por usuário sem privilégios | Usuário não admin tenta alterar logo | Rejeitado (Firebase Rules) | Firebase Storage retorna "Permission denied" |

</intent-contract>

## Code Map

- `storage.rules` -- Adição de rules match para `construtoras/{c}/logos/{filename}` com limites estritos (tamanho `<= 2MB`, `image/*`) e controle de acesso restrito a administradores.
- `firestore.rules` -- Regras de permissão sobre os metadados ou referências do logo, garantindo que o logo possa ser modificado apenas pelo `admin(c)`.
- `functions/package.json` -- Adição da dependência `sharp` e `@types/sharp` (se necessário) para processamento de imagens.
- `functions/src/index.ts` -- Nova Cloud Function de Storage (ex: `processLogoUpload`) para interceptar novos uploads de logos, utilizar o `sharp` para redimensionar (se necessário) e limpar metadados, prevenindo execuções cíclicas infinitas checando metadados/contentType.

## Tasks & Acceptance

**Execution:**
- [x] `storage.rules` -- Adicionar match para `construtoras/{c}/logos/{filename}` permitindo create e update apenas para admin(c), limitando tamanho `request.resource.size <= 2 * 1024 * 1024` e `request.resource.contentType.matches('image/(jpeg|png|webp)')`. -- Restringe payloads pesados e tipos inválidos diretamente na borda.
- [x] `firestore.rules` -- Adicionar permissão (se não houver) para gerenciar o documento ou URL de logo na coleção da construtora, restrito a `admin(c)`. (Atualização da chave `logoUrl` em construtoras ou documento dedicado). -- Assegura autoridade e privilégios.
- [x] `functions/package.json` -- Adicionar `sharp` nas dependencies e `@types/sharp` nas devDependencies, rodar `npm install`. -- Traz suporte nativo robusto a manipulação de imagens (Node).
- [x] `functions/src/index.ts` -- Implementar Cloud Function ouvindo eventos `functions.storage.object().onFinalize`. Identificar o path (logo de construtoras). Baixar a imagem, processar com `sharp` (remover metadados, opcional limite max 10 megapixels), e fazer upload de volta com metadado extra marcando como "processada" para evitar looping eterno. -- Transforma uploads raw perigosos em artefatos seguros para visualização e proxy.

**Acceptance Criteria:**
- Given um upload de imagem > 2MiB num bucket protegido, when as regras avaliarem, then será rejeitado nativamente antes mesmo de disparar Cloud Functions.
- Given um upload válido de imagem 1.5MiB por admin, when o trigger executar, then o arquivo final gravado terá os metadados (EXIF) raspados e constará metadados customizados de processamento.

## Verification

**Commands:**
- `cd functions && npm install && npm run build` -- expected: Sem erros de build ou tipos.

### Review Findings

**decision-needed:**
- [x] [Review][Decision] Leitura pública de logos permite enumeration de IDs de construtora — resolvido: manter `allow read: if true` (decisão do usuário: logo como ativo de marca; enumeração de `{c}` aceita como trade-off).

**patch:**
- [x] [Review][Patch] Metadata controlável pelo cliente permite pular sanitização (bypass do loop-guard) [storage.rules:10-14, functions/src/index.ts:334]
- [x] [Review][Patch] processLogo sem tratamento de erro: falha de sharp/404 deixa imagem sem sanitização ou crasha o trigger em loop de retry [functions/src/index.ts:332-356]
- [x] [Review][Patch] file.save substitui metadata inteira e apaga firebaseStorageDownloadTokens, quebrando URLs de download [functions/src/index.ts:350-355]
- [x] [Review][Patch] logoUrl aceito no update sem validação de tipo string [firestore.rules:43]
- [x] [Review][Patch] Sem testes de rules para update de logoUrl nem para o path de logos no Storage [firestore.rules:43, storage.rules:10-14]
- [x] [Review][Patch] Integração TypeScript do sharp: `@types/sharp@0.31` obsoleto + import dinâmico com `@ts-ignore` e fallback defensivo [functions/package.json:30, functions/src/index.ts:343-344]
- [x] [Review][Patch] `admin(c)` do Storage sem guard de existência do doc de membro (drift em relação ao `firestore.rules`, erro opaco em doc ausente) [storage.rules:8]
- [x] [Review][Patch] Guard de processed lê metadata do evento (payload possivelmente obsoleto) em vez da metadata fresca já obtida [functions/src/index.ts:334-338]
- [x] [Review][Patch] Conteúdo declarado `image/*` pode não corresponder aos bytes reais; save grava contentType herdado do upload após processamento [functions/src/index.ts:340-355]

**defer:**
- [x] [Review][Defer] Handler `processLogo` nunca executado por teste algum [functions/src/index.ts:332-356] — deferred: o repo não tem harness que execute handlers de trigger Storage (`test:emulators` não inclui o emulador de functions); criar esse harness excede o escopo desta mudança.

**Rejected:**
- decision-needed (leitura pública de logos) — rejected: usuário optou por manter `allow read: if true`; trade-off de enumeração aceito.
- false — sharp 0.35 funciona em Cloud Functions via optionalDeps; não há webpack/bundler configurado no projeto (deploy Node instala deps com npm na plataforma alvo).
- false — lockfile incluir todos os optionalDeps de plataforma é comportamento normal do npm; `npm ci` no deploy Linux instala os binários linux corretos.
- false — `engines.node: "20"` no GCF resolve para o latest Node 20.x (>= 20.9.0 exigido pelo sharp 0.35.4).
- false — sobrescrever o original com versão sanitizada corresponde à intenção da story ("ressalva limpo", AC2: arquivo final com EXIF raspado).
- false — `sharp.toBuffer()` sem formato de saída preserva o formato de entrada; as storage rules já restringem a entrada a jpeg|png|webp.
- false — as storage rules são o ponto de enforcement no caminho do cliente; o check mais largo na função é defesa em profundidade redundante, não um bypass.
- false — o lockfile resolve `semver@7.8.5`, que satisfaz `^7.8.5` exigido pelo sharp.
- false — todo o código existente em `functions/src/index.ts` usa a API v1 (`functions.https.callable`, `functions.storage.object`); o trigger novo segue o padrão do repo.
- false — o export do sharp (CJS/ESM) sempre fornece `default` truthy (função); o fallback `|| import()` é inalcançável na prática.
- false — `npm run build` passa sem erros reportados (o `@ts-ignore` suprime, não falha, a checagem); a qualidade do import está coberta pelo finding de integração sharp.
- false — `admin(c)` com `dev()` segue o padrão estabelecido em `firestore.rules` e a exceção global de dev confirmada (`sprint-status.yaml`: `preserve_global_dev: confirmed_by_user`).

## Auto Run Result

Status: blocked
Blocking condition: no subagents

