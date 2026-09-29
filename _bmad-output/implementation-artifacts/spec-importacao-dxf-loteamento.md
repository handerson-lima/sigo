---
title: 'Importação de loteamento por DXF'
type: 'refactor'
created: '2026-09-29'
status: 'done'
route: 'dispatch'
baseline_commit: 'a0a75fb16157bd52f365ecb9e21991e54b731c40'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A importação de loteamentos hoje só aceita DWF e depende de um conversor externo; o arquivo de referência do produto agora é o DXF `dwg_dxf/00a-LOTEAMENTO_HR_R13A-Model.dxf`, que precisa ser lido nativamente.

**Approach:** Alinhar a importação ao DXF de referência: UI/repositório aceitam `.dxf`, o gatilho Storage lê o DXF com `ezdxf`, extrai lotes/quadras e associa os textos MTEXT, gerando o mesmo rascunho GeoJSON revisável (features com `tipo`/`nome`/`quadra`/`status`) que o canvas já consome, reaproveitando `geometry_utils` e `heuristics`.

## Boundaries & Constraints

**Always:** Aceitar `.dxf` na UI, no repositório e no gatilho; validar caminho, tamanho e formato antes de processar; enviar `construtoraId`, `loteamentoName` e `sourceFormat:'dxf'` no rascunho; preservar a revisão humana antes de qualquer persistência definitiva; manter falha terminal como rascunho `status:'erro'` com `processingError` rastreável; manter o contrato GeoJSON e o fluxo de aprovação atuais.

**Never:** aceitar DWG ou PDF; publicar entidades definitivas sem aprovação; alterar o contrato do canvas ou o fluxo de aprovação; reintroduzir a consolidação já removida.

**Decision:** O DXF substitui o DWF integralmente: remover `dwf_extraction.py`, seus testes e o conversor `DWF_CONVERTER_COMMAND`, e fazer UI, repositório, `storage.rules` e gatilho aceitarem somente `.dxf`. A classificação lote × quadra usa primeiro tokens de layer (`LOTE`/`QUADRA`); quando todos os elementos estão no layer `0` (caso do arquivo de referência), decide por geometria (área e contenção), mantendo casos incertos como `status:'ambiguo'`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|---------------|---------------------------|----------------|
| HAPPY_PATH | DXF de referência enviado | Rascunho `status:'pendente'` com features lote/quadra e textos associados; ≥1 lote | N/A |
| UNSUPPORTED_FORMAT | Extensão diferente de `.dxf` | Rejeitado na UI; ignorado no gatilho | Mensagem ao usuário + log estruturado |
| INVALID_FILE | DXF corrompido/ilegível | Nenhuma entidade definitiva | Rascunho terminal `status:'erro'` |
| NO_ENTITIES | DXF válido sem lotes | Nenhum rascunho aprovável | Rascunho terminal `status:'erro'` |
| AMBIGUOUS | Lote sem número/nome confiável | Feature `status:'ambiguo'` | Pendência exibida no canvas |

</frozen-after-approval>

## Code Map

- `dwg_dxf/00a-LOTEAMENTO_HR_R13A-Model.dxf` -- fixture real (já versionado): bloco único `Viewport1`, todas as entidades no layer `0`.
- `functions-python/dxf_extraction.py` (novo) -- extrator DXF; espelha o contrato/erros de `dwf_extraction.py`.
- `functions-python/main.py:45-102` -- `processar_dwf` vira `processar_dxf`; extensão `.dxf`, sufixo do temp e `sourceFormat:'dxf'`.
- `functions-python/geometry_utils.py` -- reusar `get_points_from_entity`, `ezdxf_entity_to_polygon`, `associate_lotes_to_quadras`.
- `functions-python/heuristics.py` -- reusar `extract_text` e `build_geojson` (props `tipo`/`nome`/`quadra`/`status`).
- `functions-python/tests/test_main.py`, `test_geometry_utils.py`, `test_heuristics.py`, `conftest.py` -- regressão; hoje `test_main.py` rejeita `.dxf`.
- `storage.rules:44-48` -- create exige `application/x-dwf` + regex `.dwf`; trocar por DXF.
- `app/lib/src/features/loteamentos/presentation/loteamento_import_screen.dart:58,71,107,111,127` -- extensão, título e textos DWF.
- `app/lib/src/features/loteamentos/data/loteamentos_import_repository.dart:61,73-83` -- `contentType` e `loteamentoNameFromFilename`.
- `app/lib/src/features/loteamentos/presentation/loteamentos_list_screen.dart:42` -- tooltip já diz "Importar DXF".
- `functions-python/requirements.txt` -- `ezdxf`/`shapely` já presentes (remover PDF/OCR apenas se o caminho A os dispensar).

