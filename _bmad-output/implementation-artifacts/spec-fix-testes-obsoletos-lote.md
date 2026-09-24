---
title: 'Corrigir testes obsoletos do modelo Lote'
type: 'bugfix'
created: '2026-09-24'
status: 'done'
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
- Escopo expandido (aprovado pelo usuário) para deixar a suíte verde: (1) `lotes_list_screen.dart` passou a usar `const SigoBreadcrumbs()`; (2) correção do `redirect` quebrado em `lotes_routes.dart`/`setores_routes.dart` (string escapada `'\${...}'` e uso do path completo) para redirect condicional via `state.matchedLocation`; (3) `movimentacao_screen.dart` envolveu dois textos de cabeçalho em `Expanded` para eliminar overflow; (4) prefixo de navegação em `setores_list_screen.dart` corrigido de `/construtoras/` para `/construtora/`.

## Review Triage Log

- `low` (defer) — usar `SetoresPaths.list`/`EquipesPaths.list` em vez dos literais `'setores'`/`'equipes'` no redirect. Cosmético; não justifica nova alteração agora.
- `low` (defer) — padrão de redirect condicional duplicado em 4 arquivos de rota (inclui arquivos de outra história). Refatoração desnecessária neste escopo.
- `low` (defer) — `state.uri.path` (decodificado) vs `state.matchedLocation` (codificado) pode divergir para IDs com caracteres especiais; IDs do Firestore são alfanuméricos, então probabilidade baixa e redirect é defensivo.
- `low` (defer) — trailing slash em match exato não é normalizado. Caso raro.
- `low` (defer) — o comportamento exato do redirect (`/lotes/:loteId` → `/setores`) não tem teste direto; o caminho profundo é coberto pelos testes de navegação. Gap defensivo, registrado como follow-up.
- `low` (defer) — correção de layout (`Expanded`) sem teste dedicado; os testes de estoque já pinam a renderização sem overflow.


