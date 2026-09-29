---
title: 'Aprovação de importação DXF com lotes ambíguos e quadras corrigidas'
type: 'feature'
created: '2026-09-29'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: '1515c2b8393167e1fc55a0a1e7eb5af4b9ef6886'
context:
  - '_bmad-output/implementation-artifacts/spec-importacao-dxf-ponta-a-ponta.md'
  - '_bmad-output/implementation-artifacts/spec-importacao-dxf-loteamento.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** No DXF de referência `00a-LOTEAMENTO_HR_R13A-Model_SEM_COTAS.dxf`, a extração gera 145 lotes válidos e 126 ambíguos, e o fluxo não consegue alimentar a tela de quadras porque: (1) `QUADRA_REGEX` (`functions-python/heuristics.py:11`) não aceita hífen, então `Q-04` nunca é reconhecido e os lotes ficam sem quadra (medido: 0 → 244 de 271 ao corrigir o regex); (2) o extrator emite features de quadra com nomes duplicados/vazios (`Q-09`, `Q-11`, `Q-17` em dobro) e `consolidate_approved_draft` aborta com `Nome de quadra duplicado`; (3) a tela só habilita Aprovar com zero ambiguidades (`app/lib/src/features/loteamentos/presentation/loteamento_canvas_screen.dart:76`), embora os 126 ambíguos sejam majoritariamente lotes com 2+ números no mesmo polígono, cuja convenção pode ser resolvida depois.

**Approach:** Corrigir o reconhecimento de quadra, mesclar quadras duplicadas/vazias na consolidação e permitir aprovar um rascunho com lotes ambíguos: a aprovação materializa o loteamento, as quadras e os lotes (com `nome` vazio quando ainda não resolvido), deixando os nomes dos lotes para um passo posterior, sem perder a revisão.

## Boundaries & Constraints

**Always:** Manter o contrato de features (`tipo`/`nome`/`quadra`/`status`) e o canvas; IDs determinísticos e idempotência; a quadra do lote vem do nome quando houver e de contenção espacial como fallback; lote sem nome é materializado com `name` vazio (não inventar nome); preservar `updateDraftFeature` e o retry manual; aceitar exclusivamente `.dxf`.

**Never:** Não alterar a geometria extraída; não bloquear a aprovação por ambiguidade; não inventar nomes de lote/quadra; não trocar as coleções top-level nem os campos esperados pelo app; não remover a possibilidade de corrigir nomes depois.

**Decisions:** Aprovar com ambiguidades é permitido mediante uma confirmação que avisa quantos lotes seguirão sem nome; lotes sem `nome` viram documentos com `name: ''`; quadras com nome duplicado são mescladas (um `quadra_id` canônico por nome) e quadras de nome vazio não abortam.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|---------------|----------------------------|----------------|
| APROVAR_COM_AMBIGUOS | Rascunho com lotes `status:'ambiguo'` e ≥1 lote | Aprovação confirmada e consolidação cria loteamento/quadras/lotes; lotes sem nome com `name:''` | Aviso com a contagem de lotes sem nome; sem erro |
| QUADRA_HIFEN | Rótulo `Q-04` no DXF | Lote recebe `quadra:'Q-04'`; quadra `Q-04` materializada | N/A |
| QUADRA_DUPLICADA | Duas features de quadra `Q-09` | Uma única quadra `Q-09` materializada | Duplicata mesclada e registrada em log |
| QUADRA_VAZIA | Feature de quadra sem `nome` | Não aborta; lote sem quadra cai em contenção espacial ou `Geral` | N/A |
| NOMES_DEPOIS | Lote aprovado com `name:''` | Lote existe com nome vazio, editável depois sem novo upload | N/A |
| SEM_LOTE | Rascunho sem nenhum lote | Aprovação bloqueada | Mensagem ao usuário |

</frozen-after-approval>

## Code Map

