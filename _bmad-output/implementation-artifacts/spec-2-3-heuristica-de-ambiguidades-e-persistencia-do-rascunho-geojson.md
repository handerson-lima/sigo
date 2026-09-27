---
title: 'Story 2.3: Heurística de Ambiguidades e Persistência do Rascunho (GeoJSON)'
type: 'feature'
created: '2026-09-27'
status: 'in-review'
baseline_commit: '48dfcdc8e623de5696dc6d1cc4adc371dd17a248'
route: 'dispatch'
review_loop_iteration: 1
context: ["_bmad-output/implementation-artifacts/epic-2-context.md"]
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O backend já extrai a geometria de lotes e quadras de arquivos DXF e mapeia seus relacionamentos espaciais, porém as entidades de texto ainda não estão associadas, não há marcação visual para intervenção do usuário, e os dados não estão sendo gravados em um rascunho persistente.
**Approach:** Criar um módulo de heurística que faça a correspondência espacial dos `textos` extraídos com os polígonos correspondentes. Lotes com falha de identificação (múltiplos textos, textos inválidos, ou sem texto) receberão status de `ambiguo`. Todo o resultado deve ser serializado em um `GeoJSON` estrito e salvo na coleção `loteamentos_drafts` no Firestore para o front-end consumir.

## Boundaries & Constraints

**Always:**
- Salvar um único documento na coleção `loteamentos_drafts` tendo como `ID` do documento o exato `uniqueFilename` do arquivo no Cloud Storage (garantindo que o front-end escute o ID correto).
- Atribuir `"status": "ambiguo"` a qualquer Lote que tenha 0 ou >1 identificadores candidatos após a filtragem de palavras, ou que a heurística detecte como mal formado.
- O payload de saída para o Firestore deve seguir rigorosamente a especificação `GeoJSON` (FeatureCollection de Features Polygon).
- Cada Feature no GeoJSON deve conter a extensão de propriedades: `tipo` ("quadra" ou "lote"), `nome` (string, se resolvido) e `status` ("valido" ou "ambiguo"). Lotes órfãos devem receber `status: ambiguo`.

**Never:**
- Não salvar múltiplos documentos. O rascunho inteiro de um loteamento deve caber no documento GeoJSON de draft.
- Não manter Lotes órfãos como "válidos". Sem uma Quadra associada, a hierarquia falha e requer revisão manual.

**Decisions:**
- Heurística de Filtragem: Permitir o uso combinado de Stop Words e Expressões Regulares (RegEx). O RegEx deve identificar padrões de dimensão (ex: "15x30", `^\d+(X|x)\d+$`) para rejeitá-los como nomes válidos de lotes.
- Estrutura do GeoJSON: Omitir as geometrias de Quadras no GeoJSON final. O nome da quadra será injetado diretamente nas propriedades de cada Lote para reduzir o payload.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| HAPPY_PATH | Lote com exato 1 texto legível dentro de seu polígono e sem match em stop words. | Lote ganha propriedade `"nome": "<texto>"`, `"status": "valido"`. | N/A |
| MULTIPLE_TEXTS | Lote tem textos "LOTE 1" e "15x30" em seu interior. A heurística filtra "15x30". Sobra apenas 1. | Lote ganha `"nome": "LOTE 1"`, `"status": "valido"`. | N/A |
| AMBIGUOUS_TEXT | Lote com múltiplos textos válidos ou zero textos. | Lote ganha `"nome": ""`, `"status": "ambiguo"`. | N/A |
| ORPHAN_LOTE | Lote que o algoritmo anterior definiu como órfão (sem quadra). | Lote vai pro GeoJSON com `"status": "ambiguo"`, exigindo revisão. | N/A |

</frozen-after-approval>


## Code Map

- `functions-python/main.py` -- Deve importar o novo módulo de heurística, transformar `association` e `textos` em GeoJSON e salvar com firebase_admin.
- `functions-python/heuristics.py` -- Novo arquivo para o algoritmo de pareamento texto-polígono (testes de intersecção/cobertura) e montagem do dicionário de propriedades de cada Feature.
- `functions-python/firestore_utils.py` -- Novo arquivo para isolar a gravação no `loteamentos_drafts/{uniqueFilename}` do Firestore.

