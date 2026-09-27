---
title: 'Corrigir Importação de DXF'
type: 'bugfix'
created: '2026-09-27'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
context: []
baseline_commit: '17e994ea900bbbf5717bcb37fc9bc4423fe6b7e9'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A importação de arquivos DXF está falhando ou deixando erros ocultos em certas situações. A heurística falha ao não ignorar a palavra 'LOTE', e erros fatais de persistência de rascunhos (DraftPersistenceError) estão sendo capturados no main.py sem logging suficiente, deixando-nos cegos quanto à causa raiz. Além disso, não temos testes cobrindo um arquivo DXF problemático.

**Approach:** 
1. Adicionar 'LOTE' à lista de `STOP_WORDS` no `heuristics.py`.
2. Alterar o bloco except para `DraftPersistenceError` no `main.py` para usar `logger.exception` (ou implementar métricas customizadas, dependendo da resposta do usuário), garantindo visibilidade do stack trace e detalhes do erro.
3. Criar um teste automatizado em `test_main.py` simulando um DXF problemático e o comportamento de erro, para evitar regressões.

**Decisions:**
- Logs/Métricas: Apenas Logs Detalhados (`logger.exception` enviará o erro e stack trace para o GCP Error Reporting).
- Arquivo DXF de Teste: Criar um DXF Mockado com ezdxf no próprio teste.

</frozen-after-approval>

## Code Map

- `functions-python/heuristics.py` -- Modificar constante `STOP_WORDS`.
- `functions-python/main.py` -- Modificar o bloco except de `DraftPersistenceError` para adicionar logs mais detalhados.
- `functions-python/tests/test_main.py` -- Adicionar um novo teste automatizado que reproduza ou mocke o cenário de falha com DXF e teste a resposta.

## Tasks & Acceptance

**Execution:**
- [x] `functions-python/heuristics.py` -- Adicionar 'LOTE' na variável global `STOP_WORDS` -- Para que a heurística de nomenclatura ignore a palavra 'LOTE'.
- [x] `functions-python/main.py` -- Atualizar o bloco `except DraftPersistenceError` substituindo `logger.error` por `logger.exception` ou adicionando métricas -- Para garantir que o erro e o stack trace fiquem visíveis nos logs/alertas (não ficarmos cegos).
- [x] `functions-python/tests/test_main.py` -- Adicionar teste unitário simulando a leitura de um DXF e o lançamento de `DraftPersistenceError` (mockado se necessário) verificando se o log foi disparado corretamente -- Para garantir cobertura automatizada desse cenário de falha.

**Acceptance Criteria:**
- Given um texto extraído do DXF contendo a palavra 'LOTE', when a heurística o processar, then a palavra 'LOTE' deve ser ignorada.
- Given uma falha na persistência que lance `DraftPersistenceError`, when o `main.py` capturar a exceção, then o erro completo com o stack trace deve ser registrado no log (ou nas métricas).

## Implementation Notes


## Spec Change Log


## Review Triage Log


## Verification

**Commands:**
- `uv run pytest functions-python/tests/test_main.py functions-python/tests/test_heuristics.py` -- expected: Testes passam e a cobertura para a modificação de logs em main.py e heurística em heuristics.py está garantida.
