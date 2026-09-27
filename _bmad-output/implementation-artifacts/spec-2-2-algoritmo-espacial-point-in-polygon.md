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

### Review Findings

- [x] [Review][Decision] Handoff do resultado da associação para a Story 2.3b — `association_result` é reduzido a contadores para um log e descartado ao fim de `processar_dxf`; nenhum valor é retornado ou mantido acessível, então o dicionário de associação (`quadras`/`lotes_orfaos` com polígonos) se perde. A spec pede "guardar o dicionário resultante" e "manter a estrutura em memória para a Story 2.3b". É preciso definir o contrato de passagem (retorno da função, variável de módulo, ou persistir no rascunho já em 2.3b). [functions-python/main.py:140-147]
- [x] [Review][Decision] Política para Quadras sobrepostas/aninhadas — Um Lote cujo ponto representativo cai em mais de uma Quadra é anexado à primeira que casa, via `break`, sem aviso nem marcação de ambiguidade. Não há regra definida para desempate (menor área, mais específica, primeira do DXF) nem uso da convenção `"status": "ambiguo"` do épico. [functions-python/geometry_utils.py:88-94]

- [x] [Review][Patch] Normalizar e observar geometria inválida após `buffer(0)` [functions-python/geometry_utils.py:37-41]
- [x] [Review][Patch] Cobrir com testes os caminhos hoje não exercitados: conversão POLYLINE, recuperação `buffer(0)` e wiring do pipeline [functions-python/tests/test_geometry_utils.py:30-94]
- [x] [Review][Patch] Executar o pytest de `functions-python` no CI [.github/workflows/ci.yml]
- [x] [Review][Patch] Limpeza: remover imports mortos, guard redundante e renomear `l_centroid` [functions-python/geometry_utils.py:2-3,29,36,81-84]

- [x] [Review][Defer] `LINE` isoladas e fechamento forçado sem verificar sequência [functions-python/geometry_utils.py:27,33-34] — deferred: pré-existente e já registrado no Review Triage Log (Group 4, escopo); sequência de `LINE`s e verificação de conectividade excedem a história atual.
- [x] [Review][Defer] Bulges/arcos e POLYLINE mesh/3D não tratados [functions-python/geometry_utils.py:14,27] — deferred: pré-existente (Group 4); tesselação de arcos e normalização de polyface/mesh são otimização/robustez fora do escopo básico.
- [x] [Review][Defer] `review_fallback_prompts.md` versionado com caminhos de máquina e conteúdo duplicado [review_fallback_prompts.md:33,42,46] — deferred: artefato de processo não-portável; limpeza de repositório, sem impacto em runtime.

#### Rejected

- `false` — `get_points_from_polyline` lança exceção em vez de "logar e continuar": a exceção é capturada em `ezdxf_entity_to_polygon` (`geometry_utils.py:42-43`), portanto a execução nunca é bloqueada. O comportamento alegado não ocorre.
- `false` — Inconsistência de status `done`/`review` entre frontmatter da spec, `sprint-status.yaml` e `deferred-work.md`: bookkeeping reconciliado pela etapa de sincronização deste workflow; corrigir o frontmatter editando a spec sob revisão.
- `low` (rejeitado) — Seções `## Implementation Notes` vazias e evidências do Review Triage Log que apenas repetem o problema / citam `len(pts) >= 4` enquanto o código usa `len(pts) < 3`: correções seriam edições na spec sob revisão.
- `low` (rejeitado) — Lotes órfãos sem campo literal `"status": "Sem Quadra"` nem log por lote: a chave `lotes_orfaos` já codifica o estado e há log agregado em `main.py:145`; a materialização do status pertence à persistência da 2.3b.
- `low` (rejeitado) — Entrada nova de `deferred-work.md` sem referências `file:line`: rastreabilidade cosmética; a correção adiciona complexidade sem defeito demonstrado.


