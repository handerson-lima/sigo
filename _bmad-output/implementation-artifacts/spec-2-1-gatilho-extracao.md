---
title: 'Story 2.1: Gatilho OnFinalize e Extração de Geometria Bruta'
type: 'feature'
created: '2026-09-26'
status: 'done'
baseline_commit: '2b0f467b261c0500b6f3e57269c6993851200e83'
route: 'dispatch'
review_loop_iteration: 2
context: ["_bmad-output/implementation-artifacts/epic-2-context.md"]
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O sistema permite upload de DXF, mas não há um backend configurado para escutar esse evento e parsear a geometria nativa do CAD sem bloquear threads no cliente.

**Approach:** Criar uma Cloud Function Gen 2 em Python acionada por um gatilho `OnFinalize` no Cloud Storage. A função utilizará a biblioteca `ezdxf` para extrair os blocos e geometrias associadas a Quadras e Lotes e as manterá em memória preparadas para a próxima etapa (Story 2.2).

## Boundaries & Constraints

**Decisions:**
- SETUP DO PYTHON: Criar pasta `functions-python` e atualizar o `firebase.json` com codebase múltiplo (Padrão para manter a Gen 1/Node.js intacta).
- BUCKET E CAMINHO: Ouvir o bucket default do projeto no caminho `loteamentos_drafts_uploads/{userId}/{timestamp}_{filename}` para estar alinhado com o front-end Flutter.


**Always:**
- A função DEVE ser implementada em Python (Gen 2; 3.11+).
- Deve utilizar as bibliotecas `ezdxf` e `shapely` ou `google-cloud-storage`.
- O processamento deve ocorrer estritamente em memória após o download do arquivo DXF temporário.

**Never:**
- A função NÃO DEVE realizar inserções no banco de dados Firestore ainda, esta persistência será tratada nas histórias subsequentes.
- NÃO tentar processar a hierarquia topológica (Point-in-Polygon), apenas extrair as entidades brutas.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| HAPPY_PATH | Um arquivo `.dxf` válido é enviado ao bucket | O arquivo é lido, e entidades "Lote" e "Quadra" são extraídas para estruturas Python | N/A |
| INVALID_FILE | Um arquivo não-dxf ou dxf corrompido é enviado | A extração falha de modo controlado e loga um aviso no Cloud Logging | Log de Erro e interrupção graciosa sem crash unhandled |
| NO_ENTITIES | DXF válido, porém sem entidades de "Lotes" ou "Quadras" | A função processa corretamente, resultando em listas de geometrias vazias | Loga um aviso informando que o arquivo estava vazio de conteúdo útil |

</frozen-after-approval>


## Code Map

- `firebase.json` -- Configuração do codebase (para permitir Functions Node e Python coexistirem).
- `functions-python/main.py` -- Ponto de entrada da Cloud Function `onFinalize`.
- `functions-python/requirements.txt` -- Dependências: `firebase-functions`, `ezdxf`, `google-cloud-storage`.

## Tasks & Acceptance

**Execution:**
- [x] `firebase.json` -- Atualizar a array `functions` para registrar o codebase `functions-python` (garantir runtime `python311`).
- [x] `functions-python/requirements.txt` e `functions-python/requirements-dev.txt` -- Declarar dependências básicas (`firebase-functions`, `ezdxf`, `google-cloud-storage` no principal; `pytest` no dev).
- [x] `functions-python/main.py` -- Implementar a Cloud Function `processar_dxf` decorada com o gatilho Storage OnFinalize interceptando `loteamentos_drafts_uploads/`.
- [x] `functions-python/main.py` -- Fazer download seguro garantindo fechamento de File Descriptors (`try/finally`), usar `ezdxf.readfile()`, tratar erros não engolindo exceções transientes, validar size/generation, e extrair os dados. A função deve focar apenas na extração e terminar com sucesso, registrando o total extraído no log (sem chamar lógica topológica da Story 2.2b).
- [x] `functions-python/main.py` -- Extrair blocos (incluindo tratamento correto de herança para `INSERT` em layer 0) e iterar sobre o modelspace agrupando polígonos/linhas por layer usando correspondência flexível (ex: tokens no plural), separando de entidades texto.
- [x] `functions-python/tests/` -- Criar testes unitários com pytest validando filtro de rota, DXF corrompido, arquivo sem entidades, limites de tamanho e fluxo principal de extração de blocos/layers com DXF sintético. Assegurar chamadas corretas e mocks isolados (ex: `patch`). Adicionar `.github/workflows/ci.yml` ou um script de CI para rodar os testes, e um `conftest.py` ou `pythonpath` para resolver o `pytest`.