## Tasks & Acceptance

**Execution:**
- [x] `functions-python/heuristics.py` -- Criar funções para parear Textos com Polígonos de Lote e aplicar a filtragem heurística para definir `status` e `nome`. Converter dados estruturados para FeatureCollection GeoJSON.
- [x] `functions-python/firestore_utils.py` -- Criar função que salva o dicionário GeoJSON no Firestore na coleção `loteamentos_drafts`.
- [x] `functions-python/main.py` -- Integrar `heuristics.py` e `firestore_utils.py` ao fluxo de `processar_dxf`. O ID do doc será baseado em `temp_local_filename` ou em um extrato de `file_data.name` (que contém o ID no storage).
- [x] `functions-python/tests/` -- Escrever testes unitários verificando a conversão para GeoJSON e a lógica de atribuição "ambíguo".

**Acceptance Criteria:**
- Given Lotes e Quadras estruturados espacialmente e Textos extraídos do DXF, when a heurística for aplicada, then o GeoJSON final deve marcar como "ambiguo" os lotes cujo nome não pôde ser claramente identificado (0 ou mais de 1 texto válido candidato).
- Given um arquivo processado com sucesso, when o GeoJSON for finalizado, then ele deve ser persistido como um único documento no Firestore na coleção `loteamentos_drafts` utilizando o ID do arquivo original enviado pela UI.

## Implementation Notes

## Spec Change Log

- **2026-09-27:** Resolvido `intent_gap` entre a decisão de não usar RegEx e a regra da matriz de I/O de filtrar textos de dimensão ("15x30"). Restrição de RegEx removida para permitir a filtragem robusta de marcações de dimensão.

## Review Triage Log

