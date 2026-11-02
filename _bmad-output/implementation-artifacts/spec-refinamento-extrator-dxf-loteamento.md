---
title: 'Refinamento do extrator DXF de loteamentos para variações de engenharia civil'
type: 'feature'
created: '2026-11-02'
status: 'in-progress'
route: 'dispatch'
baseline_commit: '46391526b0512086701fae39a4bb1afd938773bd'
review_loop_iteration: 0
context:
  - '_bmad-output/implementation-artifacts/spec-importacao-dxf-loteamento.md'
  - '_bmad-output/implementation-artifacts/spec-aprovacao-dxf-com-ambiguos.md'
  - '_bmad-output/implementation-artifacts/spec-desambiguacao-nomes-lote-dxf.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O extrator DXF (`dxf_extraction.py`, `geometry_utils.py`, `heuristics.py`) perde a quadra `Q-19` no fixture de referência (`22/23` quadras reconhecidas), classifica 8 polígonos não-lote (cores ACI 1/6/18/252 e molduras de rótulo `Q-xx`) como lotes ambíguos, ignora atributos de bloco (`ATTRIB`) e prefixos de lote (`LOTE 12`, `LT 12`, `L-12`), e assume metros fixos sem checar `$INSUNITS`.

**Approach:** Descartar molduras de rótulo `Q-xx` e filtrar pela cor ACI predominante na classificação geométrica quando tudo está no layer `0`; aplicar fallback de proximidade (`<= 8 m`) para rótulo de quadra adjacente quando a quadra com lotes não cobre nenhum `Q-xx`; extrair `ATTRIB` de `INSERT`; normalizar prefixos de lote (`LOTE`/`LT`/`L`) para o inteiro em `heuristics.py`; e escalar `MIN_LOTE_AREA` conforme `$INSUNITS`.

## Boundaries & Constraints

**Always:** Manter 100% de compatibilidade com o contrato GeoJSON (`tipo`/`nome`/`quadra`/`status`) e com `consolidate_approved_draft` em `firestore_utils.py`; preservar a precedência de inteiro puro sobre rótulo composto no mesmo lote (`13` vence `LOTE 12`); manter `MIN_LOTE_AREA = 10.0 m²` como padrão quando `$INSUNITS` for `0` (sem unidade), `6` (metros) ou desconhecido; resolver herança de cor ACI (`0`/BYBLOCK segue o `INSERT`, `256`/BYLAYER segue a tabela `layers`).

**Never:** Não alterar `firestore_utils.py`, `main.py` ou o app Flutter; não inventar nomes para lotes sem número ou órfãos; não permitir que fallback de proximidade de quadra sobrescreva uma quadra que já possui `Q-xx` coberto ou atribua rótulo a quadra sem lotes.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|---------------|----------------------------|----------------|
| QUADRA_Q19_E_MOLDURA | Polígono pequeno/adjacente só com rótulo `Q-xx` + quadra vizinha com lotes sem `Q-xx` interno | Moldura não vira `lote`; quadra vizinha com lotes a `<= 8 m` recebe `Q-19` (`23` quadras no fixture) | Se `0` ou `>= 2` rótulos no raio, mantém `quadra: ''` |
| PREFIXO_LOTE | Texto único `LOTE 12`, `LT 12`, `LT. 12`, `L-12` ou `LOTE 07` no lote | `status: 'valido'`, `nome` normalizado para o número (`'12'`, `'07'`) | Se competir com inteiro puro (`13` + `LOTE 12`), o inteiro puro vence (`'13'`) |
| INSERT_ATTRIB | Bloco `INSERT` com `ATTRIB` (`NUM_LOTE = '12'` ou `'LOTE 12'`) sem `BURST` | `_flatten` emite `ATTRIB` e `extract_text` extrai texto e ponto de inserção | `ATTRIB` vazio ou sem ponto é ignorado |
| INSUNITS_ESCALA | DXF em milímetros (`$INSUNITS = 4`) ou centímetros (`$INSUNITS = 5`) | `MIN_LOTE_AREA` escalado para a unidade do desenho (`10 * 10⁶ mm²`, `10 * 10⁴ cm²`), descartando símbolos `< 10 m²` | `$INSUNITS` ausente/`0`/inválido usa `1.0` (metros) |
| COR_ACI_PREDOMINANTE | Layer `0` com lotes em cor ACI 3 e áreas verdes/institucionais em ACI 1/6/18/252 | Polígonos sem candidato a nome de lote e fora da cor ACI predominante dos lotes válidos são descartados | Se todas as parcelas tiverem a mesma cor (ex.: `256` default), mantém todas |