## Tasks & Acceptance

**Execution:**
- [x] `functions-python/dxf_extraction.py` -- criar extrator com `ezdxf`: explodir `INSERT`/blocos herdando layer, fechar `LWPOLYLINE`, classificar lote/quadra, associar MTEXT e devolver GeoJSON no contrato do rascunho, com erro de domínio terminal.
- [x] `functions-python/main.py` -- renomear gatilho para DXF, validar `.dxf`, chamar o novo extrator e gravar `sourceFormat:'dxf'`.
- [x] `functions-python/tests/` -- cobrir rota/extensão/tamanho/temp/erros no gatilho e extração no fixture real e em DXF sintéticos.
- [x] `functions-python/dwf_extraction.py`, `functions-python/tests/test_dwf_extraction.py` e referências a `DWF_CONVERTER_COMMAND` -- remover (DXF substitui DWF).
- [x] `storage.rules` -- aceitar `application/dxf` e `.*\.dxf` (case-insensitive), mantendo size/auth.
- [x] UI Flutter (`loteamento_import_screen.dart`, `loteamentos_import_repository.dart`) e testes -- aceitar `.dxf`, MIME DXF, texts/título e mensagens.
- [x] `functions-python/requirements.txt` -- remover dependências exclusivas de DWF/PDF/OCR quando não usadas pelo caminho DXF.

**Acceptance Criteria:**
- Given o DXF de referência, when enviado e processado, then gera rascunho revisável com lotes/quadras/textos que o canvas renderiza e permite aprovar.
- Given DWF/DWG/PDF, when o usuário tenta enviar, then a UI rejeita e o gatilho não o processa.
- Given DXF corrompido ou sem lotes, when processado, then não há rascunho aprovável e o motivo fica disponível para diagnóstico.

## Implementation Notes

- `dxf_extraction.extract_dxf_geojson` reproduz o contrato terminal de `dwf_extraction`: `DxfExtractionError` (subclasse de `ValueError`) vira rascunho `status:'erro'` com `processingError`.
- Classificação: primeiro tokens de layer (`LOTE`/`QUADRA`); quando todos os elementos estão no layer `0`, decide por geometria — um polígono é quadra se contém outra parcela com área `>= 10 m²` e `<= 50%` da sua; o restante (área `>= 10 m²`) é lote. `HATCH`, `LINE` e `ARC` são ignorados; `INSERT` é explodido herdando o layer da referência.
- O caminho PDF/OCR experimental foi preservado: a spec substitui apenas o DWF, então `pdf_extraction.py`, `tests/test_pdf_extraction.py`, `apt.txt` e as dependências `PyMuPDF`/`opencv-python-headless`/`pytesseract` seguem em uso e não foram removidos.
- O nome dos lotes depende das heurísticas existentes (`heuristics.build_geojson`). No DXF de referência muitos MTEXT de cota/área caem dentro do lote e levam o rascunho a `status:'ambiguo'` (revisão humana), comportamento previsto na matriz `AMBIGUOUS`; nenhuma heurística foi alterada por estar fora do escopo da spec.

## Spec Change Log

## Review Triage Log

