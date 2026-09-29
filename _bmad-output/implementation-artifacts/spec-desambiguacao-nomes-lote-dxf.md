---
title: 'Desambiguação automática de nomes de lote no DXF'
type: 'feature'
created: '2026-09-29'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: 'de65b11b45889a7b41b20d7a6fc8b1cded4b6a89'
context:
  - '_bmad-output/implementation-artifacts/spec-aprovacao-dxf-com-ambiguos.md'
  - '_bmad-output/implementation-artifacts/spec-importacao-dxf-loteamento.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** No DXF `00a-LOTEAMENTO_HR_R13A-Model_SEM_COTAS.dxf` restam 126 lotes `ambiguo`: 94 têm 2+ números de lote dentro do mesmo polígono (o ponto de inserção do número vizinho cai no lote atual), 11 têm só rótulo de rua/área/`M²`, 9 têm texto sem número e 12 não têm texto. Isso obriga uma revisão manual enorme antes de aprovar.

**Approach:** Refinar a heurística de nomes em `heuristics.process_lote`: descartar tokens que não são nome de lote (`Q-xx`, `M²`, decimais isolados e palavras de rua/área/institucional) e, quando houver ≥2 inteiros cobertos pelo polígono, escolher o mais próximo do ponto representativo do polígono (mantendo `ambiguo` quando a proximidade for indefinida). Não alterar a geometria extraída.

## Boundaries & Constraints

**Always:** Manter o contrato de features (`tipo`/`nome`/`quadra`/`status`) e o canvas; manter `ambiguo` quando a escolha for incerta (nunca inventar); preservar `DIMENSION_REGEX`/`STOP_WORDS` e a associação de quadra por rótulo; manter determinismo (mesma entrada ⇒ mesmo resultado).

**Never:** Não alterar polígonos/geometria; não mexer na consolidação nem no fluxo de aprovação; não usar nome de rua/área como nome de lote; não introduzir dependência de cor ACI nesta mudança.

**Decision:** A escolha entre múltiplos inteiros usa o mais próximo do `representative_point` do polígono quando estiver estritamente mais perto do que o segundo (com margem relativa mínima de 5%); caso contrário mantém `ambiguo`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|---------------|----------------------------|----------------|
| MULTI_INTEIROS | Lote com 2+ inteiros cobertos | `status:'valido'` com o inteiro mais próximo do polígono | N/A |
| NEAR_TIE | Dois inteiros com distância praticamente igual | Mantém `status:'ambiguo'` | N/A |
| SINGLE_INTEIRO | Lote com exatamente 1 inteiro | `status:'valido'` (comportamento atual) | N/A |
| NONLOT_TOKEN | `Q-04`, `152,00M²`, `16.00`, `RUA ...`, `ÁREA VERDE` | Não vira nome de lote | N/A |
| ZERO_TEXTO | Lote sem texto coberto | Mantém `status:'ambiguo'`, `nome:''` | N/A |

</frozen-after-approval>

## Code Map

- `functions-python/heuristics.py:7-11` -- `STOP_WORDS`/`DIMENSION_REGEX`; adicionar filtro de área (`M²`/`M2`) e de termos de rua/área/institucional, e rejeitar `Q-xx` e decimais isolados como nome.
- `functions-python/heuristics.py:91-127` -- `process_lote`: coleta candidatos por `poly.covers(pt)`; implementar a escolha por proximidade ao `representative_point` e a margem de 5%.
- `functions-python/tests/test_dxf_extraction.py:47-71` -- `validos == 145` e `len(quadras) == 22`; atualizar os números do fixture `SEM_COTAS` após a desambiguação.
- `functions-python/tests/test_heuristics.py` -- cobrir multi-inteiros, empate, tokens não-lote e inteiro único.
- `functions-python/tests/test_consolidation_reference.py` -- segue aprovando o fixture; ajustar se a contagem de ambíguos mudar.
- `app/` -- sem mudança (consumo do contrato permanece).

## Tasks & Acceptance

**Execution:**
- [x] `functions-python/heuristics.py` -- adicionar `AREA_REGEX`/rejeição de `Q-xx`/decimais e lista de termos não-lote ao filtro de candidatos em `process_lote` -- tira rua/área/dimensão da disputa por nome.
- [x] `functions-python/heuristics.py` -- escolher o inteiro mais próximo do `representative_point` quando houver 2+ inteiros, com margem relativa de 5%; senão manter `ambiguo` -- resolve os 94 casos medidos sem inventar nome.
- [x] `functions-python/tests/test_heuristics.py` -- cobrir MULTI_INTEIROS, NEAR_TIE, SINGLE_INTEIRO e NONLOT_TOKEN -- travas da regra.
- [x] `functions-python/tests/test_dxf_extraction.py` e `tests/test_consolidation_reference.py` -- atualizar contagens do fixture e garantir que o número de `valido` suba e o de `ambiguo` caia -- mede o efeito real.