**Acceptance Criteria:**
- Given que um arquivo `.dxf` foi salvo no Cloud Storage no formato esperado pelo Flutter
- When a Cloud Function Python (Gen 2) é acionada via trigger `OnFinalize`
- Then o arquivo deve ser lido e parseado corretamente, extraindo blocos e polígonos, e passando nos testes unitários criados.

## Implementation Notes

A extração é feita identificando os Layers correspondentes a Lotes e Quadras. A correspondência usa tokens do nome do layer (separados por espaço, `_` ou `-`), casando `LOTE`/`LOTES` e `QUADRA`/`QUADRAS`; a entidade de uma camada combinada (ex.: `LOTE_E_QUADRA`) é classificada em ambas as listas.

## Spec Change Log

- **2026-09-26 (Loopback 1)**: Modificação do caminho do bucket alvo (`loteamentos_drafts_uploads/`) devido ao desalinhamento com o Flutter (intent_gap). Reforçada a necessidade de lidar explicitamente com blocos INSERT (`ezdxf.explode` ou equivalente), tratamento de exceções corretos (não engolir exceptions globais) e testabilidade (inclusão de `pytest`) devido a falhas capturadas no Code Review. (KEEP: Arquitetura `OnFinalize` na Gen 2 via `firebase-functions` continua válida).
- **2026-09-26 (Loopback 2)**: Foram identificadas instruções divergentes e vazamento de escopo (bad_spec). O comando `firebase deploy --dry-run` é inválido. O comando `pytest` falhava sem PYTHONPATH. O Code Map pedia `functions-framework` (não necessário para Gen2) e `ezdxf.read()` (mas `ezdxf.readfile` é o correto para caminhos locais). Além disso, a frase "manter em memória para a próxima etapa" induziu a implementação precoce da Story 2.2b. As instruções foram corrigidas para focar exclusivamente na extração e o comando de deploy/testes foi ajustado. Evitou-se o estado de pipeline quebrado e código morto. (KEEP: A infraestrutura Python com UV, testes baseados em pytest e on_object_finalized via firebase-functions).

## Review Triage Log