</frozen-after-approval>

## Code Map

- `functions-python/dxf_extraction.py` -- extração, explosão de blocos e classificação lote × quadra:
  - `TEXT_TYPES` (`:22`): incluir `'ATTRIB'`.
  - `_flatten` (`:49-66`): ao explodir `INSERT`, iterar também sobre `getattr(entity, 'attribs', ())` emitindo cada `ATTRIB` com layer/cor efetivos.
  - `_effective_color(entity, inherited_color, doc)` (novo): resolve ACI (`0` → `inherited_color`; `256`/ausente → cor do layer em `doc.layers`; demais `1..255` diretos).
  - `_unit_area_scale(doc)` (novo): lê `doc.header.get('$INSUNITS', 0)` e usa `ezdxf.units.conversion_factor(code, ezdxf.units.M)` para retornar `(1.0 / factor) ** 2` (quantas unidades² equivalem a `1 m²`), com fallback `1.0`.
  - `_geometry_classification` / `_classify` (`:79-126`): receber `min_lote_area` escalado e `text_entities`; descartar de `lotes` polígonos que cobrem `QUADRA_REGEX` sem cobrir candidato a nome de lote, e descartar polígonos sem candidato a nome de lote cuja cor ACI efetiva divirja da cor ACI predominante dos lotes com candidato (quando houver cor predominante `>= 50%`).
- `functions-python/heuristics.py` -- heurística de nomes de lote e associação de quadra:
  - `LOTE_PREFIX_REGEX` (novo): `re.compile(r'^(?:LOTE|LT\.?|L)[\s.\-:º°]*(\d+)$')`.
  - `_is_lote_name_candidate` (`:33-51`): aceitar strings que casam `LOTE_PREFIX_REGEX`.
  - `_select_nome` (`:54-83`): separar candidatos em `inteiros_puros` (`INTEGER_REGEX`) e `inteiros_prefixados` (`LOTE_PREFIX_REGEX`); usar `inteiros_puros` se não vazio, senão `inteiros_prefixados`, aplicando a mesma regra de candidato único ou mais próximo com `MARGEM_PROXIMIDADE = 0.05`.
  - `extract_text` (`:85-117`): tratar `dxftype == 'ATTRIB'` igual a `'TEXT'` (`entity.dxf.text`, `align_point` ou `insert`).
  - `build_geojson` (`:175-187`): quando `q_candidates` por `quadra_poly.covers(pt)` for vazio e a quadra possuir lotes associados (`association['quadras'].get(q_entity)`), buscar `QUADRA_REGEX` dentro de `QUADRA_LABEL_MAX_DISTANCE = 8.0` (escalado pela unidade linear quando informada, padrão `8.0`); se exatamente 1 rótulo casar, atribuir a `quadra_nome`.
- `functions-python/geometry_utils.py` -- conversão de polilinhas e associação espacial lote → quadra (preservar contrato de `ezdxf_entity_to_polygon` e `associate_lotes_to_quadras`).
- `functions-python/tests/test_dxf_extraction.py` -- atualizar contagens do fixture `SEM_COTAS` (`len(quadras) == 23` incluindo `'Q-19'`, `len(ambiguos) == 18`, `len(validos) == 245`) e adicionar testes para moldura `Q-xx`, `ATTRIB` em `INSERT`, `$INSUNITS` em mm e filtro por cor ACI.
- `functions-python/tests/test_heuristics.py` -- adicionar testes para prefixos (`LOTE 12`, `LT 12`, `LT. 12`, `L-12`), precedência de inteiro puro sobre `LOTE 12`, `extract_text` com `ATTRIB` e fallback de distância de quadra.

## Tasks & Acceptance

