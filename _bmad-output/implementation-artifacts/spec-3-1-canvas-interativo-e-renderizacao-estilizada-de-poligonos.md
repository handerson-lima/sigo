---
title: 'Story 3.1: Canvas Interativo e Renderização Estilizada de Polígonos'
type: 'feature'
created: '2026-09-27'
status: 'in-progress'
baseline_commit: 'a4820ca3697c0875309fccc4cd290caacaca70a3'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-3-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O rascunho GeoJSON gerado pelo backend após o upload do DXF não pode ser visualizado pelo usuário, impedindo-o de identificar onde estão os lotes com problema (status ambíguo).

**Approach:** Criar uma tela (`LoteamentoCanvasScreen`) contendo um visualizador interativo (`InteractiveViewer`) e um `CustomPaint` para desenhar os polígonos presentes no payload GeoJSON, aplicando cores distintas (neutro, laranja-alerta) com base na propriedade "status".

## Boundaries & Constraints

**Always:**
- Utilizar `InteractiveViewer` nativo do Flutter para gerenciar Pan & Zoom.
- Decodificar o payload como GeoJSON padrão, focando em `Polygon` e `MultiPolygon`.
- Acessar o campo "status" nas propriedades da feature ("properties") para determinar a cor.
- Inscrever a tela no documento do rascunho em `loteamentos_drafts` via repositório.

**Never:**
- Não usar pacotes de mapas reais (como `flutter_map` ou Google Maps), pois o GeoJSON pode estar fora de escala ou coordenadas terrestres locais; usar apenas coordenadas geométricas locais e independentes no Canvas.
- Não efetuar algoritmos espaciais complexos no frontend.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Acesso Inicial | Documento do rascunho válido com lista de Features | Canvas renderiza os polígonos centrados na tela, permitindo zoom e arraste | Mostrar estado vazio se sem features |
| Renderização Visual | Polígono com propriedade `status: ambiguo` | O polígono correspondente é preenchido com cor de alerta (ex: laranja) | Fallback para cor neutra |
| Geometria Inválida | GeoJSON com formato atípico (ex: falta coordinates) | O parser deve pular (skip) a Feature defeituosa sem falhar a tela inteira | Registrar erro no console |

</frozen-after-approval>

## Code Map

- `app/lib/src/features/loteamentos/presentation/loteamento_canvas_screen.dart` -- Nova tela de revisão que recebe o `draftId` e consome o stream do rascunho.
- `app/lib/src/features/loteamentos/presentation/widgets/geojson_canvas_widget.dart` -- Componente contendo o `InteractiveViewer` e um `CustomPainter` para desenhar a lista de Features GeoJSON.
- `app/lib/src/routing/app_router.dart` -- Adicionar a rota para `/construtoras/:cId/loteamentos/draft/:draftId`.

## Tasks & Acceptance

**Execution:**
- [x] `app/lib/src/features/loteamentos/presentation/widgets/geojson_canvas_widget.dart` -- Criar o componente de renderização 2D (Pan, Zoom, desenho de polígonos baseado no min/max bounds para enquadramento inicial).
- [x] `app/lib/src/features/loteamentos/presentation/loteamento_canvas_screen.dart` -- Criar a tela que escuta o `draftStreamProvider` e fornece o payload para o widget de renderização.
- [x] `app/lib/src/routing/app_router.dart` -- Registrar a nova rota de rascunho (`loteamentos/draft/:draftId`).

**Acceptance Criteria:**
- Given um usuário sendo redirecionado para a tela do rascunho após o processamento, when a tela carregar, then ele deve ver os polígonos representados na tela.
- Given o visualizador aberto, when o usuário fizer o gesto de pinça ou arrastar o mouse/dedo, then o mapa deve ampliar e mover (Pan & Zoom).
- Given um lote retornado pelo backend com "status": "ambiguo", when renderizado no canvas, then sua cor de preenchimento deve ser laranja/amarela (diferente da cor dos lotes válidos).

## Implementation Notes

## Spec Change Log

## Review Triage Log

## Verification

**Commands:**
- `cd app && flutter analyze` -- expected: Sem erros de linting.

**Manual checks (if no CLI):**
- Rodar o app, submeter um DXF (ou mock) que gere rascunho e validar que a tela transiciona e renderiza o canvas com pan e zoom fluídos.