- `high` [bad_spec] - O contexto do Épico 2 foi atualizado com numeração concorrente (Stories 2.1b/2.2b vs 2.1/2.2), criando confusão.
- `high` [bad_spec] - O comando de verificação documentado (`firebase deploy --dry-run`) é inválido no Firebase CLI.
- `high` [bad_spec] - O comando de verificação `cd functions-python && pytest` não funciona por ausência de PYTHONPATH (`conftest.py` ou `python -m pytest`).
- `high` [bad_spec] - Code Map e tasks exigem `functions-framework` e `ezdxf.read()`, mas a implementação difere.
- `high` [bad_spec] - A Story 2.1b não deveria tentar reter as geometrias "em memória para a próxima etapa" pois Cloud Functions são stateless; o handoff precisa ser mais bem definido. A lógica da Story 2.2b (`associate_lotes_to_quadras`) vazou para a 2.1b.
- `high` [patch] - `buffer(0)` pode retornar `MultiPolygon` ou `GeometryCollection`, o que é tratado incorretamente como `Polygon` válido e quebra asserções seguintes.
- `high` [patch] - Não há CI configurado no `.github/workflows/ci.yml` para rodar os testes da pasta `functions-python`.
- `medium` [patch] - O bloco genérico `except Exception` força retries automáticos na Cloud Function mesmo para erros determinísticos (ex: arquivo inválido).
- `medium` [patch] - O wiring entre `processar_dxf` e `associate_lotes_to_quadras` não é assertado nos testes (efeito observável nulo).
- `medium` [patch] - Tokens de layers exatos ("LOTE", "QUADRA") falham ao ignorar variações comuns em plurais (ex: "LOTES").
- `medium` [patch] - Exceções `IOError`/`DXFError` retornam listas vazias (`NO_ENTITIES`) no lugar de propagar a falha corretamente.
- `medium` [defer] - Lotes que se sobrepõem a múltiplas quadras usam um `break` simplista na primeira combinação sem sinalizar ambiguidade. Isso deve ser tratado na Story 2.2b.
- `low` [patch] - A checagem de limite de tamanho do arquivo pula quando `file_data.size` é falsy.
- `low` [patch] - O replace `.replace('.dxf', '')` é case-sensitive e deixa extensões `.DXF` vazarem para o ID.
- `low` [patch] - `os.remove` no `finally` pode causar erro se o arquivo nunca foi criado.
- `low` [defer] - As variáveis extraídas `user_id` e `loteamento_id` não são usadas. Elas só serão usadas na persistência Firestore na Story 2.3b.
- `low` [patch] - Import não utilizado `import re` em `main.py`.
- `low` [patch] - Mocks globais injetados em `sys.modules` mascaram problemas de resolução.
- `low` [defer] - Arquivos markdown (`review_fallback_prompts.md`, diffs) referenciam paths absolutos não-portáveis (`/Users/usuario/...`).
- `low` [defer] - O `sprint-status.yaml` não reflete corretamente a máquina de estados desta story.
- `false` - INSERT na layer 0 faz entidades sumirem sem aviso. (Refutação: Em CAD, inserir um bloco no layer "0" preserva o layer original das subentidades; ele não converte automaticamente em LOTE/QUADRA, logo o descarte está correto).
- `false` - `firebase.json` omite entry point para Python. (Refutação: O default do Firebase Functions para Python é `main.py` caso a chave seja omitida, portanto é válido).
- `false` - `.gitignore` muito abrangente. (Refutação: Entradas adicionadas como `build/` são padrão para Python e não afetam arquivos de processo atuais).

## Design Notes

A extração é feita identificando os Layers correspondentes a Lotes e Quadras. A correspondência usa tokens do nome do layer (separados por espaço, `_` ou `-`), casando `LOTE`/`LOTES` e `QUADRA`/`QUADRAS`; a entidade de uma camada combinada (ex.: `LOTE_E_QUADRA`) é classificada em ambas as listas.

## Verification

**Commands:**
- `cd functions-python && python -m pytest` -- expected: Todos os testes locais passam, assegurando regras de extração (INSERT/lotes/quadras) e controle de fluxos de erro.
- `cat .github/workflows/ci.yml | grep pytest` -- expected: O comando de teste Python existe no CI.

### Review Findings (2026-09-27)

Diff: `2b0f467..HEAD` restrito a `functions-python/`, `firebase.json`, `.github/workflows/ci.yml`, `.gitignore`. 4 camadas.