**Execution:**
- [x] `functions-python/heuristics.py` -- suportar `ATTRIB` em `extract_text`, reconhecer e normalizar prefixos de lote (`LOTE_PREFIX_REGEX`) em `_is_lote_name_candidate`/`_select_nome` (mantendo prioridade para inteiros puros) e aplicar fallback de proximidade (`<= 8.0`) para rótulo de quadra em `build_geojson` quando a quadra com lotes não cobrir nenhum `Q-xx` -- permite ler atributos de bloco, textos `LOTE 12`/`LT 12`/`L-12` e associar `Q-19`.
- [x] `functions-python/dxf_extraction.py` -- incluir `'ATTRIB'` em `TEXT_TYPES` e em `_flatten`, calcular escala de área por `$INSUNITS`, resolver cor ACI efetiva e refinar `_geometry_classification` para descartar molduras `Q-xx` e polígonos sem candidato a nome fora da cor ACI predominante dos lotes -- evita falsos lotes em mm, molduras de quadra e polígonos de área institucional/verde em cor distinta.
- [x] `functions-python/tests/test_heuristics.py` -- cobrir `extract_text` com `ATTRIB`, candidatos `LOTE 12`/`LT 12`/`LT. 12`/`L-12`, precedência de inteiro puro sobre prefixado e fallback de proximidade de `Q-xx` -- garante os cenários da matriz de heurística.
- [x] `functions-python/tests/test_dxf_extraction.py` -- atualizar asserções do fixture `SEM_COTAS` para 23 quadras (`Q-01` a `Q-23`, incluindo `Q-19`) e `<= 18` ambíguos, e adicionar testes unitários para moldura de rótulo `Q-xx`, bloco `INSERT` com `ATTRIB`, `$INSUNITS` em milímetros e filtro por cor ACI -- valida todos os requisitos no fixture real e em DXFs sintéticos.

**Acceptance Criteria:**
- Given o fixture `00a-LOTEAMENTO_HR_R13A-Model_SEM_COTAS.dxf`, when processado por `extract_dxf_geojson`, then todas as 23 quadras (`Q-01` a `Q-23`, incluindo `Q-19`) são reconhecidas nos lotes, `validos == 245` e `ambiguos` cai de 26 para 18.
- Given o fixture `SEM_COTAS` aprovado, when consolidado por `consolidate_approved_draft`, then materializa loteamento, quadras (incluindo `Q-19`) e lotes sem erro e sem quebrar o contrato de `loteamentos_drafts`.
- Given um DXF com polígonos pequenos de anotação em torno de `Q-xx`, blocos `INSERT` com `ATTRIB`, textos `LOTE 12`/`LT 12`/`L-12` ou `$INSUNITS` em milímetros, when extraído, then classifica e nomeia os lotes corretamente descartando símbolos fora de escala.

## Implementation Notes

- `functions-python/heuristics.py`: adicionado `LOTE_PREFIX_REGEX` e `QUADRA_LABEL_MAX_DISTANCE = 8.0`. `_is_lote_name_candidate` e `_select_nome` aceitam e normalizam rótulos com prefixo (`LOTE`/`LT`/`L`), preservando a precedência de inteiros puros sobre prefixados. `extract_text` passa a ler entidades `ATTRIB`. `build_geojson` aplica fallback de distância (`<= 8.0` escalado por unidade linear) para rótulos `Q-xx` somente quando a quadra não cobre nenhum `Q-xx`, possui lotes associados e há exatamente 1 rótulo no raio.
- `functions-python/dxf_extraction.py`: incluído `'ATTRIB'` em `TEXT_TYPES` e emissão de `entity.attribs` em `_flatten` com herança de layer e cor ACI (`_effective_color`: `0`/BYBLOCK segue o `INSERT`, `256`/BYLAYER segue `doc.layers`). Adicionado cálculo de escala linear/área por `$INSUNITS` (`_unit_linear_scale`, `_unit_area_scale`). Refinado `_geometry_classification` para descartar molduras que cobrem `QUADRA_REGEX` sem candidato a lote e polígonos sem candidato a nome cuja cor ACI efetiva diverge da cor predominante (`>= 50%`) dos lotes com candidato.
- No fixture `00a-LOTEAMENTO_HR_R13A-Model_SEM_COTAS.dxf`: todas as 23 quadras (`Q-01` a `Q-23`, incluindo `Q-19`) são reconhecidas, `validos == 245` e `ambiguos == 18`.

## Spec Change Log

## Review Triage Log

## Verification

**Commands:**
- `/Users/usuario/obras/functions-python/venv/bin/python -m pytest /Users/usuario/obras/functions-python/tests/ -q` -- expected: todos os testes em `functions-python/tests/` passam.