- [Review][bad_spec] BH1 / EC9: A matriz de I/O exige filtragem de "15x30" (dimensões), mas as Decisions banem RegEx em favor de Stop Words hardcoded, impossibilitando satisfazer o critério (high).
- [Review][patch] BH5 / EC1: Lotes órfãos sem polígonos são silenciosamente ignorados do GeoJSON, violando a regra de mantê-los como ambíguos (medium).
- [Review][false] BH2: Lote nomeado "12" é perfeitamente válido no contexto de loteamentos; rejeitado.
- [Review][low] BH3: Tuplas vs Arrays em GeoJSON; Firestore SDK serializa tuplas para listas nativamente na web; rejeitado.
- [Review][false] BH4 / VG6: draft_id com .dxf reflete perfeitamente o uniqueFilename que o frontend já usa.
- [Review][low] BH6: Omissão de `contains` em favor de `covers` é puramente estética; rejeitado.
- [Review][defer] BH7 / EC4: Textos na fronteira entre lotes; edge-case a ser deferido.
- [Review][patch] BH8 / EC5: Busca `in` de "Q" captura substrings indevidas como "MAQUINA" (medium).
- [Review][patch] BH9 / EC2: `str(None)` resulta na string literal "None" (medium).
- [Review][false] BH10 / EC10: Reivindica falta de validação de malformado, mas 0 ou >1 candidatos cobre corretamente esse estado na heurística.
- [Review][patch] BH11: Exception no Firestore vaza a Cloud Function em vez de ser adequadamente capturada em `main.py` (medium).
- [Review][defer] BH12: Escrita de estado de erro no rascunho é fora do escopo original.
- [Review][patch] VG1 / BH13: Faltam testes verificando 0 candidatos ou múltiplos candidatos válidos resultando em `ambiguo` (medium).
- [Review][patch] VG2 / BH14: Falta asserção do caminho de persistência `save_draft_to_firestore` na suíte (medium).
- [Review][patch] VG3: O teste `test_processar_dxf_valid` lança `AttributeError` e quebra por usar mocks insuficientes em vez de entidades completas (medium).
- [Review][defer] VG4: Mudança na ordem de processamento de lotes órfãos não quebra clientes atuais.
- [Review][low] VG5: Propriedade `quadra` não é assertada pois não tem consumidor, é aceitável.
- [Review][patch] EC3: Textos colados com pontuação ("AV.", "Q.1") burlam as Stop Words exatas (medium).
- [Review][patch] EC6: Textos idênticos duplicados dentro do lote não sofrem deduplicação (medium).
- [Review][defer] EC7: Formatações de MTEXT não são purgadas.
- [Review][defer] EC8: Limite de 1 MiB do GeoJSON no Firestore (limite hard).
- [Review][defer] BH15: Winding order (exterior anti-horário) omitida.
- [Review][low] BH16: Passar as dicts e a association completa não convida a bugs letais.
- [Review][false] BH17: ezdxf_entity_to_polygon garante retorno de um Shapely Polygon puro e já trata o unboxing de MultiPolygons.
- [Review][patch] A1 / A22: Usar `contains` em vez de `covers` para lotes descarta textos na fronteira exata, causando falsos ambíguos. Guard: usar covers ou desempatar explicitamente.
- [Review][patch] A2: `list(poly.exterior.coords)` produz tuplas, e podem ser 3D; Firestore SDK do Python só aceita listas 2D nativas.
- [Review][patch] A3 / A4 / EC2: Código de extração de MTEXT inalcançável e usando regex quebrado. Usar `ezdxf.tools.text.plain_text()`.
- [Review][patch] A5 / EC5: Exceções transitórias engolidas e transformadas em DraftPersistenceError fatal. Re-raise em erros de rede/timeout.
- [Review][defer] A6: Salvar status de erro no Firestore em caso de poison message.
- [Review][patch] A7 / A8 / EC6: `draft_id` descartava `{userId}`, podendo sobrescrever drafts entre diferentes usuários se o nome do arquivo batesse.
- [Review][patch] A9: Docstring de `geometry_utils.py` desatualizada em relação a quadra_polygons.
- [Review][defer] A10: Ordem não determinística de `lotes_orfaos`.
- [Review][patch] A11: Emitir `geometry: null` viola a especificação estrita do GeoJSON de Polygon. Emitir `{"type": "Polygon", "coordinates": []}` em vez disso.
- [Review][patch] A12: `if not poly:` engole polígonos validamente vazios. Usar `is None`.
- [Review][patch] A13 / EC3: `DIMENSION_REGEX` não captura espaços (15 x 30) ou sufixos (15x30 m).
- [Review][patch] A14: O filtro `any(tok in STOP_WORDS)` rejeita textos válidos como "CASA 2" indevidamente. O filtro deve ser `val in STOP_WORDS`.
- [Review][patch] A15: `quadra_nome` cede à primeira quadra na ordem de textos. Atribuir só se houver candidato único.
- [Review][patch] A16 / VG1 / VG2: Falta de teste do fluxo de persistência e DraftPersistenceError. Criar `test_firestore_utils.py`.
- [Review][patch] A17 / VG3: Ausência de asserção da limpeza do arquivo temporário no teste de sucesso em `test_main.py`.
- [Review][patch] A18 / A19 / A20: Sujeira nos artefatos (commits de `.patch` e prompts) e paths absolutos no deferred-work.md.
- [Review][false] A21: Alega que spec foi editada in-place sem re-aprovação, o que é falso, pois a aprovação humana foi explicitamente solicitada e registrada no change log durante o loopback de intent_gap.
- [Review][defer] A23: Limite de tamanho de documento de 1 MiB no Firestore.
- [Review][patch] A24: `TEXT` com alinhamento deve usar `dxf.align_point` e recair no `dxf.insert`.
- [Review][patch] EC1: Texto na origem `(0,0,0)` vira `pt` falsy.
- [Review][patch] EC4: Regex de Quadra ignora letras ("QUADRA A").
- [Review][patch] VG4 / VG5 / VG6: Cobertura de teste ausente para `is_mtext`, limpeza de pontuação e deduplicação de strings idênticas.

## Verification

**Commands:**
- `cd functions-python && pytest tests/` -- expected: Testes da heurística passam com sucesso (cobertura dos casos órfãos, textos múltiplos e lixo).
