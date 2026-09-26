---
title: 'Story 2.1: Gatilho OnFinalize e Extração de Geometria Bruta'
type: 'feature'
created: '2026-09-26'
status: 'done'
baseline_commit: '2b0f467b261c0500b6f3e57269c6993851200e83'
route: 'dispatch'
review_loop_iteration: 1
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
- `functions-python/requirements.txt` -- Dependências `ezdxf`, `functions-framework`.

## Tasks & Acceptance

**Execution:**
- [x] `firebase.json` -- Atualizar a array `functions` para registrar o codebase `functions-python` (garantir runtime `python311`).
- [x] `functions-python/requirements.txt` e `functions-python/requirements-dev.txt` -- Declarar dependências básicas (`functions-framework`, `ezdxf`, `google-cloud-storage`, `pytest`).
- [x] `functions-python/main.py` -- Implementar a Cloud Function `processar_dxf` decorada com o gatilho Storage OnFinalize interceptando `loteamentos_drafts_uploads/`.
- [x] `functions-python/main.py` -- Fazer download seguro garantindo fechamento de File Descriptors, usar `ezdxf.read()`, tratar erros sem engolir retries transientes, validar size/generation, e extrair o `{userId}` do path.
- [x] `functions-python/main.py` -- Extrair blocos (incluindo tratamento para `INSERT`) e iterar sobre o modelspace agrupando polígonos/linhas por layer (separando de entidades texto), mantendo em variáveis locais (isolamento para Story 2.2).
- [x] `functions-python/tests/` -- Criar testes unitários com pytest validando filtro de rota, DXF corrompido, arquivo sem entidades, e fluxo principal com DXF sintético.

**Acceptance Criteria:**
- Given que um arquivo `.dxf` foi salvo no Cloud Storage no formato esperado pelo Flutter
- When a Cloud Function Python (Gen 2) é acionada via trigger `OnFinalize`
- Then o arquivo deve ser lido e parseado corretamente, extraindo blocos e polígonos, e passando nos testes unitários criados.

## Implementation Notes

## Spec Change Log

- **2026-09-26 (Loopback 1)**: Modificação do caminho do bucket alvo (`loteamentos_drafts_uploads/`) devido ao desalinhamento com o Flutter (intent_gap). Reforçada a necessidade de lidar explicitamente com blocos INSERT (`ezdxf.explode` ou equivalente), tratamento de exceções corretos (não engolir exceptions globais) e testabilidade (inclusão de `pytest`) devido a falhas capturadas no Code Review. (KEEP: Arquitetura `OnFinalize` na Gen 2 via `firebase-functions` continua válida).

## Review Triage Log

