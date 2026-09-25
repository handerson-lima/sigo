---
title: 'Minhas Construtoras exibe apenas construtoras ativas (inclusive para devs)'
type: 'feature'
created: '2026-09-24'
status: 'in-progress'
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