- [x] [Review][Decision] (resolvido: manter token exato; Notes da spec reconciliadas e teste de camada combinada adicionado) Estratégia de classificação de layers (token exato vs substring vs camadas combinadas) — `main.py:49-65` casa tokens exatos `LOTE(S)`/`QUADRA(S)` separados por `_`/`-`; as Design/Implementation Notes da spec (linhas 70/106) pedem correspondência por substring `'LOTE'`/`'QUADRA'`. Camadas como `LOTE_E_QUADRA` são adicionadas às duas listas; `LOTE.1`, `LOTE/QUADRA`, `SUBLOTE`, `LOTEAMENTO` não têm regra definida nem teste. Decidir a convenção: substring vs token e o tratamento de camadas combinadas.
- [x] [Review][Patch] `.gitignore:87` `lib/` ignora `app/lib/` (fontes Dart novas) [`.gitignore:87`] — verificado com `git check-ignore -v app/lib/new_feature.dart` → casa `.gitignore:87:lib/`. Escopar para `functions-python/lib/` ou remover.
- [x] [Review][Patch] `extract_dxf_geometries` engole todas as exceções retornando vazio, tornando DXF corrompido/`IOError` indistinguível de `NO_ENTITIES` e sem retry [`functions-python/main.py:19-30`] — contradiz spec:59/74 e o `medium` do Triage Log; testes cristalizam o comportamento (`test_extract_dxf_geometries_ioerror`). Propagar `IOError`/`OSError`; reservar listas vazias para "sem entidades".
- [x] [Review][Patch] INSERT aninhado em layer 0 não herda o layer do ancestral [`functions-python/main.py:67-81`] — quando o INSERT interno está em layer `"0"`, `layer_to_pass` fica `"0"` e as sub-entidades não são classificadas. Herdar `parent_layer` quando o layer do INSERT for `0`/`BYBLOCK`; recursão aninhada também não tem teste.
- [x] [Review][Patch] Sem teste para `NO_ENTITIES` (DXF válido sem LOTE/QUADRA) [`functions-python/tests/test_main.py`] — cenário explícito da I/O & Edge-Case Matrix; os testes só atingem vazio por caminho de exceção.
- [x] [Review][Patch] `generation` não validado apesar da task "validar size/generation" [`functions-python/main.py:136`] — `bucket.blob(..., generation=file_data.generation)` sem guard; geração ausente pode baixar versão errada. Espelhar o tratamento de `size`.
- [x] [Review][Patch] `print("DEBUG: ...")` em produção em vez de Cloud Logging [`functions-python/main.py:99,105,128,132`] — substituir por `logger`.
- [x] [Review][Patch] Lacunas de cobertura em `processar_dxf` [`functions-python/tests/test_main.py`] — sem casos para `size` falsy/não-numérico, event fields malformados (`name=None`/`bucket=None`), limpeza do temp/fd e asserção do caminho do temp passado a `extract_dxf_geometries`/`download_to_filename`.

Achados `defer`:

- [x] [Review][Defer] `conftest.py` substitui namespaces inteiros (`google`, `firebase_functions`, `firebase_admin`) por `MagicMock` em `sys.modules`, mascarando erros reais de import/resolução [`functions-python/tests/conftest.py:9-24`] — deferred: infraestrutura de teste; correção exige harness maior, sem defeito de produção demonstrado.
- [x] [Review][Defer] `requirements.txt` não fixa versões (`>=`) enquanto `requirements-dev.txt` fixa [`functions-python/requirements.txt`] — deferred: higiene de reprodutibilidade, sem regressão demonstrada.
- [x] [Review][Defer] Filtro de rota valida só prefixo + extensão, sem checar o formato `{userId}/{timestamp}_{filename}` [spec:24] [`functions-python/main.py:108-115`] — deferred: formato será consumido na Story 2.3, não exigido pelos ACs desta.
- [x] [Review][Defer] `MAX_FILE_SIZE_BYTES = 50MB` com `memory=MB_512` e sem `timeout_sec` nem guarda de complexidade [`functions-python/main.py:13,89-92`] — deferred: maybe-false (não demonstrado); assentaria com evidência de OOM/truncamento em DXF real de ~50MB.
- [x] [Review][Defer] `firebase.json` ignora só `__pycache__`, sem `**/__pycache__`/`*.pyc` nem exclusão de `tests/`/dev requirements [`firebase.json:25-32`] — deferred: bloat de bundle no deploy, sem impacto funcional.
- [x] [Review][Defer] `extract_dxf_geometries` sem anotação de retorno e devolvendo entidades ezdxf cruas, sem contrato serializável para a Story 2.2 [`functions-python/main.py:15,86`] — deferred: interface entre stories, definida apenas na 2.2.
- [x] [Review][Defer] `except Exception ... raise` genérico força retry em erros possivelmente determinísticos [`functions-python/main.py:153-155`] — deferred: semântica de retry do Cloud Functions; avaliar taxonomia de erro junto com o patch de exceções.

Rejeitados (apêndice):

- `false` — CI `cache: pip` sem `cache-dependency-path`: o default do `actions/setup-python` cobre `**/requirements.txt`, então a dependência é encontrada.
- `false` — `event.data` `None`/`size` não-str-int: `data` sempre presente em `on_object_finalized`; `size` real é int e o caso ausente já é tratado. Inputs inviáveis na prática.
- `low` — `BYBLOCK` tratado como layer em `main.py:46`: sentinel de cor/tipo, não ocorre como nome de layer; comportamento inofensivo.

### Review Findings — Re-review (2026-09-27)

