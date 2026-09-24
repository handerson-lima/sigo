---
title: 'Corrigir testes obsoletos do modelo Lote'
type: 'bugfix'
created: '2026-09-24'
status: 'in-progress'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Após a refatoração da hierarquia (loteamento/quadra), o modelo `Lote` perdeu o campo `obraId` e ganhou `loteamentoId`/`quadraId` (com `status` obrigatório), e `LoteRepository.watchLotes` passou a receber 3 argumentos. Os testes que ainda usam a API antiga não compilam, deixando a suíte quebrada.

**Approach:** Atualizar os testes e fixtures para a nova assinatura do modelo `Lote` e da interface `LoteRepository`, preservando a semântica de cada teste. Sem mudanças em código de produção.

</frozen-after-approval>

## Implementation Notes

- Corrigidos os construtores `Lote(...)` (troca de `obraId` por `loteamentoId`/`quadraId` + `status`) e as assinaturas `watchLotes` (3 args) em 5 arquivos de teste + 1 fixture. Sem mudanças em produção.
- Descoberta durante a implementação: `app/lib/src/features/lotes/presentation/lotes_list_screen.dart:33` usa a API antiga `SigoBreadcrumbs(segments: [...])`, mas o widget foi reescrito (commit `de88af4`) para derivar os breadcrumbs do path do GoRouter (`const SigoBreadcrumbs()`), como já fazem as telas de setores e equipes. Isso gera erro de compilação em produção e bloqueia `obras_lotes_crud_test.dart` e `setores_equipes_navigation_test.dart`.
- `test/sigo_breadcrumbs_test.dart` (da tarefa anterior) também quebrou pela mesma mudança de API.
- `test/stock_saida_test.dart` compila agora, mas 3 testes falham em runtime com overflow de RenderFlex (Row) na `MovimentacaoScreen`.