- `functions-python/heuristics.py:11` -- `QUADRA_REGEX` hoje `^(Q|QUADRA)[\s\.]*[0-9A-Z]+$` (não casa `Q-04`); aceitar separador `-`. Uso em `process_lote` (`:116-127`) e `build_geojson` (`:152-177`).
- `functions-python/firestore_utils.py` -- `consolidate_approved_draft`: `_value(properties,'nome')` exige nome no lote e `properties.get('status')=='ambiguo'` levanta `ValueError`; e nome de quadra duplicado levanta `ValueError` (`quadras_by_name`). Relaxar: nome opcional, ambíguo aceito, mesclar duplicados/vazios por nome.
- `app/lib/src/features/loteamentos/presentation/loteamento_canvas_screen.dart:76-92` -- guarda `ambiguos == 0 && possuiLote`; permitir com ambiguidade após confirmação, mantendo o bloqueio sem lote.
- `app/lib/src/features/loteamentos/data/loteamentos_import_repository.dart:139-151` -- `approveDraft` já grava `consolidationRequestId` e aciona o retry manual; sem alteração de contrato.
- `functions-python/tests/test_heuristics.py`, `tests/test_firestore_utils.py`, `tests/test_consolidation_reference.py` -- atualizar: `Q-04`, duplicados, lote ambíguo/sem nome materializado, contagem de quadras.
- `functions-python/tests/test_dxf_extraction.py:47-57` -- congela `validos == ['16.00']`; atualizar para a realidade do fixture.
- `app/test/src/features/loteamentos/presentation/loteamento_canvas_screen_test.dart` -- cobrir aprovação com ambíguos (confirmação) e bloqueio sem lote.

## Tasks & Acceptance

**Execution:**
- [x] `functions-python/heuristics.py` -- `QUADRA_REGEX` aceitar `Q`/`QUADRA` + separador opcional (espaço, ponto ou hífen) + `[0-9A-Z]+` -- reconhece `Q-04` e popula `quadra` no lote.
- [x] `functions-python/firestore_utils.py` -- quadras duplicadas/vazias mescladas por nome; lote `ambiguo`/sem nome materializado com `name:''` em vez de abortar -- permite aprovar sem resolver tudo.
- [x] `app/lib/src/features/loteamentos/presentation/loteamento_canvas_screen.dart` -- habilitar Aprovar com ambiguidade após diálogo de confirmação com a contagem de lotes sem nome; manter bloqueio quando não há lote -- destrava o fluxo.
- [x] `functions-python/tests/` -- cobrir regex de quadra, merge de duplicados, lote ambíguo/sem nome e a contagem de quadras do fixture (Q-01…Q-22 reconhecidas; Q-19 não é associada — ver `deferred-work.md`).
- [x] `app/test/src/features/loteamentos/presentation/loteamento_canvas_screen_test.dart` -- cobrir aprovação confirmada com ambíguos e bloqueio sem lote.

**Acceptance Criteria:**
- Given o DXF `SEM_COTAS`, when processado, then os lotes recebem `quadra` (Q-01…Q-22 reconhecidas) e a consolidação cria as quadras sem abortar por duplicidade.
- Given um rascunho com lotes ambíguos, when o usuário confirma a aprovação, then loteamento, quadras e lotes são criados (lotes sem nome com `name:''`) e a tela de quadras é alimentada.
- Given um rascunho sem lote, when o usuário tenta aprovar, then é bloqueado.
- Given a reentrega da mesma solicitação, when o gatilho recebe, then não há documentos duplicados (idempotência preservada).

## Implementation Notes

- Medições no fixture `SEM_COTAS`: 279 features = 271 lote + 8 quadra; 145 válidos/126 ambíguos. Corrigindo só o `QUADRA_REGEX`, 244/271 lotes ganham quadra (22 quadras distintas; Q-19 não é associada — ver `deferred-work.md`); mesclando duplicados, a consolidação gera 25 quadras (Q-01…Q-22, 2 vazias e `Geral`).
- 9 quadra de nome vazio/duplicado vêm das features `tipo:'quadra'` reparadas; o restante das quadras nasce das referências por nome dos lotes.

