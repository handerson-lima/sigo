---
title: 'Fundações do Design System e Shell Responsivo'
type: 'feature'
created: '2026-09-23'
status: 'ready-for-review'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred: []
baseline_revision: 'a03d51d2d7cdfcda5d6192981823b325bfe20284'
---

<intent-contract>

## Intent

**Problem:** O sistema SIGO precisa de uma base visual coesa (cores, fontes e design system) e um shell responsivo para se adaptar a diferentes tamanhos de tela, dissociados da lógica de negócio.

**Approach:** Criar `ThemeData` e `ThemeExtension` no pacote genérico de design_system para manter cores e tipografias de forma estrita. Atualizar `SigoLayout`, `SigoTopBar` e `SigoSidebar` para refletir as quebras responsivas de 320, 390 e 800+, aplicando os tokens de cor e espaçamento extraídos do contrato.

## Boundaries & Constraints

**Always:** Manter a apresentação pura; o shell (design system) não deve se acoplar a regras de state management (Riverpod) ou navegação, essas partes já existem e devem ser injetadas/preservadas.

**Never:** Não misturar lógica de tenant, autenticação ou roteamento no Theme. Não importar componentes legados se for misturar temas soltos. Não adicionar propriedades fixas ou proporções hard-coded incompatíveis com telas pequenas.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Layout Responsivo Desktop | constraints.maxWidth > 800 | Row com Sidebar e Scaffold sem bottom/top bar solto | N/A |
| Layout Responsivo Mobile | constraints.maxWidth <= 800 | Scaffold com SigoTopBar e drawer para SigoSidebar | N/A |

</intent-contract>

## Code Map

- `app/lib/src/design_system/sigo_theme.dart` -- NEW: Arquivo contendo a definição do ThemeData e ThemeExtension (cores brand-blue, action-blue, dourado, tipografia base).
- `app/lib/main.dart` -- Import e injeção do SigoTheme.
- `app/lib/src/common_widgets/sigo_layout.dart` -- Ajuste do breakpoint > 800 e insets de página responsivos (16 / 32).
- `app/lib/src/common_widgets/sigo_sidebar.dart` -- Adequação das cores e tipografia da barra lateral aos tokens de design system.
- `app/lib/src/common_widgets/sigo_top_bar.dart` -- Aplicação do gradiente do cabeçalho e ajuste tipográfico.

## Tasks & Acceptance

**Execution:**
- `app/lib/src/design_system/sigo_theme.dart` -- Criar ThemeData e SigoThemeExtension com os tokens de DESIGN.md -- Centraliza o estilo do app inteiro num só lugar sem acoplar regras de negócio.
- `app/lib/main.dart` -- Importar e aplicar o novo ThemeData no MaterialApp -- Garante que toda a aplicação reflita a nova fundação.
- `app/lib/src/common_widgets/sigo_layout.dart` -- Atualizar Breakpoints e Insets (drawer até 800 e sidebar acima, insets 16 ou 32) -- Ajusta o shell à regra definida no DESIGN.md.
- `app/lib/src/common_widgets/sigo_sidebar.dart` -- Aplicar `{colors.sidebar}` e tokens de tipografia na barra lateral -- Adaptar navegação visualmente de forma pura.
- `app/lib/src/common_widgets/sigo_top_bar.dart` -- Modificar fundo para usar o gradiente de cabeçalho, atualizar cores de ícones/textos -- Finalizar aspecto responsivo e cores do cabeçalho de forma pura.

**Acceptance Criteria:**
- Given a navegação padrão em desktop (>800), when renderizar o SigoLayout, then a Sidebar está visível com largura de 250px (ou 72px colapsada) e o padding da tela é 32px.
- Given a navegação em telefone (<=800), when renderizar o SigoLayout, then o TopBar é visível, o padding é 16px, e a sidebar vira um drawer.
- Given o uso do app, when a UI for construída, then os estilos e cores principais devem ser retirados do SigoTheme.

## Verification

**Commands:**
- `cd app && flutter analyze` -- expected: Sem erros de análise no código do design system.
- `cd app && flutter test` -- expected: Passar em testes de layout se houver.

## Auto Run Result

Status: blocked
Blocking condition: no subagents
