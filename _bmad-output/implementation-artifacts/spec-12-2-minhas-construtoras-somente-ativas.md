---
title: 'Minhas Construtoras exibe apenas construtoras ativas (inclusive para devs)'
type: 'feature'
created: '2026-09-24'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A tela "Minhas Construtoras" ainda exibe construtoras inativas para devs: o branch dev de `ConstrutoraRepository.getUserConstrutoras` retorna todas as construtoras sem filtrar `isActive`, e o fallback de cache também só filtrou para não-dev na 12.2.

**Approach:** Aplicar `filtrarConstrutorasAtivas` também no branch dev e no fallback de cache, de modo que "Minhas Construtoras" mostre somente construtoras ativas para qualquer usuário, inclusive dev. Não alterar a tela de Gestão Global de Construtoras do dev (`dev_construtoras_list_screen.dart`), que continua exibindo todas as construtoras (com seus filtros/chips).

</frozen-after-approval>

## Implementation Notes

- Alterado `app/lib/src/features/construtoras/data/construtora_repository.dart`:
  - branch `dev` de `_loadgetUserConstrutoras` agora retorna `filtrarConstrutorasAtivas(...)` (antes retornava todas);
  - fallback de cache em `getUserConstrutoras` agora filtra sempre (removido o condicional `dev ? items : ...`).
- O parâmetro `dev` continua sendo usado apenas para a chave de cache e para escolher o branch de consulta (todas as construtoras vs. vínculos do usuário).
- `dev_construtoras_list_screen.dart` (Gestão Global do dev) não foi alterado.
- Verificação: `flutter analyze` limpo; testes de `features/construtoras` 125/125.

## Review Triage Log

- Estado vazio do dev ("Nenhuma construtora encontrada no sistema.") falso quando só há inativas — low — corrigido para "Nenhuma construtora ativa encontrada." (`construtoras_list_screen.dart:38`). → patch.
- Caminhos alterados (branch dev + decode) sem teste — low — wiring trivial sobre predicado já testado; exigiria fake de Firestore. Rejeitado.
- Branch dev baixa a coleção inteira e filtra no cliente — low — o filtro no cliente preserva a semântica de legado (doc sem `isActive`); um `.where('isActive', true)` esconderia legados. Rejeitado.
- Branch dev sem tratamento de `permission-denied` — false — para dev ativo `dev()` libera leitura irrestrita; a negação não ocorre nesse caminho.
- `construtoraInacessivel` só cobre `permission-denied`, cache usa `unauthenticated` — low — divergência pré-existente da 12.2, fora deste caminho. Rejeitado.
- Filtro duplicado (load + decode) — false — o decode cobre entradas de cache gravadas antes da mudança; o predicado é idempotente.
- Spec `in-progress`/iteration 0 com notas dizendo pronto — false — finalizada agora.
- Spec sem AC/verificação, sem Risks/out-of-scope, sem cache key, doc comment do `null` — false — formato oneshot e detalhes de implementação; sem impacto de comportamento.
- Semântica "todas as ativas" para dev vs "minhas" — false — comportamento pré-existente; o pedido foi apenas ocultar inativas.
- Nome `_loadgetUserConstrutoras` mal-cased — low — pré-existente, cosmético. Rejeitado.

**Patch aplicado:** copy do estado vazio dev. **Verificação:** `flutter analyze` limpo; `flutter test` 503/503.

**Revisão de homologação (2026-09-26):** recorte = commits `07171a8` + `c0be5c4` vs baseline `ed53736`; 4 camadas (blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor). Esta spec renegocia o AC da spec original ("dev continua vendo todas as construtoras"): a homologação confirma que o código atual reflete esta spec — "Minhas Construtoras" filtra ativas também para dev, enquanto a Gestão Global do dev (`dev_construtoras_list_screen.dart`) segue vendo todas. Patch de teste aplicado (copy do estado vazio dev). Achados e triagem completos em `spec-12-2-ocultar-construtoras-inativas-na-listagem.md` (seção "Revisão de homologação").