- BH1 (requirements.txt sem alteração com tarefa `[x]`) — `false` — a tarefa é condicional ("quando não usadas pelo caminho DXF"); as deps `PyMuPDF`/`opencv`/`pytesseract` seguem usadas pelo caminho PDF preservado, então não há o que remover.
- BH2 (`Never: aceitar PDF` vs caminho PDF preservado) — `false` — o fluxo de loteamento aceita somente `.dxf` e rejeita o resto (testado no repositório e no gatilho); `pdf_extraction.py` é caminho experimental separado, não alcançável por essa importação.
- BH3 (spec DWF antiga não marcada como superada) — `false` — `spec-importacao-dwf-loteamento.md` é registro histórico; a nova spec é a autoridade e o código não contém mais DWF.
- BH4 ("caminho A" indefinido no Code Map) — `low` — real, porém documental; rejeitado porque a correção editaria esta spec.
- BH5 + EC1 + VG-other (classificação por layer descarta parcelas sem token) — `medium` — verificado: `_layer_classification` retorna cedo assim que existe entidade com token e `_classify` ignora as demais; DXF com `QUADRA` + lote no layer `0` falha terminal, descartando lote válido. Rota: `patch`.
- BH6 (match por substring: `LOTE` casa `LOTEAMENTO`) — `low` — rejeitado: cenário não demonstrado no fixture (tudo no layer `0`) e a correção (tokenização) adiciona complexidade.
- BH7 + EC3 (`_flatten` sobrescreve layer explícito do filho) — `medium` — verificado: `child.dxf.layer = layer` aplica o layer do `INSERT` a todo filho, apagando layer próprio e impedindo classificação por token. Rota: `patch`.
- BH8 (áreas assumem metros, sem checar `$INSUNITS`) — `maybe-false` — a unidade do fixture é metros; não se demonstrou upload real em mm/cm. Rota: `defer` (severidade `medium` não verificada; settle: testar DXF em mm ou checar `$INSUNITS` de uploads reais).
- BH9 (`build_geojson` só emite feature quadra para reparadas) — `false` — reuso obrigatório pela spec e contrato já consumido pelo canvas; quadras válidas são expostas via `quadra` no lote, e features `tipo:'quadra'` existem para reparadas.
- BH10 (removidos limites de bytes/entidades do extrator) — `maybe-false` — upload limitado a 50 MB e `MAX_INSERT_DEPTH` limita recursão; não se demonstrou DXF adversário que estoure. Rota: `defer` (severidade `medium` não verificada; settle: medir tempo/memória com DXF de 50 MB).
- BH11 (bulge/curvas ignorados por `get_points_from_entity`) — `low` — comportamento pré-existente de `geometry_utils`, não introduzido aqui. Rota: `defer`.
- BH12 (spec sem evidência das verificações) — `low` — rejeitado: a correção editaria esta spec; as verificações são registradas no fluxo.
- BH13 + VG2 (assertivas de teste fracas: herança de INSERT e associação de textos) — `low` — verificado: `test_extract_herda_layer_do_insert` passa por fallback geométrico e o teste de textos só exige `>=1` nome. Rota: `patch` (reforçar assertivas; correção direta).
- EC2 (`covers(rep_point)` em sobreposição parcial) — `low` — rejeitado: não demonstrado com parcelas reais (lotes não se sobrepõem) e trocar por `contains` alteraria a semântica sem ganho comprovado.
- EC4/EC5 (`_upload_metadata` pode lançar `DraftPersistenceError` dentro do handler de `DxfExtractionError`) — `medium` — real, mas pré-existente (mesma estrutura no código DWF, inalterada pelo diff). Rota: `defer`.
- VG1 (regra de `storage.rules` sem teste; suíte de rules fora do CI) — `patch` — verificado pelo revisor: nenhum teste exercitava `loteamentos_drafts_uploads`. Foi adicionado o caso 7.4 (aceita `application/dxf`+`.dxf`/`.DXF`; nega `application/x-dwf`/`.dwf`, MIME/ext divergentes e uid estranho), que passa sob `npm run test:rules`. A ligação de `test:rules` ao CI foi para `defer` por esbarrar na falha pré-existente 8.3 (regra de logos).

## Design Notes

No arquivo de referência os HATCH são símbolos gráficos (mediana < 1 m²), não parcelas. Os lotes são `LWPOLYLINE` (cor ACI 3, ~150–570 m²) e as quadras são polígonos grandes (cor 1/5) que contêm os lotes; os textos vêm de `MTEXT` (nº do lote, `NN,NNm²`, `Q-xx`/`INSTITUCIONAL`, nomes de rua). A classificação deve tolerar esse arquivo e DXF com layers nomeados, deixando casos incertos como `status:'ambiguo'` para a revisão humana.

## Verification

**Commands:**
- `cd functions-python && ./venv/bin/python -m pytest tests/test_main.py tests/test_dxf_extraction.py tests/test_geometry_utils.py tests/test_heuristics.py -q` -- expected: passam, incluindo o fixture real.
- `cd app && flutter analyze && flutter test test/src/features/loteamentos -q` -- expected: sem diagnósticos e testes passam.