**Acceptance Criteria:**
- Given o DXF `SEM_COTAS`, when processado, then o número de lotes `valido` sobe de 145 para ≥ 230 e `ambiguo` cai de 126 para ≤ 35.
- Given um lote com 2 inteiros e proximidade indefinida, when processado, then permanece `ambiguo`.
- Given rótulos `Q-04`/`M²`/`RUA`, when dentro de um lote, then não viram nome do lote.
- Given a mesma entrada, when processada duas vezes, then o resultado é idêntico.

## Implementation Notes

- Medição no fixture: 94 de 126 ambíguos têm ≥2 inteiros e **todos os 94** têm um inteiro estritamente mais próximo do `representative_point`; 23 ambíguos têm `Q-xx` e 36 têm rua/área entre candidatos. O teto esperado é ~12–32 ambíguos (os sem texto/rótulo de área).
- `ESTRADA CARROÇÁVEL` é hoje o único lote `ambiguo` com nome; com o filtro de termos de rua ele passa a `nome:''`.

## Spec Change Log

## Review Triage Log

- BH1/ECH2/ECH3 candidato único não-inteiro vira `nome` válido (ex.: `GALERIA`, `16.`, `LOTE 12`) — **medium** → patch. Contraria "nunca inventar"; aceitar como nome só inteiro.
- BH2 rótulos multi-palavra com `LOTE`/`QUADRA`/`CASA` não são filtrados — **medium** → patch (mesma raiz de BH1; coberto por aceitar só inteiro).
- BH3 números com pontuação (`12.`) falham `INTEGER_REGEX` — **medium** → patch. Normalizar pontuação antes de casar o inteiro.
- BH4 `STOP_WORDS`/`NON_LOTE_TERMS` sobrepostos e divergentes — **low** → rejeitado. Manutenção; sem defeito demonstrado.
- BH5 lote órfão força `ambiguo` mas mantém `nome` — **medium** → patch. Violaria o invariante `ambiguo ⇒ nome:''`.
- BH6 `representative_point` em polígono inválido — **maybe-false** → defer. Fixture emite geometria inválida; settle: medir com polígono inválido se o ponto cai fora.
- BH7/ECH1/VG-other dedup guarda o 1º ponto — **low** → rejeitado. Fixture não tem valores duplicados por polígono; conserto não trivial.
- BH8/VG-main margem de 5% não é fixada por teste — **medium** → patch. Testes de fronteira (~2,9% ⇒ ambíguo; ~10% ⇒ válido).
- BH9 cobertura multi-lote regrediu — **low** → patch (readicionar associação com 2 lotes).
- BH10 linhas/faltas de teste (inteiro + rótulo LOTE, órfão com texto, pontuação) — **low** → patch (incluídas no mesmo passo).
- BH11 `AREA_REGEX` casa `M20`/`M2A` por substring — **low** → patch. Ancorar a área (dígitos + unidade).
- BH12 `_contains_word` e `×`/maiúsculas — **false**. `extract_text` já uppercasa e `×` é separador na classe.
- BH13 AC `≥230` vs teste `==245` inconsistentes — **low** → rejeitado. Assert exato é mais forte que o AC.
- BH14 teste de integração sem comentário e perde o caminho de nome vazio — **low** → rejeitado. Sem defeito de comportamento.
- BH15 escolha do número certo não é assertada — **false**. `test_build_geojson_multi_inteiros_escolhe_o_mais_proximo` assere o nome escolhido.
- BH16 drift textual da spec — rejeitado. Correção editaria a spec.
- BH17 teste de determinismo fraco — **low** → rejeitado.

## Design Notes

A proximidade usa o `representative_point` (garantidamente dentro do polígono) e a distância euclidiana do ponto de inserção do texto. A margem de 5% evita escolher o vizinho quando os números estão a distâncias quase iguais (fronteira compartilhada), preservando `ambiguo` para revisão humana.

## Verification

**Commands:**
- `cd functions-python && ./venv/bin/python -m pytest tests/test_heuristics.py tests/test_firestore_utils.py tests/test_consolidation_reference.py tests/test_dxf_extraction.py -q` -- expected: passam; `valido ≥ 230`.
- `cd functions && npm run test:draft-persistence` -- expected: emulador sobe; persistência/consolidação passam.
- `cd app && flutter analyze && flutter test test/src/features/loteamentos` -- expected: sem novos diagnósticos (contrato inalterado).
- `firebase deploy --only functions --project sigo-c2eb2` -- expected: `processar_dxf` publica a nova heurística.

**Manual checks (if no CLI):**
- Rodar `extract_dxf_geojson` no fixture e conferir `Counter(status)` (válido/ambíguo) e nomes numéricos.
