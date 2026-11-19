---
title: 'Card Visual do Lote, Detalhes 360 Graus e Atribuição de Equipe ou Funcionário'
type: 'feature'
created: '2026-11-19'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '_bmad-output/specs/spec-remodelagem-loteamentos-sem-geometria/SPEC.md'
  - '_bmad-output/specs/spec-remodelagem-loteamentos-sem-geometria/data-contracts.md'
  - '_bmad-output/specs/spec-remodelagem-loteamentos-sem-geometria/architecture-diagrams.md'
---

## Intent

**Problem:** A listagem de lotes (`LotesListScreen`) exibia apenas um `ListTile` simples com o nome do lote e navegava diretamente para `EtapasListScreen`, sem apresentar medidas dimensionais, progresso consolidado das 5 etapas, ficha técnica completa (incluindo dados opcionais extraídos de PDF) ou atribuição rápida de equipes e funcionários ativos do módulo de RH.

**Approach:** Criar o card executivo `LoteSummaryCard` e integrá-lo em grade/lista responsiva na `LotesListScreen`, criar a tela 360º `LoteDetailScreen` na sub-rota `:loteId/detalhes` (preservando o deep-link legado `:loteId -> :loteId/etapas`, breadcrumbs e acesso à lista de etapas) e implementar o bottom sheet `AtribuirLotacaoLoteSheet` integrado aos streams de RH (`equipesStreamProvider` e `funcionariosStreamProvider`).

## Boundaries & Constraints

**Always:**
- Reutilizar tokens semânticos de `sigo_theme.dart` (`lotOnTimeBg`, `lotOnTimeInk`, `lotCompleteBg`, `lotCompleteInk`, `brandBlue`, `brandGold`, `actionBlue`, `surfaceBase`, `surfaceRaised`, `borderHairline`) com fallback seguro para `SigoTheme.extension`.
- Ler `progressoPercentual`, `etapasConcluidasCount`, `statusEtapasMap`, `equipesVinculadas` e `funcionariosVinculados` diretamente do documento desnormalizado `Lote` ao renderizar `LoteSummaryCard` (zero consultas em cascata).
- Filtrar apenas equipes e funcionários ativos (`isActive == true`) no `AtribuirLotacaoLoteSheet`.
- Recalcular atomicamente o progresso do lote via `EtapaRepository.updateEtapaProgresso` ao alterar status ou percentual de qualquer etapa na `LoteDetailScreen`.
- Exibir índices urbanísticos, recuos e carimbo na ficha técnica de `LoteDetailScreen` somente quando preenchidos.
- Restringir ações de atribuição, remoção de vínculos e edição do lote a administradores (`isAdmin`), preservando os testes existentes (`loteamento_quadra_lote_navigation_test.dart`, `obras_lotes_crud_test.dart`).

**Never:**
- Nunca exibir ou depender de geometria/GeoJSON/canvas.
- Nunca quebrar o redirecionamento de deep-link `:loteId -> :loteId/etapas` nem os breadcrumbs existentes.

## Code Map

- `app/lib/src/features/lotes/presentation/lote_summary_card.dart` — Card visual do lote exibindo identificação, logradouro, medidas resumidas, barra/percentual de conclusão, indicadores individuais das 5 etapas (`Muro`, `1ª`, `2ª`, `3ª`, `Branca`), resumo de equipes/funcionários vinculados e ação rápida `+ Atribuir` (admin).
- `app/lib/src/features/lotes/presentation/lotes_list_screen.dart` — Listagem responsiva (1, 2 ou 3 colunas via `LayoutBuilder`) de `LoteSummaryCard` com navegação para `LoteDetailScreen` e abertura do `AtribuirLotacaoLoteSheet`.
- `app/lib/src/features/lotes/presentation/lote_detail_screen.dart` — Tela de detalhes 360º com cabeçalho e progresso geral, diálogo de edição dos dados do lote (`updateLote`), ficha técnica completa (medidas principais + índices urbanísticos, recuos e carimbo quando preenchidos), gestão de equipes/funcionários vinculados com remoção em 1 toque e checklist interativo das 5 etapas com atualização de status/percentual (`updateEtapaProgresso`) e vínculo por etapa.
- `app/lib/src/features/lotes/presentation/atribuir_lotacao_lote_sheet.dart` — Bottom sheet com abas **Equipes RH** e **Funcionários RH**, filtro de ativos, busca textual e seleção de vínculo geral no lote ou em etapa específica (`atribuirEquipe` / `atribuirFuncionario`).
- `app/lib/src/features/lotes/routing/lotes_routes.dart` — Registro da sub-rota `detalhes` (`LotesPaths.detalhes`) sob `:loteId` com `AccessGuard(module: 'lotes')`.
- `app/test/src/features/lotes/presentation/lote_summary_card_test.dart` — Widget tests do `LoteSummaryCard`.
- `app/test/src/features/lotes/presentation/lotes_list_screen_test.dart` — Widget tests da `LotesListScreen`, navegação para `LoteDetailScreen`, breadcrumbs e permissões.
- `app/test/src/features/lotes/presentation/atribuir_lotacao_lote_sheet_test.dart` — Widget tests do `AtribuirLotacaoLoteSheet` (filtro de ativos, abas, vínculo geral e por etapa).
- `app/test/src/features/lotes/presentation/lote_detail_screen_test.dart` — Widget tests da `LoteDetailScreen` (ficha técnica completa/opcional, remoção de vínculo, atualização atômica de etapas, edição de lote e acesso a etapas).

## Verification

- `flutter analyze lib/src/features/lotes/ test/src/features/lotes/presentation/` — **0 issues**.
- `flutter test test/src/features/lotes/presentation/lote_summary_card_test.dart test/src/features/lotes/presentation/lotes_list_screen_test.dart test/src/features/lotes/presentation/atribuir_lotacao_lote_sheet_test.dart test/src/features/lotes/presentation/lote_detail_screen_test.dart test/loteamento_quadra_lote_navigation_test.dart test/obras_lotes_crud_test.dart` — **34/34 passando**.

## Review Triage Log

- **Revisão #16 (`story2-reviewer`) — APROVADO** (commit `926cf7d`):
  - Escopo, contratos de dados, tokens de `sigo_theme.dart`, streams de RH (`equipesStreamProvider` / `funcionariosStreamProvider`) e rotas/breadcrumbs validados contra `SPEC.md`, `data-contracts.md` e `architecture-diagrams.md`.
  - Verificação independente: `flutter analyze` com 0 issues; `flutter test test/src/features/lotes/presentation/ test/loteamento_quadra_lote_navigation_test.dart test/obras_lotes_crud_test.dart` com **41/41 testes passando**.
  - Observação menor (não bloqueante): `lotes_list_screen.dart` e `lote_detail_screen.dart` seguem o padrão `isAdmin || isOwner` (enquanto `LoteamentosListScreen`/`QuadrasListScreen` também aceitam `role == 'admin' || role == 'owner'`).
