---
title: 'Ocultar construtoras inativas na listagem do usuário'
type: 'feature'
created: '2026-09-24'
status: 'done'
route: 'dispatch'
baseline_commit: 'ed53736b284a296bef98bc6f9255239dc6c0ee20'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Um usuário comum membro de uma construtora inativada continua vendo-a em "Minhas Construtoras" e mantém acesso aos seus dados. A listagem só filtra o flag do vínculo (`construtora_members.isActive`), ignorando o flag da própria construtora (`construtoras.isActive`), e as Security Rules não barram leitura de construtoras inativas.

**Approach:** Ocultar construtoras com `isActive == false` na carga de "Minhas Construtoras" para usuários comuns e forçar a restrição nas Security Rules do Firestore, barrando o acesso a construtoras inativas. Devs mantêm acesso irrestrito.

## Boundaries & Constraints

**Always:**
- `construtoras.isActive` ausente ⇒ tratado como `true` (docs legados continuam acessíveis).
- A restrição de visibilidade aplica-se apenas a usuários comuns (branch `dev == false`); devs continuam vendo todas as construtoras.
- Inativar é mascarar via flag: nunca deletar dados, nunca bloquear login.
- A restrição deve ser forçada no servidor (Security Rules), não apenas na UI.
- Bloqueio **global** (decisão): as Security Rules passam a exigir construtora ativa em `member(c)`; usuário comum perde acesso à construtora inativa, às obras, aos loteamentos, aos módulos e aos dados dela. O dev permanece irrestrito.

**Never:**
- Não alterar o Painel Dev nem a tela/lógica da story 12.1.
- Não adicionar dependências novas nem `collectionGroup` sobre `construtoras`.
- Não expor construtoras inativas a usuários comuns por nenhuma query ou caminho direto.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Lista com vínculo em construtora inativa | membro `isActive:true`, construtora `isActive:false` | construtora ausente da lista | tela sem erro |
| Lista com vínculo ativo | construtora `isActive:true` | construtora exibida | N/A |
| Leitura de doc de construtora inativa por usuário comum | `isActive:false` | leitura negada | `permission-denied` tratado como sem acesso |
| Doc de construtora sem campo `isActive` | campo ausente | tratado como ativo | N/A |
| Leitura por dev | `dev()` ativo | permitida | N/A |

</frozen-after-approval>

## Code Map

- `firestore.rules:8` -- `member(c)` (hoje: `cmExists && cm.isActive`); `firestore.rules:41` -- read de `construtoras/{c}`. Adicionar helper `activeConstrutora(c)` (`get(...construtoras/$(c)).data.get('isActive', true) == true`) e exigi-lo em `member(c)` (bloqueio global).
- `app/lib/src/features/construtoras/data/construtora_repository.dart:67-116` -- `_loadgetUserConstrutoras`: branch não-dev (L83-115) busca membros e lê cada doc pai da construtora; filtrar `isActive == false` e ignorar `permission-denied` do doc pai. Branch dev (L71-82) inalterado.
- `app/lib/src/features/construtoras/presentation/user_construtoras_provider.dart:9-20` -- passa `dev` do `trustedDevProvider`; ponto de teste via override.
- `app/lib/src/features/construtoras/domain/construtora.dart:12,19` -- `isActive` com default `true`; reutilizar, não alterar.
- `app/lib/src/features/construtoras/presentation/construtoras_list_screen.dart:27-53` -- consome o provider; estados loading/erro/vazio já existem; sem mudança.
- `functions/test/security-rules.test.cjs:88-90,105-139` -- fixtures de construtoras/membros; `:240-262` testes de isolamento/inativo. Adicionar construtora inativa + membro e casos de leitura.
- `firestore.indexes.json:3-16` -- índice collectionGroup atual é suficiente; sem alteração.

## Tasks & Acceptance

**Execution:**
- [x] `firestore.rules` -- adicionar `activeConstrutora(c)` e exigi-lo em `member(c)` -- forçar a restrição global no servidor.
- [x] `app/lib/src/features/construtoras/data/construtora_repository.dart` -- no branch não-dev, descartar construtoras com `isActive == false` e tratar `permission-denied` ao ler o doc pai (retornar null/descartar) -- a lista nunca exibe inativas nem quebra a tela.
- [x] `app/lib/src/features/construtoras/data/construtora_repository.dart` (ou helper puro `@visibleForTesting`) -- extrair predicado de filtro testável -- dar cobertura automatizada ao filtro.
- [x] `functions/test/security-rules.test.cjs` -- adicionar fixtures (construtora inativa + membro ativo nela) e testes de leitura negada/aceita -- provar as Security Rules.

