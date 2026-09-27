---
title: '2.2 — Preservar e revisar quadras reparadas'
type: 'bugfix'
created: '2026-09-27'
status: 'in-progress'
baseline_commit: 'ba6970ca48cf7065deab60359d76dc151aff092a'
route: 'dispatch'
review_loop_iteration: 0
context: ['_bmad-output/implementation-artifacts/epic-2-context.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O reparo geométrico descarta componentes menores de quadras, tornando lotes legítimos órfãos. O rascunho não mostra a quadra reparada para conferência.

**Approach:** Preservar todos os componentes recuperados sob uma única quadra, testar associação contra a geometria completa, transportar as partes no GeoJSON e permitir conferência explícita no canvas. Recomendação aprovada pelo usuário em 2026-09-27: preservar todas as partes, marcar quadra reparada como pendente, rejeitar apenas resultado vazio/inválido e adequar consumidores.

## Boundaries & Constraints

**Always:** Manter Polygon/MultiPolygon válidos completos, incluindo anéis internos. Toda quadra reparada exige confirmação humana, mesmo quando resulta em Polygon único. Uma só identidade por quadra; não gerar quadras independentes por componente. Pendência usa `status: ambiguo` e impede aprovação pela UI até confirmação. Desenho e seleção devem alcançar cada componente e respeitar furos. Fornecer acesso à revisão mesmo se lotes cobrirem toda a quadra. Confirmar geometria não depende de renomear e não resolve lotes ambíguos. Geometrias não recuperáveis são registradas em log; continuar com as demais.

**Never:** Não fazer deploy, migrar dados nem executar operações remotas. Não corrigir os achados independentes OCS/WCS e desempate entre quadras nesta entrega. Preservar alterações locais prévias e histórico da revisão. Não transformar a confirmação em editor de geometria.

## I/O & Edge-Case Matrix

| Cenário | Entrada | Resultado | Erro |
|---|---|---|---|
| Duas partes | Quadra reparada com áreas 16 e 1, lote em cada parte | Ambos associados à mesma quadra; GeoJSON conserva área 17, ambas as partes, pendência própria | Nenhum |
| Reparo simples | Geometria inválida recuperada como Polygon | Preservar e exigir conferência | Nenhum |
| Reparo vazio | Entidade degenerada junto a entidades válidas | Ignorar quadra com aviso e continuar; lote sem quadra continua órfão | Log |
| Canvas | MultiPolygon com furo e espaço entre componentes | Cada parte visível/selecionável sob mesmo índice; furo e intervalo não selecionam | Nenhum |
| Revisão | Quadra reparada e lote ambíguo | Aprovação bloqueada; confirmação só resolve quadra, preserva geometria e lote pendente | Falha de gravação mantém pendência |
| Compatibilidade | Rascunho antigo contendo só lotes | Correção de lote e renderização continuam funcionando | Nenhum |

</frozen-after-approval>

## Code Map

- `functions-python/geometry_utils.py`: conversão, reparo `buffer(0)`, associação, mapas de polígonos; carregar também informação de quais quadras foram reparadas sem reprocessar cada geometria.
- `functions-python/heuristics.py`: atualmente emite só lotes e usa `.exterior`; serializar Polygon/MultiPolygon e incluir uma feature para cada quadra reparada, mantendo rascunhos não reparados compatíveis. Reusar resolução textual existente.
- `functions-python/main.py`: pipeline já entrega mapas à heurística; verificar contrato integrado com DXF real.
- `app/lib/src/features/loteamentos/presentation/widgets/geojson_canvas_widget.dart`: já suporta MultiPolygon; usar preenchimento que preserve furos, quadras atrás de lotes, mantendo índices reais.
- `app/lib/src/features/loteamentos/presentation/loteamento_canvas_screen.dart`: contagem/aprovação, seleção e gravação; distinguir pendências de quadras, oferecer acesso explícito às reparadas sobrepostas por lotes.
- `app/lib/src/features/loteamentos/presentation/widgets/lote_correcao_panel.dart`: manter edição de lotes; para quadra reparada mostrar aviso e confirmação explícita da geometria, sem exigir renomeação.
- `app/lib/src/features/loteamentos/data/loteamentos_import_repository.dart`: transação já mescla propriedades e preserva geometria; reusar sem alterar infraestrutura.

## Tasks & Acceptance

**Execution:**
- [ ] `functions-python/tests/test_geometry_utils.py`, `test_heuristics.py`, `test_main.py` — regressões reais para matriz; executar antes e depois da correção.
- [ ] `functions-python/geometry_utils.py`, `heuristics.py` — preservar geometria e sinalizar reparo de quadras até GeoJSON; adaptar lote multipartido ao serializador compartilhado sem criar fluxo independente.
- [ ] `app/lib/src/features/loteamentos/presentation/` — conferir partes/furos, pendências e confirmação da quadra com gravação das propriedades somente.
- [ ] `app/test/src/features/loteamentos/` — testar seleção nas partes/furos, bloqueio, confirmação, erro de gravação e compatibilidade com lotes.

**Acceptance Criteria:**
- Given DXF com quadra recuperável multipartida, when processado até GeoJSON, then nenhum componente recuperado desaparece, lotes de ambas as partes mantêm a associação e a quadra fica pendente.
- Given rascunho com quadra reparada, when usuário confere e confirma, then todas as partes continuam intactas e só a pendência dessa quadra é resolvida.

## Implementation Notes

Autorização existente cobre esta decisão e seus ajustes necessários; nenhum novo ato irreversível. Árvore já contém documentação da revisão e reconciliação do sprint: preservar. Achados independentes da revisão original continuam pendentes. Acessibilidade mínima: ação de revisão com texto compreensível; sem redesenho amplo.

## Spec Change Log

## Review Triage Log

## Verification

- `functions-python/.venv/bin/python -m pytest -q -p no:cacheprovider functions-python/tests` — suíte Python completa.
- Em `app`: `flutter test test/src/features/loteamentos` e `flutter analyze` — testes do domínio e análise estática; usar SDK local disponível, sem downloads desnecessários.