### Review Findings — 2026-09-27 (commit `9a3d8e1`)

Escopo confirmado: `9a3d8e1^..9a3d8e1`, 6 arquivos, +226/-7. Revisão completa com quatro camadas independentes: blind-hunter, edge-case-hunter, verification-gap e acceptance-auditor. Nenhuma camada falhou. Referências de linha abaixo correspondem ao commit revisado, salvo indicação explícita de HEAD.

- [ ] [Review][Decision] **Alta — Reparo descarta componentes válidos de uma quadra.** `buffer(0)` pode gerar partes de áreas 16 e 1; selecionar apenas a maior faz um lote na parte menor virar órfão. Reproduzido com vértices `(0,0),(4,0),(4,4),(0,4),(0,0),(-1,0),(-1,-1),(0,-1),(0,0)` e lote interno à região negativa. Definir se o reparo deve preservar todos os componentes ou rejeitar explicitamente a geometria multipartida com aviso. A segunda opção é admitida pela matriz de geometria inválida da spec, mas não recupera os lotes dessa quadra. O comportamento persiste em HEAD. [functions-python/geometry_utils.py:55-59]
- [ ] [Review][Patch] **Alta — Converter coordenadas OCS para WCS antes da associação.** Com quadra `(0,0)..(10,10)` e lote OCS `(-4,2),(-2,2),(-2,4),(-4,4)` com extrusão `(0,0,-1)`, os vértices WCS estão dentro da quadra, mas a associação o devolve como órfão. Usar a transformação própria da entidade e adicionar regressão com entidades DXF reais. Persiste em HEAD. [functions-python/geometry_utils.py:13-20]
- [ ] [Review][Patch] **Média — Cobrir ponto representativo em lote côncavo e inclusão de borda.** Testes atuais só usam retângulos com pontos internos/externos; trocar `representative_point` por `centroid` ou `covers` por `contains` não é detectado. Afirmar listas exatas de associação para ambos os casos. [functions-python/tests/test_geometry_utils.py:58-84]
- [ ] [Review][Patch] **Média — Cobrir recuperação multipartida e vazia com resultados exatos.** O bowtie atual produz `Polygon` de área 25 no ambiente verificado, não exercitando a seleção de componente de `MultiPolygon`. `is_valid`/não nulo não detectam seleção da parte errada. Testar a política que for escolhida na decisão acima e reparo vazio. [functions-python/tests/test_geometry_utils.py:47-56]
- [x] [Review][Patch] **Média — Integração quebra o teste existente do pipeline no commit revisado; corrigido posteriormente.** `test_processar_dxf_valid` fornece strings ao novo associador e falha em `entity.dxftype()`. Snapshot exato: **29 passed, 1 failed**. O CI já executa toda a suíte Python. Em HEAD, o teste usa um DXF real e a cadeia de processamento, e passou isoladamente (**1 passed**); a correção veio em `a4820ca`, não foi realizada nesta revisão. A lacuna original de wiring está agrupada aqui. [functions-python/main.py:167; functions-python/tests/test_main.py:90-114]
- [x] [Review][Defer] **Média — Empate entre quadras de mesma área depende da ordem de entrada.** Duas quadras sobrepostas de área 100 atribuem o mesmo lote a entidades diferentes ao inverter a entrada. Deferred: política de sobreposição já registrada como fora do escopo no Group 4 da revisão anterior; preservada nesta rodada. Exige decisão de desempate/ambiguidade antes de implementação. [functions-python/geometry_utils.py:115-121]

#### Evidências de execução

