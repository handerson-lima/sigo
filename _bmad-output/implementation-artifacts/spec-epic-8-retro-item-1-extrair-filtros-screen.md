---
title: 'epic-8-retro-item-1 Extrair filtros de membros'
type: 'refactor'
created: '2026-09-24'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `membros_screen.dart` (514 linhas) concentra lista + filtros + busca + dropdown de obra + refresh + estados de erro/offline — finding 3 (god-class growth) da retrospectiva do epic 8; o item de ação `epic-8-retro-item-1-extrair-filtros-screen` segue `open` em `sprint-status.yaml` e foi acionado explicitamente pelo humano.

**Approach:** Extrair o método `_buildFiltroBar` (SegmentedButton Todos/Por obra/Pendentes, TextField de busca, dropdown de obra) para um widget dedicado `StatelessWidget` em `presentation/widgets/`, espelhando o padrão da extração RH (`ChamadaFiltrosHeader`): estado permanece no parent (providers Riverpod + `_buscaController`), widget recebe dados e callbacks; refactor puro de comportamento preservado — os testes do grupo `8.2 filtros e busca (widget)` em `membros_test.dart` devem continuar verdes sem alteração.

</frozen-after-approval>

## Implementation Notes

- Widget criado: `app/lib/src/features/construtoras/presentation/widgets/membros_filtros_header.dart` — `MembrosFiltrosHeader` (StatelessWidget), presentation-only com dados + callbacks required (estado permanece no parent, convenção da feature).
- `membros_screen.dart`: `_buildFiltroHeader` reduzido de ~113 linhas de UI para binder fino (~24 linhas) que instancia `MembrosFiltrosHeader` com callbacks ligados aos providers `filtroMembrosProvider`/`buscaMembrosProvider`/`obraSelecionadaProvider` e ao `_buscaController` (que permanece na tela). Param unused `construtoraId` removido da assinatura; os dois call sites (lista vazia e índice 0 da lista) ajustados.
- Contratos de providers, microcopy testada (`Todos`, `Por obra`, `Pendentes`, `Limpar busca`, etc.), key/`initialValue` do dropdown e comentários de Flutter 3.47 preservados literalmente.
- Tela: 514 → 425 linhas; UI pesada agora no widget dedicado.
- Verificação: `flutter analyze` → apenas 13 `unused_import` pré-existentes de roteamento (baseline confirmado); `flutter test test/features/construtoras/membros_test.dart` → 118/118 All tests passed (grupo 8.2 incluído, sem alteração de testes).

## Review Triage Log

- contagem-linhas-424 | verdict: low | evidência: real (514−106+17=425); corrigido para 425 nas notes.
- refs-call-sites-L353-L401 | verdict: low | evidência: posições pré-refactor; refs de linha removidas das notes.
- status-frontmatter-in-progress | verdict: false | evidência: fluxo oneshot promove a `done` apenas no Finalize Spec; `in-progress` era o estado esperado durante a review.
- sprint-status-action-aberto | verdict: false | evidência: `story_key` vazio (item de retro sem chave `development_status`); step-oneshot só lê `sync-sprint-status.md` quando `story_key` não é vazio.
- checkbox-retro-nao-marcado | verdict: false | evidência: mesmo gate do finding anterior; retro é registro histórico, tracking vive em `action_items` do sprint-status.
- sem-teste-direto-widget | verdict: low | rejeitado: cobertura indireta completa (118 testes; grupo 8.2 exercita toda a barra via tela); fix exigiria novos testes > correção simples.
- params-posicionais-trocaveis | verdict: false | evidência: tipos impedem swap silencioso — `String?` não assignable a `String` e `FiltroMembros` é tipo próprio; troca vira erro de compile.
- naming-bar-vs-header | verdict: low | evidência: real; `_buildFiltroBar` renomeado para `_buildFiltroHeader`.
- query-controller-sem-doc | verdict: low | rejeitado: sincronia mantida por construção (onChanged→provider; limpar atualiza controller+provider); comentário seria nice-to-have.
- doc-paridade-chamada-fraca | verdict: low | evidência: real; comentário reescrito sem a afirmação de paridade.
- retry-ausente-erro-obras | verdict: false | evidência: retry mudaria comportamento; intent congelado é refactor de preservação literal (estado de erro original copiado sem retry).
- context-vazio | verdict: low | rejeitado: campo opcional do template; Intent já nomeia o item de retro de origem.
- linhas-aproximadas-22-112 | verdict: low | agrupado com contagem-linhas; notes agora usam ~24 e ~113.
- incidente-stash-nas-notes | verdict: low | evidência: ruído de processo; narrativa removida das Implementation Notes.