- `high` - O filtro de caminho em `main.py` usa `uploads/loteamentos/` mas o app envia para `loteamentos_drafts_uploads/`, impedindo o processamento real (encontrado pelo verification-gap e edge-case-hunter).
- `high` - Arquivos com blocos (INSERT) não são tratados corretamente, o que gera extração vazia para DXFs reais (encontrado pelo edge-case-hunter e blind-hunter). O spec explicitamente pedia "extrair os blocos" na Intent.
- `medium` - `tempfile.mkstemp` devolve um descritor de arquivo aberto que não é fechado com `os.close(fd)`, causando vazamento de fd.
- `medium` - Acessar `entity.dxf.layer` antes do filtro de tipo pode lançar `AttributeError` em entidades sem layer.
- `medium` - O bloco `except Exception as e:` engole todas as exceções, o que impede que erros transientes disparem um retry automático do Cloud Functions.
- `medium` - Layers contendo tanto LOTE quanto QUADRA são processados apenas como LOTE devido ao `if/elif`.
- `medium` - Ausência de verificação do limite de tamanho do arquivo DXF antes do processamento (OOM em arquivos muito grandes).
- `medium` - O object pode ser refetched apenas pelo nome, ignorando o generation id do evento.
- `medium` - `file_data.name` ou `file_data.bucket` podem ser `None` gerando `AttributeError`.
- `medium` - Falta de testes para validar as extrações e os ramos de fluxo (NO_ENTITIES, INVALID_FILE) via pytest.
- `low` - `TEXT` e `MTEXT` anexados na lista `lotes`, misturando strings com geometria espacial.
- `low` - A falta da extração do `{id}` do loteamento, pois será necessário na próxima story.
- `low` - `firebase.json` está sem a declaração do runtime `python311` e o nome do codebase difere do esperado (`python-functions` vs `functions-python`).
- `low` - Importação não utilizada do `firestore` e importação redundante do `firebase_admin.initialize_app()` dentro de um function environment.
- `false` - Manter as variáveis em memória e descartar no retorno significa que a Story 2.2 não tem entrada. Verificado: a Story 2.2 é uma continuação deste pipeline na mesma função Cloud, e o isolamento desta story é intencional.
- `false` - As dependências divergem, ex. `shapely` não utilizado. Verificado: `shapely` é proposital, preparado para a Story 2.2.
- `false` - `epic-2-context.md` substituindo o contexto. Verificado: não havia contexto anterior para este épico que precisasse de preservação.
- `false` - O status no spec diz `in-review` mas no yaml diz `in-progress`. Verificado: este é o estado correto da máquina de estados durante o step-04.
- `low` [patch] - `__pycache__` e `debug.py` entram no changeset, e o `.gitignore` raiz não possui regras para Python. Fix: Adicionar regras ao `.gitignore` e remover `debug.py` do index.
- `low` [patch] - `debug.py` possui falha silenciosa com o MagicMock. Fix: O arquivo `debug.py` será removido, pois era apenas para debug local.
- `low` [patch] - `main.py` contém prints de debug (`DEBUG: Invalid path`). Fix: Remover os prints de debug.
- `medium` [patch] - O decorator `@storage_fn.on_object_finalized(bucket="sigo-86dd9.appspot.com")` tem o bucket fixado no código de produção e testes. Fix: Remover o argumento `bucket` para ouvir o default.
- `medium` [patch] - `firebase.json` omite a chave `runtime: python311`. Fix: Adicionar `"runtime": "python311"` ao codebase `functions-python`.
- `high` [patch] - INSERTs não aplicam transformação matricial (coordenadas erradas) nem tratam aninhamentos. Fix: Usar `entity.virtual_entities()` do ezdxf, que resolve as matrizes de inserção e aninhamentos de forma transparente.
- `medium` [patch] - Sub-entidades no layer 0 (comum em blocos) são descartadas pelo filtro. Fix: Herdar o layer da entidade pai (INSERT) para entidades no layer 0 ou "BYBLOCK".
- `medium` [patch] - Acessar `entity.dxf.name` no INSERT pode lançar `AttributeError` e causar crash. Fix: Capturar corretamente as exceções de atributo ou usar `.dxf.get('name')`.
- `medium` [patch] - Entidades de TEXT/MTEXT são descartadas e a heurística de ambiguidades ficará sem insumo. Fix: Extrair também os textos para a memória e retornar em uma lista `textos`.
- `medium` [patch] - Parsing de caminho inconsistente: docstring diz 3 partes, mas código tenta 4. Fix: Padronizar e corrigir o parsing de `file_name.split("/")`.
- `medium` [patch] - `firebase-functions==0.2.0` no `requirements.txt` é obsoleto e o `pytest` não está no principal. Fix: Atualizar as versões do SDK e mover `pytest` para o dev.
- `low` [patch] - O .venv está usando Python 3.14 ao invés do target 3.11+. Fix: O CI de deploy usará a versão da engine, para o local usaremos o `uv` forçando o python 3.11.
- `medium` [patch] - Cobertura de testes falha em INSERTs e caminhos extremos, sem asserção forte. Fix: Melhorar `test_main.py` com asserções das listas e cenários.
- `medium` [patch] - `extract_dxf_geometries` não captura exceções base do ezdxf (`ezdxf.DXFError`). Fix: Capturar erros ezdxf e evitar leak para o except genérico.
- `low` [patch] - As tarefas do spec-2-1 estão desmarcadas. Fix: Marcar as checkboxes no spec.
- `high` [patch] - `epic-2-context.md` foi inteiramente reescrito e perdeu o contexto PWA UX. Fix: Restaurar o arquivo do git e apenas concatenar (append) o contexto novo.
- `low` [patch] - diff-spec-2-1.diff repete hunks e inclui arquivos de processo. Fix: Gerar diff mais limpo e ignorar os próprios diffs.

## Design Notes

A extração pode ser feita identificando os Layers ou os tipos de Blocos correspondentes a Lotes e Quadras. O código inicial usará um mapeamento simplificado dos nomes de layers (por exemplo, layers contendo a substring 'LOTE' e 'QUADRA') ou iterará pelas polylines.

## Verification

**Commands:**
- `firebase deploy --only functions:processar_dxf --dry-run` -- expected: O CLI do firebase valida as sintaxes e consegue resolver o codebase corretamente.
- `cd functions-python && pytest` -- expected: Todos os testes locais passam, assegurando regras de extração (INSERT/lotes/quadras) e controle de fluxos de erro.