- Snapshot isolado do commit, extraído por `git show`, sem checkout ou alteração de código de produção; interpretador `functions-python/.venv/bin/python`.
- `python -m pytest -q -p no:cacheprovider` no snapshot: **29 passed, 1 failed**, falha `test_processar_dxf_valid`, `AttributeError: 'str' object has no attribute 'dxftype'`.
- Teste isolado `functions-python/tests/test_main.py::test_processar_dxf_valid` em HEAD: **1 passed**. Não constitui validação integral de HEAD.
- Reproduções no snapshot: MultiPolygon com áreas `[16.0, 1.0]` reduzido a `16.0`, lote da região menor órfão; extrusão negativa produz vértices WCS contidos e associação órfã; inversão das quadras empatadas altera o destino.

#### Triagem individual (antes do agrupamento)

| ID | Origem | Achado | Veredito | Evidência / destino |
|---|---|---|---|---|
| 1 | blind-hunter | Handoff local ausente | false | A spec exige manter a estrutura em memória para a futura etapa, sem persistir nesta história. A variável local existe após a chamada; não há consumidor externo exigido. |
| 2 | blind-hunter | Pytest ausente no CI | false | `git show 9a3d8e1:.github/workflows/ci.yml` contém job functions-python com instalação e `python -m pytest`. |
| 3 | blind-hunter | Wiring sem verificação | medium | No snapshot, o teste integrado falha antes de completar a associação. Agrupado ao defeito do teste; DXF real e chamada de persistência já exercitados pelo teste posterior que passou. |
| 4 | blind-hunter | Perda de componentes no reparo | high | Reproduzido: parte de área 1 descartada e lote contido vira órfão. Decision. |
| 5 | blind-hunter | Empate por ordem | medium | Reproduzido invertendo quadras de mesma área; política de sobreposição previamente adiada. Defer. |
| 6 | blind-hunter | Teste de buffer fraco | medium | Só afirma validade/não nulo; não cobre recuperação multipartida nem vazia. Patch, agrupado ao ID 12. |
| 7 | edge-case-hunter | OCS comparado como WCS | high | Extrusão negativa reproduz falso órfão com entidade DXF válida. Patch. |
| 8 | edge-case-hunter | Teste do pipeline quebra | medium | Pytest do snapshot confirma AttributeError; mesmo defeito de 3 e 13; corrigido em commit posterior. |
| 9 | edge-case-hunter | Handoff descartado | false | Mesmo contrato do ID 1: continuação síncrona futura é permitida; não existe consumidor externo no escopo exigindo retorno. |
| 10 | edge-case-hunter | Polígonos não retornados | false | Spec não exige mapa público de polígonos nem proíbe reconversão. Nenhum consumidor nesse commit perde uma entrada exigida. A Story 2.3 posteriormente adicionou os mapas. |
| 11 | verification-gap | Concavidade/borda sem regressão | medium | Evidência de testes apresentada pelo revisor: mutações centroid/contains sobrevivem aos retângulos existentes. Patch. |
| 12 | verification-gap | Maior componente sem verificação | medium | Evidência apresentada: max→min não distinguido pelas asserções; agrupado ao ID 6. Teste final depende da política aprovada. |
| 13 | acceptance-auditor | Teste obrigatório do pipeline quebra | medium | Confirmado pelo pytest do snapshot; agrupado a 3 e 8, corrigido posteriormente. |

Resultado: **1 decision-needed, 3 patches pendentes, 1 patch histórico já corrigido, 1 defer, 4 rejeitados**. Nenhum código alterado nesta revisão. Status da história/sprint será sincronizado após a decisão e o tratamento dos itens, conforme o workflow.

#### Rejected

- ID 1 — `false`: variáveis locais atendem à manutenção em memória até a implementação da etapa seguinte; retorno/estado global não é requisito da spec.
- ID 2 — `false`: o job Python já existe no commit e executa pytest; ausência de alteração do workflow no diff não prova ausência de CI.
- ID 9 — `false`: não há contrato exigido de consumo fora do handler no escopo 2.2; atribuição local preserva os dados durante a execução.
- ID 10 — `false`: retorno de polígonos normalizados não é contrato definido da história; necessidade futura de reconversão não demonstra falha deste commit.
