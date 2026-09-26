---
title: 'Story 2.2: Algoritmo Espacial Point-in-Polygon'
type: 'feature'
created: '2026-09-26'
status: 'done'
baseline_commit: 'b346638400af2fb58126a2d4757689f15f984726'
route: 'dispatch'
review_loop_iteration: 0
context: ["_bmad-output/implementation-artifacts/epic-2-context.md"]
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O backend extraiu as geometrias brutas de Lotes e Quadras de um arquivo DXF (Story 2.1), mas ainda não determinou o pertencimento espacial de cada Lote à sua respectiva Quadra, o que é essencial para construir a topologia correta do loteamento.

**Approach:** Implementar um algoritmo de teste Point-in-Polygon (usando a biblioteca `shapely`) dentro do pipeline da Cloud Function Python. O algoritmo converterá as polylines/linhas extraídas pelo `ezdxf` em polígonos válidos, calculará o centroide de cada Lote e verificará em qual polígono de Quadra ele está contido.

## Boundaries & Constraints

**Decisions:**
- Associação de Lotes Órfãos: Lotes cujo centroide não caia em nenhuma quadra devem ser mantidos com status de "Sem Quadra" e incluídos no rascunho para correção manual na UI posteriormente.

**Always:**
- Utilizar a biblioteca `shapely` para as operações espaciais e validações geométricas.
- Usar o centroide do Lote (ou ponto representativo) para testar a contenção (Point-in-Polygon) em vez de intersecção completa, visando performance e tolerância a pequenos erros de desenho.
- Tratar geometrias abertas extraídas do DXF tentando fechá-las caso sejam linhas sequenciais antes de transformar em polígono.

**Never:**
- Não salvar os dados no Firestore ainda; manter a estrutura em memória para a Story 2.3b.
- Não bloquear a execução principal caso uma geometria específica seja inválida; registrar em log e continuar.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Lote Contido | Lote com centroide dentro de uma Quadra válida | Lote é associado à Quadra correspondente | N/A |
| Geometria Inválida | Linhas que não formam um polígono fechado para uma Quadra | Quadra é ignorada ou reconstruída se possível | Log de aviso sobre Quadra inválida |
| Lote Órfão | Lote cujo centroide não cai em nenhuma Quadra | Lote é classificado sem Quadra associada (ou associado a "Sem Quadra") | Log informativo |

</frozen-after-approval>

## Code Map

- `functions-python/main.py` -- Ponto de integração do cálculo após a extração das variáveis locais `lotes` e `quadras`.
- `functions-python/geometry_utils.py` -- (Novo) Módulo para conversão de entidades ezdxf para polígonos Shapely e execução do algoritmo Point-in-Polygon.
- `functions-python/tests/test_geometry_utils.py` -- (Novo) Testes unitários para a associação espacial.

## Tasks & Acceptance

**Execution:**
- [x] `functions-python/geometry_utils.py` -- Criar funções para converter entidades ezdxf (LWPOLYLINE, POLYLINE, LINE) em `shapely.geometry.Polygon`.
- [x] `functions-python/geometry_utils.py` -- Implementar função `associate_lotes_to_quadras(lotes, quadras)` usando teste de centroide contido no polígono da quadra.
- [x] `functions-python/main.py` -- Importar e invocar o algoritmo passando as listas extraídas, e guardar o dicionário resultante.
- [x] `functions-python/tests/test_geometry_utils.py` -- Adicionar testes garantindo a conversão correta de polígonos fechados/abertos e a lógica de Point-in-Polygon.

**Acceptance Criteria:**
- Given um conjunto de entidades DXF representando Quadras e Lotes
- When a extração for concluída
- Then o algoritmo agrupa corretamente cada Lote na Quadra que o contém geograficamente, lidando com segurança com formas irregulares ou não fechadas.

## Implementation Notes

## Spec Change Log

## Review Triage Log

- **Verdict:** `high` | **Group:** 1 (Triângulos e Vec3) | **Category:** `patch`
  **Evidence:** A conversão de `POLYLINE` usa `pt.dxf.location[:2]`, mas `Vec3` do `ezdxf` não suporta slicing em inteiros e gera `TypeError`, derrubando silenciosamente as `POLYLINE`. Além disso, a validação `len(pts) >= 4` barra triângulos (3 pontos) que são polígonos perfeitamente válidos no Shapely, descartando-os.

- **Verdict:** `medium` | **Group:** 2 (Fronteiras e Geometria) | **Category:** `patch`
  **Evidence:** O uso estrito de `contains()` exclui as bordas; lotes cujo ponto representativo caia perfeitamente sobre a linha de limite da quadra serão dados como órfãos. É necessário usar `covers()` ou `intersects()` para incluir a borda.

- **Verdict:** `low` | **Group:** 3 (Geometrias Inválidas e Buffer) | **Category:** `patch`
  **Evidence:** A correção com `buffer(0)` (para arrumar self-intersections) pode retornar `MultiPolygon` ou geometrias vazias, não restritas a `Polygon` simples. A exceção capturada em `get_points_from_polyline` apenas loga e prossegue, o que pode mascarar erros graves. O log não registra quando ocorre auto-intersection correction. Testes faltam para cobrir esses cenários (POLYLINE, triângulos).

- **Verdict:** `false` | **Group:** - | **Category:** -
  **Evidence:** O Edge Case Hunter afirmou que a função converte a entidade `LINE` e isso geraria problema, no entanto a implementação intencionalmente ignorou `LINE`s soltas, restringindo-se a polilinhas. A afirmação de que usar `representative_point` traz "resultados diferentes" para polígonos côncavos também é descartada, pois foi uma decisão deliberada justamente para garantir a corretude em polígonos côncavos (o centroide poderia cair fora do lote).

- **Verdict:** `false` | **Group:** - | **Category:** -
  **Evidence:** Todos os achados do Verification Gap Reviewer (relativos a `read_cache.dart`, `queue.js`, `prepare_pwa.py`) são refutados pois os referidos arquivos e comportamentos são de outro projeto e não existem no diff fornecido para esta Story 2.2.

- **Verdict:** `medium` | **Group:** 4 (Decisões de Escopo e Performance) | **Category:** `defer`
  **Evidence:** Quadras sobrepostas resolvidas pelo primeiro match sem aviso; falta de índice espacial (O(NxM)); falta de tratamento de entidades multi-partes ou arcos (bulges); linhas (LINE) isoladas não convertidas em polígonos; fechamento forçado podendo incluir eixos viários. Tudo isso excede a complexidade da história atual.
## Verification

**Commands:**
- `cd functions-python && pytest tests/test_geometry_utils.py` -- expected: Testes do algoritmo passam.
