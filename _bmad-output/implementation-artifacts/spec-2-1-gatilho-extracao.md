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

A extração pode ser feita identificando os Layers ou os tipos de Blocos correspondentes a Lotes e Quadras. O código inicial usará um mapeamento simplificado dos nomes de layers (por exemplo, layers contendo a substring 'LOTE' e 'QUADRA') ou iterará pelas polylines.

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

A extração pode ser feita identificando os Layers ou os tipos de Blocos correspondentes a Lotes e Quadras. O código inicial usará um mapeamento simplificado dos nomes de layers (por exemplo, layers contendo a substring 'LOTE' e 'QUADRA') ou iterará pelas polylines.

## Verification

**Commands:**
- `cd functions-python && python -m pytest` -- expected: Todos os testes locais passam, assegurando regras de extração (INSERT/lotes/quadras) e controle de fluxos de erro.
- `cat .github/workflows/ci.yml | grep pytest` -- expected: O comando de teste Python existe no CI.
