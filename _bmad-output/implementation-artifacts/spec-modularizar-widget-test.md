---
title: 'Modularização de widget_test.dart por Domínio'
type: 'refactor'
created: '2026-09-17'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-2-retro-2026-09-17.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O arquivo `app/test/widget_test.dart` centraliza mais de 680 linhas com múltiplos domínios de testes de widget e de regras (autenticação, access guard, troca de obras, sidebar, topbar e normalização de módulos), dificultando a manutenção, evolução e execução seletiva de testes conforme identificado nos itens de ação `epic-1-retro-item-1-modularizar-testes` e `epic-2-retro-item-3-modularizar-widget-test`.

**Approach:** Decompor `app/test/widget_test.dart` em arquivos de teste temáticos e modulares em `app/test/`:
1. `app/test/auth_initialization_widget_test.dart`: Inicialização e rotas para usuário deslogado.
2. `app/test/access_guard_test.dart`: Regras e bloqueios de acesso por construtora, obra e módulo (`AccessGuard`, dev global, obras inativas, membros inativos e fallbacks).
3. `app/test/obra_switcher_layout_test.dart`: Alternância de Obra A -> Obra B e recálculo dinâmico imediato do layout/dashboard.
4. `app/test/sigo_sidebar_test.dart`: Comportamento reativo de itens de navegação da `SigoSidebar`.
5. `app/test/sigo_top_bar_test.dart`: Comportamento de `SigoTopBar` e rota ativa explícita.
6. `app/test/member_modules_normalization_test.dart`: Normalização de módulos e fallback fechado (`normalizeRawModules`).
7. Manter `app/test/widget_test.dart` como orquestrador ou smoke test mínimo sem duplicação.
Garantir que 100% dos testes continuem passando sem qualquer quebra de regressão.

</frozen-after-approval>

## Implementation Notes

- Arquivo `app/test/widget_test.dart` (687 linhas) dividido com sucesso em 6 arquivos modulares focados por domínio.
- `app/test/widget_test.dart` simplificado para atuar como smoke test de inicialização do app.
- Todas as dependências e imports validados sem advertências no `flutter analyze`.
- Todos os 114 testes do Flutter executados e aprovados com 100% de sucesso (`flutter test`).
- Itens de ação `epic-1-retro-item-1-modularizar-testes` e `epic-2-retro-item-3-modularizar-widget-test` atendidos.

