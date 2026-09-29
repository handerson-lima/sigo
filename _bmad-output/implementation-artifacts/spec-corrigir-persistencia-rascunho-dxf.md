---
title: 'Corrigir persistência do rascunho DXF no Firestore'
type: 'bugfix'
created: '2026-09-29'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: 'a401542f21071ee4b63c6c2cbb43a8e4ff1a4c08'
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Rascunhos de loteamento com geometria real não são gravados no Firestore — `doc_ref.set()` falha com `400 Property array contains an invalid nested entity` porque `feature.geometry.coordinates` é um array de arrays. O upload nunca vira rascunho aprovável (observado nos logs de `processar_dxf`).

**Approach:** Gravar cada `feature.geometry` como JSON serializado (string) no documento do rascunho, restaurando o contrato histórico que o canvas já aceitava, e fazer o canvas desserializar String ou Map. Cobrir a persistência real com teste de integração contra o emulador do Firestore.

## Boundaries & Constraints

**Always:** O documento do rascunho não pode conter arrays aninhados; manter o contrato de features (`tipo`/`nome`/`quadra`/`status`); o canvas renderiza geometry serializada (String) ou Map; preservar `updateDraftFeature`, `approveDraft` e o rascunho terminal (`status:'erro'`); serializar no ponto único de gravação.

**Never:** alterar o extrator/gatilho DXF; mudar a saída de `heuristics.build_geojson` (continua Map); quebrar o fluxo de correção/aprovação; tocar em outras coleções ou esquema.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| HAPPY_PATH | FeatureCollection de `build_geojson` com lotes/quadras reais | Doc persiste; cada `feature.geometry` é String JSON; nenhum array aninhado | N/A |
| LEGACY_MAP | Rascunho/dado com `geometry` como Map | Canvas renderiza normalmente | N/A |
| CORRECTION | `updateDraftFeature` reescreve `features` | `geometry` segue String; gravação continua válida | N/A |
| MALFORMED_GEOMETRY | `geometry` String inválida | Feature ignorada no render | Log de geometria inválida |

</frozen-after-approval>

## Code Map

- `functions-python/firestore_utils.py:9-32` -- ponto único de `doc_ref.set`; serializar `feature['geometry']` (Map → `json.dumps`) antes de gravar, de forma idempotente.
- `functions-python/heuristics.py:56-70` -- `build_geojson` continua devolvendo geometry Map; não alterar nem seus testes.
- `functions-python/tests/test_firestore_utils.py:17-22` -- hoje assere `mock_doc.set.assert_called_once_with(geojson)`; precisa refletir a serialização.
- `functions-python/tests/conftest.py:8-24` -- mocka globalmente `google`/`firebase_admin`; o teste de integração deve ficar fora de `tests/` (ex.: `tests_integration/`) ou contornar os mocks.
- `app/lib/src/features/loteamentos/presentation/widgets/geojson_canvas_widget.dart:55-67,94-101` -- dois acessos `feature['geometry'] as Map`; extrair helper que aceita String (`jsonDecode`) ou Map.
- `app/test/src/features/loteamentos/presentation/widgets/geojson_canvas_widget_test.dart` -- adicionar caso com geometry String.
- `app/lib/src/features/loteamentos/data/loteamentos_import_repository.dart:100-136` -- `updateDraftFeature` faz round-trip de `features`; não deve parsear/serializar geometry, senão reintroduz arrays aninhados.
- `functions/package.json` (scripts) e `.github/workflows/ci.yml` -- rodar o teste de integração via `firebase emulators:exec --only firestore`.

## Tasks & Acceptance

**Execution:**
- [x] `functions-python/firestore_utils.py` -- serializar `geometry` de cada feature para String antes de `set` -- elimina arrays aninhados no documento.
- [x] `functions-python/tests/test_firestore_utils.py` -- assertar geometry serializada e ausência de arrays aninhadas no payload -- trava a regressão sem emulador.
- [x] `functions-python/tests_integration/test_draft_persistence.py` -- teste real com emulador Firestore: gravar `build_geojson` e reler o documento -- prova a correção fim a fim.
- [x] `app/lib/src/features/loteamentos/presentation/widgets/geojson_canvas_widget.dart` -- helper `_geometryOf` aceitando String/Map -- renderiza o contrato serializado.
- [x] `app/test/src/features/loteamentos/presentation/widgets/geojson_canvas_widget_test.dart` -- caso com geometry String -- cobre a desserialização.
- [x] `functions/package.json` + `.github/workflows/ci.yml` -- script/job `test:draft-persistence` -- executa o teste de integração no CI.