**Acceptance Criteria:**
- Given usuário comum membro de construtora com `isActive:false`, when abre "Minhas Construtoras", then a construtora não aparece e a tela não exibe erro.
- Given construtora com `isActive:true`, when usuário comum abre a lista, then ela permanece visível.
- Given usuário comum membro de construtora inativa, when lê `construtoras/{c}` e dados dela (obras, loteamentos, módulos), then leitura negada; dev permanece autorizado.
- Given doc de construtora sem `isActive`, when avaliado por regra/query, then tratado como ativo.
- Given dev logado, when abre a lista, then continua vendo todas as construtoras independentemente de `isActive`.

## Implementation Notes

## Spec Change Log

## Review Triage Log

| # | Achado (camada) | Veredito | Evidência |
|---|-----------------|----------|-----------|
| 1 | spec `in-review` vs `sprint-status` `in-progress` | false | Planos distintos; o workflow sincroniza o sprint-status em marcos e o atualiza no step-05. Sem defeito de código. |
| 2 | Seções Implementation/Change/Triage vazias | false | Seções append-only/opcionais do workflow; esta triagem as popula agora. |
| 3 | `activeConstrutora` sem guard de existência (membership órfã) | false | `get()` de doc inexistente torna a avaliação da regra falsa — fail-closed, nega acesso; nenhum acesso indevido. Legado coberto por 2.5. |
| 4 | `get()` extra em `member(c)` (limites/custo) | low | Nenhum estouro de limite demonstrado; custo desprezível nesta escala; fix é inerente à feature. Rejeitado. |
| 5 | Regras wildcard (`firestore.rules:214-216`) liberam members/movimentacoes de construtora inativa | low | Pré-existente (`movimentacoes` aberto a qualquer signed); não introduzido pela 12.2. → **defer**. |
| 6 | Teste 2.4 (obra) trivialmente verdadeiro | low | A negação real é provada por `mat_inativa` (módulo estoque) e pela leitura do doc da construtora; a assertion de obra é redundante. Rejeitado. |
| 7 | Lógica nova do repositório (catch `permission-denied`/`parent==null`/`rethrow`) sem teste | medium | AC "tela sem erro" poderia regredir sem detecção. Corrigido: seam `construtoraInacessivel` + teste. → **patch**. |
| 8 | Teste passa `null`s e não exercita a exceção | medium | Mesma raiz do #7; coberto pelo novo teste de `construtoraInacessivel`. → **patch** (agrupado). |
| 9 | Caminho de query real sem teste | medium | Mesma raiz do #7; cobertura limitada por não haver fake de Firestore; comportamento provado por regras + filtro. Agrupado. |
| 10 | Âncoras do Code Map desatualizadas | false | Correção exigiria editar a spec; line drift não afeta comportamento e o Code Map é apoio de planejamento. |
| 11 | Consequência (admin perde edição) não documentada | false | A decisão "bloqueio global" na frozen já cobre usuário comum; admin não-dev é usuário comum. |
| 12 | `activeConstrutora` sem `signed()` | false | Chamada só dentro de `member(c)`, após `cmExists` (que exige `signed()`); consistente com `cm()`. |
| 13 | N+1 leituras `Source.server` | low | Padrão pré-existente (o código já fazia 1 `get` por vínculo); escala pequena. Rejeitado. |
| 14 | `test:rules` não roda em CI | low | Infra pré-existente: o script nunca esteve no CI (verificação manual documentada). → **defer**. |
| 15 | Decode do `cachedRead` não reaplicava o filtro | low | Construtora inativa cacheada antes podia reaparecer no fallback offline; corrigido no decode (respeitando `dev`). → **patch**. |
| 16 | Rota direta a construtora inativa mostra erro em vez de Acesso Negado | low | `AccessGuard` decide só pelo vínculo (pré-existente); os dados são negados no servidor (sem exposição); exige navegação direta a item não listado. → **defer**. |

**Patches aplicados:** #7/#8/#9 (`construtoraInacessivel` + teste) e #15 (filtro no decode do cache).
**Verificação pós-patch:** `flutter analyze` limpo; `flutter test` 501/501; `npm run test:rules` 25/25.

## Design Notes

- O `collectionGroup('construtora_members')` não permite filtrar campos do doc pai (`construtoras.isActive`) na query. Por isso a leitura dos docs-pai é feita individualmente e a construtora inativa é descartada no cliente; a garantia server-side vem das Security Rules. Sem novo índice.
- Para evitar `permission-denied` quebrando a lista, cada leitura de doc-pai é isolada: `permission-denied` ⇒ descarta aquela construtora (equivale a inativa/sem acesso).

## Verification

**Commands:**
- `flutter analyze` (workdir `app`) -- expected: sem erros.
- `flutter test` (workdir `app`) -- expected: todos passam.
- `npm run test:rules` (workdir `functions`) -- expected: testes de Security Rules passam (usa emulador Firebase).

**Manual checks (if no CLI):**
- Inativar uma construtora no Painel Dev e recarregar "Minhas Construtoras" com um usuário comum membro: a construtora não deve aparecer; com usuário dev, deve continuar aparecendo.