## Spec Change Log

## Review Triage Log

- BH1 spec promete Q-01…Q-23 mas Q-19 não é associada — **low** → defer. Q-19 existe no DXF, mas o rótulo cai num polígono classificado como lote; corrigir exige mexer na classificação geométrica, vetado pelo intent ("não alterar a geometria extraída"). AC ajustada para as quadras efetivamente reconhecidas.
- BH2/ECH2 merge de quadra duplicada descarta geometria — **low** → rejeitado. Só afeta o fallback de contenção de lotes sem nome; unir polígonos é mais que correção direta.
- BH3 duas quadras de nome vazio geram documentos separados — **low** → rejeitado. Decisão de produto; a spec só exigia não abortar.
- BH4/ECH4/VG-main aprovação confirma só por "lote sem nome", e lote ambíguo com nome tentativo é materializado sem aviso — **medium** → patch. Verificado: `_approve` usa `lotesSemNome`; um lote `ambiguo` com `nome` (ex.: `ESTRADA CARROÇÁVEL`) seguiria sem confirmação e com nome inventado.
- BH5 servidor não valida mais ambiguidade; rules deixam membro alterar `status`/`features` — **false**. O intent decide explicitamente permitir aprovar com ambiguidade; a rule já restringe a membro ativo.
- BH6 `_feature_name` colapsa estados e não marca `needsReview` — **low** → rejeitado. Sem defeito demonstrado; editaria o contrato dos documentos.
- BH7 números mágicos e perda da cobertura de rejeição de dimensão — **low** → rejeitado. Qualidade de teste, sem regressão de comportamento demonstrada (a rejeição de cota é coberta em `test_heuristics`).
- BH8 fixture sem proveniência/checksum — **low** → rejeitado. Correção editaria docs/spec.
- BH9 `QUADRA_REGEX` permissivo (`Q--04`) sem teste negativo — **low** → rejeitado. Sem falha demonstrada.
- BH10 contagem de `lotesSemNome` capturada no build pode ficar defasada — **low** → rejeitado. Janela improvável (o diálogo recalcula no toque pelo estado atual do stream).
- ECH1 `nome` não-String quebraria o build do canvas — **false**. `build_geojson` sempre emite `nome` String.
- ECH3 nome numérico vira vazio em silêncio — **false**. Idem.
- ECH5/ECH6/VG-Q19 Q-19 ausente e teste fixando 22 — **low** → defer (mesma causa de BH1).

## Design Notes

O círculo `Q-xx` rotula a quadra inteira (bloco delimitado por linhas vermelhas) e os números vermelhos são os lotes; as linhas verdes subdividem os lotes. A associação geométrica já existe em `geometry_utils.associate_lotes_to_quadras`; o defeito era só a leitura textual do rótulo. Manter o lote ambíguo visível (nome vazio) evita inventar identificação e permite corrigir os dados numa etapa posterior.

## Verification

**Commands:**
- `cd functions-python && ./venv/bin/python -m pytest tests/test_heuristics.py tests/test_firestore_utils.py tests/test_consolidation_reference.py tests/test_dxf_extraction.py -q` -- expected: passam, com Q-01…Q-23 e sem aborto por duplicidade.
- `cd functions && npm run test:draft-persistence` -- expected: emulador sobe; consolidação com nomes vazios passa.
- `cd app && flutter analyze && flutter test test/src/features/loteamentos` -- expected: sem novos diagnósticos; aprovação com ambíguos confirmada.
- `firebase deploy --only functions,firestore:rules --project sigo-c2eb2` -- expected: functions e rules publicadas.

**Manual checks (if no CLI):**
- Aprovar o rascunho `SEM_COTAS` e confirmar quadras Q-01…Q-23 e lotes (nome vazio) em `quadras`/`lotes`.