**Acceptance Criteria:**
- Given o DXF de referência processado, when o rascunho é salvo, then o documento existe em `loteamentos_drafts` e o canvas renderiza os lotes.
- Given geometria persistida como String, when `updateDraftFeature` corrige um lote, then a correção persiste sem erro.
- Given um rascunho com geometry serializada, when o canvas carrega, then exibe os polígonos.

## Implementation Notes

## Spec Change Log

## Review Triage Log

- BH1 `properties`/`metadata` com arrays aninhados reintroduzindo 400 — **false**. `build_geojson` só emite escalares em `properties` (`tipo`/`nome`/`status`/`quadra`/`geometria_reparada`) e `_upload_metadata` só devolve `construtoraId`/`loteamentoName` + strings; nenhum caminho produz array aninhado fora de `geometry`.
- BH2 `ensure_ascii=False` divergindo do assert `json.dumps(geometry)` — **false**. A geometria real só contém `"Polygon"`/`"MultiPolygon"` e números, então `ensure_ascii` não muda a saída; o teste não pode divergir com dados reais.
- BH3/ECH3/ECH7 cast `geometry['coordinates'] as List` estoura com geometria String decodificada porém de schema inválido — **low** → patch. O caminho String é novo e a matriz MALFORMED_GEOMETRY promete ignorar/logar geometria inválida; hoje só cobre JSON sintaticamente inválido.
- BH4 falta teste do ramo "String decodifica para não-objeto" — **false**. O ramo está implementado e logado (`geojson_canvas_widget.dart:50`); verificação (`verification-gap`) não apontou lacuna e não há comportamento incorreto.
- BH5 `MultiPolygon` sem cobertura ponta a ponta — **false**. É lacuna de cobertura; `serialize_geometry` e o canvas tratam o tipo e nenhum comportamento incorreto foi demonstrado.
- BH6 teste de integração sem teardown/ID fixo — **false**. `save_draft_to_firestore` usa `set()` (sobrescreve), então não há acúmulo nem estado residual entre execuções.
- BH7 `google.auth` importado sem constar em requirements — **low** → patch. Import depende de dependência transitiva do `firebase-admin`; declarar explicitamente evita quebra futura.
- BH8 `_has_nested_array` duplicado em dois arquivos de teste — **false**. Sem prejuízo concreto; a deduplicação entre pacotes de teste com conftests distintos seria complexidade além de correção direta.
- BH9 sem guarda de que o teste aponta para o emulador — **false**. `conftest.py` garante `FIRESTORE_EMULATOR_HOST` via `setdefault` e o projeto é `demo-sigo`; `firestore.client()` sempre resolve para o emulador.
- BH10 spec com seções placeholder — rejeitado. O conserto seria editar a spec deste build; não é um defeito de código.
- BH11 job de CI sem cache de pip — **false**. Só impacto de velocidade, sem falha funcional; adicionar cache é complexidade além de correção direta.
- ECH1 `Map<String, dynamic>.from` estoura com chaves não-String — **false**. Firestore, `jsonDecode` e `build_geojson` produzem sempre mapas de chave String; cenário não alcançável.
- ECH2 `_getDrawOrder` estoura com feature não-Map — **false**. Código pré-existente e inalcançável: `build_geojson` só emite features Map.
- ECH4 geometria nem dict nem String deixada sem serializar — **false**. `build_geojson` sempre emite geometria dict (Map).
- ECH5 `features` tupla não serializada — **false**. `build_geojson` sempre emite `features` como list.
- ECH6 assert `set` chamado exatamente uma vez removido — **low** → patch. A reescrita trocou `assert_called_once_with` por inspeção de payload; chamadas `set` duplicadas deixariam de ser detectadas.

## Design Notes

`build_geojson` (Map com `coordinates` aninhadas) é o formato de entrada correto; a serialização fica só na borda de persistência (`save_draft_to_firestore`), preservando testes de heurística e o contrato do canvas. Exemplo: `{"type":"Polygon","coordinates":[[[0,0],[1,0],[1,1],[0,0]]]}` vira a string `"{\"type\": \"Polygon\", \"coordinates\": [[[0, 0], [1, 0], [1, 1], [0, 0]]]}"` antes do `set`.

## Verification

**Commands:**
- `cd functions-python && ./venv/bin/python -m pytest tests/test_firestore_utils.py tests/test_main.py tests/test_heuristics.py -q` -- expected: passam.
- `cd functions && npm run test:draft-persistence` -- expected: emulador Firestore sobe e o teste de integração passa.
- `cd app && flutter analyze && flutter test test/src/features/loteamentos -q` -- expected: sem novos diagnósticos e testes passam.