Diff: delta de correções (`git diff HEAD` restrito a `functions-python/`, `.gitignore`). 4 camadas. Suíte: 14 testes passam.

- [x] [Review][Decision] (resolvido: manter catch `(OSError, DXFError)`; `extract` retorna `None` para INVALID_FILE e listas vazias para NO_ENTITIES; logs distintos) Semântica de erro de `extract_dxf_geometries`: arquivo inválido (determinístico, sem retry) vs transiente (propaga/retry) vs `NO_ENTITIES` [`functions-python/main.py:21-26,148-149`] — o `except (IOError, OSError, ezdxf.DXFError)` retorna `([], [], [])`, então `INVALID_FILE` e `NO_ENTITIES` só se distinguem por log e um `IOError` transiente nunca chega ao retry; o comentário chama `IOError/OSError` de "deterministic" (impreciso, e `UnicodeDecodeError`/erros fora da tupla escapam para retry). Decidir a taxonomia: manter + documentar, propagar `IOError/OSError`, ou introduzir exceção de domínio `InvalidDxfError`.
- [x] [Review][Patch] Sem teste para o ramo `ezdxf.DXFError` (DXF estruturalmente inválido) [`functions-python/tests/test_main.py`] — os testes de erro usam texto puro/arquivo inexistente, que levantam `OSError`; o ramo `DXFError` fica sem cobertura (verificado: remover `ezdxf.DXFError` da tupla não quebra a suíte).
- [x] [Review][Patch] Sem asserção de que `generation` é repassado ao blob [`functions-python/tests/test_main.py`] — `test_processar_dxf_valid` não faz `mock_bucket.blob.assert_called_once_with(..., generation=...)`; a correção do guard de `generation` pode regredir silenciosamente.
- [x] [Review][Patch] Sem teste do caminho de falha de `blob.download_to_filename` nem da limpeza de fd/temp sob exceção [`functions-python/tests/test_main.py`] — os `raise` de `main.py:153-158` e o `finally` não são exercitados.
- [x] [Review][Patch] Lógica de herança de layer duplicada em `process_entity` e `explode_and_process` [`functions-python/main.py:42-43,71-72`] — o mesmo teste `not layer/layer=="0"/BYBLOCK → parent_layer` existe em dois pontos e pode divergir; extrair helper.
- [x] [Review][Patch] Testes de borda ausentes [`functions-python/tests/test_main.py`] — `size` exatamente igual a `MAX_FILE_SIZE_BYTES`, caminho `.DXF` maiúsculo, INSERT em `BYBLOCK`, e caso negativo/profundo de aninhamento (inner em `LOTES`, outer em `0`).
- [x] [Review][Patch] Fixture `synthetic_dxf` não usada em `test_processar_dxf_valid` (extração mockada) — remover o parâmetro para não escrever DXF real sem efeito.

Achados `defer`:

- [x] [Review][Defer] Cobertura de propagação de exceção inesperada fora de `(IOError, OSError, DXFError)` [`functions-python/main.py:21`] — deferred: comportamento defensivo e caminho hipotético; registrar teste junto ao ramo `DXFError` quando for tocado.
- [x] [Review][Defer] `.gitignore` escopado para `functions-python/lib/` deixa `lib/` aninhado (ex.: `pip install -t lib`) sem proteção [`/.gitignore:87`] — deferred: sem impacto no Flutter; alternativa `!app/lib/` mais estreita se houver necessidade.
- [x] [Review][Defer] `StopIteration` de DXF truncado pode escapar da tupla e forçar retry [`functions-python/main.py:21`] — deferred: maybe-false; assentaria com teste alimentando DXF truncado e observando o tipo de exceção do ezdxf.

Rejeitados (re-review):

- `low` — condição `not layer_to_pass` "morta" em `main.py:71`: guarda defensiva e inofensiva; o valor só é vazio em caso patológico já coberto pela intenção.
- `low` — ausência de telemetria/dead-letter no caminho de `generation` ausente: já loga `logger.error` e retorna; telemetria além do escopo desta story.
- `false` — exigência de trocar o nível de log de `INVALID_FILE` para "aviso": a coluna Error Handling da própria matriz pede "Log de Erro", então `logger.error` está correto.
