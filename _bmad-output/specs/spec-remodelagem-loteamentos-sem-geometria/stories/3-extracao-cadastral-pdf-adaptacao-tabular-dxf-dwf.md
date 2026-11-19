---
title: 'Extração Cadastral de PDF em 3 Cenários e Adaptação Tabular DXF/DWF'
type: 'feature'
created: '2026-11-19'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: '200c11a'
context:
  - '_bmad-output/specs/spec-remodelagem-loteamentos-sem-geometria/SPEC.md'
  - '_bmad-output/specs/spec-remodelagem-loteamentos-sem-geometria/data-contracts.md'
  - '_bmad-output/specs/spec-remodelagem-loteamentos-sem-geometria/architecture-diagrams.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O backend `functions-python` extraía contornos rasterizados/vetoriais em formato `FeatureCollection` GeoJSON (com campo `geometry`) voltados para revisão em canvas geométrico, sem suportar extração cadastral/dimensional de pranchas PDF (1 página, multipágina e múltiplos PDFs no mesmo rascunho) e sem materializar as 5 etapas padrão e o resumo desnormalizado dos lotes na consolidação.

**Approach:** Reescrever `functions-python/pdf_extraction.py` para extração textual/OCR (PyMuPDF + fallback `pytesseract`) de carimbo, localização, quadro geral de áreas, recuos e cotas lineares nos 3 cenários de PDF; adaptar `dxf_extraction.py`, `dwf_extraction.py` e `heuristics.py` para emitir exclusivamente o contrato tabular `items` (calculando dimensões aproximadas da envolvente e área em m², sem `geometry`); e atualizar `main.py` e `firestore_utils.py` para suportar merge transacional por `draftId`, `targetLoteamentoId` e consolidação atômica criando as 5 etapas padrão em `WriteBatch`es de até 500 operações.

## Boundaries & Constraints

**Always:**
- Emitir exclusivamente o contrato tabular (`loteamento`, `sourceFormat`, `sourceFiles`, `items`, `targetLoteamentoId`) em `loteamentos_drafts/{draftId}`, sem `geometry` nem `features`.
- Suportar os 3 cenários de PDF: página única, multipágina (agregando `items` de todas as páginas) e múltiplos arquivos PDF compartilhando o mesmo `draftId` via transação Firestore idempotente.
- Aplicar fallback OCR (`pytesseract`) quando o texto vetorial extraído via PyMuPDF for vazio ou insuficiente.
- Validar cotas lineares confrontando `frenteM * profundidadeM ~= areaTerrenoM2` com tolerância de 1%; na ausência de par compatível, manter dimensões nulas para revisão opcional.
- Na consolidação (`consolidate_approved_draft`), suportar novo loteamento ou mesclagem em `targetLoteamentoId` existente, criando atomicamente as 5 etapas padrão (`muro`, `cinza1`, `cinza2`, `cinza3`, `branca`, IDs `{loteId}_{tipo}`) e o resumo inicial (`progressoPercentual: 0`, `etapasConcluidasCount: 0`, `etapasTotalCount: 5`, `statusEtapasMap`) em batches de até 500 operações.

**Never:**
- Nunca persistir `geometry` ou `FeatureCollection` em `loteamentos`, `quadras`, `lotes` ou `loteamentos_drafts`.
- Nunca editar arquivos em `app/` ou `firestore.rules` nesta story.
- Nunca apagar o documento de rascunho em `loteamentos_drafts` durante a consolidação.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| PDF_SINGLE_PAGE | PDF de 1 página equivalente à referência (Lote 31, Quadra 28, Loteamento Jardim Botanico, Estivas, Extremoz/RN, 10x20m, 200m², 49,96m², taxas/recuos/carimbo) | Rascunho tabular com `loteamento`, `sourceFiles` (1 arquivo, `pageCount: 1`) e 1 item completo sem `geometry` | PDF corrompido/vazio/sem dados -> `PdfExtractionError` |
| PDF_MULTIPAGE | PDF com 3 páginas (lotes distintos) | Agrega todos os itens em `items` com `sourcePage` 1..3 e `pageCount: 3` | Páginas vazias são ignoradas; se 0 itens -> `PdfExtractionError` |
| PDF_MULTI_FILE_SHARED_DRAFT | 2+ arquivos PDF com mesmo `metadata.draftId` no Storage | Merge transacional idempotente de `items`, `sourceFiles` e `loteamento` em `loteamentos_drafts/{draftId}` | Erro em um arquivo registra `status: 'erro'` em `sourceFiles` sem derrubar itens válidos já existentes |
| PDF_OCR_FALLBACK | Página PDF sem texto vetorial suficiente | Rasteriza e executa `pytesseract.image_to_string` como fallback | OCR indisponível -> loga e trata ausência de texto com `PdfExtractionError` |
| DXF_DWF_TABULAR | Arquivos `.dxf` e `.dwf` (inclusive fixtures de referência) | Emite `items` tabulares com `quadra`, `nome`, `frenteM`, `profundidadeM`, `areaTerrenoM2` (via `minimum_rotated_rectangle` e escala de unidades), sem `geometry` | Contornos inválidos/ausentes -> `DxfExtractionError` / `DwfExtractionError` |
| CONSOLIDATE_NEW_OR_TARGET | Rascunho tabular aprovado com ou sem `targetLoteamentoId` | Cria novo loteamento (se `targetLoteamentoId` nulo) ou mescla no existente, cria quadras, lotes (com resumo inicial 0/5) e 5 etapas padrão por lote | Sem itens ou sem `construtoraId` -> `ValueError` |
| CONSOLIDATE_BATCH_500 | Consolidação com >= 100 lotes (> 500 documentos incluindo 5 etapas/lote) | Divide gravações em múltiplos `WriteBatch`es de até 500 operações | Falha de batch propaga exceção mantendo rascunho para retry |

</frozen-after-approval>

## Code Map

- `functions-python/pdf_extraction.py` -- Reescrita completa para extração cadastral/dimensional de PDF (PyMuPDF + fallback OCR `pytesseract`, parser de carimbo/localização, Quadro Geral de Áreas BR, recuos e cotas lineares com tolerância de 1%)
- `functions-python/heuristics.py` -- Adição de `_polygon_dimensions` e `build_tabular_items` para emissão tabular sem geometria
- `functions-python/dxf_extraction.py` -- Adaptação para `extract_dxf_draft` emitindo contrato tabular `items`
- `functions-python/dwf_extraction.py` -- Adaptação para `extract_dwf_draft` emitindo contrato tabular `items`
- `functions-python/firestore_utils.py` -- Persistência/merge transacional tabular em `save_draft_to_firestore` e consolidação em `consolidate_approved_draft` com `targetLoteamentoId`, 5 etapas padrão e batching de 500 ops
- `functions-python/main.py` -- Suporte a `.pdf`, `.dxf` e `.dwf` em `processar_dxf`, resolução de `draftId` compartilhado, `targetLoteamentoId` e erro tabular sem GeoJSON
- `functions-python/tests/` -- Testes `pytest` atualizados e expandidos (`test_pdf_extraction.py`, `test_dxf_extraction.py`, `test_dwf_extraction.py`, `test_firestore_utils.py`, `test_consolidation_reference.py`, `test_main.py`)

## Tasks & Acceptance

- [x] Reescrever `functions-python/pdf_extraction.py` para os 3 cenários sem geometria (PyMuPDF + fallback OCR `pytesseract`, carimbo/localização, Quadro Geral de Áreas BR, recuos e cotas lineares com tolerância de 1%).
- [x] Adaptar `functions-python/dxf_extraction.py` e `functions-python/dwf_extraction.py` (via `heuristics.build_tabular_items`) para emitir o contrato tabular `items` com `frenteM`, `profundidadeM` e `areaTerrenoM2` sem GeoJSON/geometry.
- [x] Atualizar `functions-python/firestore_utils.py` e `functions-python/main.py` para merge transacional de múltiplos PDFs no mesmo `draftId`, suporte a `targetLoteamentoId`, e consolidação atômica criando as 5 etapas padrão (`muro`, `cinza1`, `cinza2`, `cinza3`, `branca`, IDs `{loteId}_{tipo}`) e resumo inicial em `WriteBatch`es de até 500 operações.
- [x] Cobrir todos os cenários com `pytest` em `functions-python/tests/` e validar 100% de passagem.

## Implementation & Verification Notes

- **Testes executados:** `/Users/usuario/obras/functions-python/venv/bin/pytest -v` em `functions-python/` -> **136 passed, 5 warnings in 8.08s** (100% de aprovação).
- **Cobertura validada:**
  - PDF de 1 página equivalente à referência (Lote 31 da Quadra 28, Loteamento Jardim Botanico, Rua Sandoval Wanderley, s/n, Estivas, Extremoz/RN, 10x20m, 200m², 49,96m², taxas 24,98%/56,23%, coeficiente 0,24, áreas permeável/impermeável, recuos 5,05/5,94/1,43/1,43, CNPJ, CREA e data `outubro/26`).
  - PDF multipágina (3 páginas agregadas em `items` com `sourcePage` 1..3) e fallback OCR (`pytesseract`) em página sem texto vetorial.
  - Merge transacional idempotente de múltiplos arquivos PDF compartilhando o mesmo `draftId` e retenção de itens válidos em falha parcial de arquivo subsequente.
  - Extração tabular DXF e DWF (inclusive fixtures de referência com 245 válidos, 18 ambíguos e 23 quadras, além de conversão de `$INSUNITS` em mm para metros).
  - Consolidação criando novo loteamento e mesclando em `targetLoteamentoId` existente, materializando as 5 etapas padrão e respeitando o teto de 500 operações por `WriteBatch` (602 ops em 2 batches no teste unitário e 3+ batches no fixture de referência).

## Review Triage Log

- **Revisão adversarial (#16, `story2-reviewer`) — Veredito: `APROVADO`** (commit `83b8de7`):
  - Escopo e integridade validados (13 arquivos em `functions-python/` + story `.md`, zero persistência de `geometry`).
  - Contratos de dados validados para `pdf_extraction.py`, `dxf_extraction.py`, `dwf_extraction.py`, `heuristics.py`, `firestore_utils.py` e `main.py` (3 cenários PDF, OCR fallback, tolerância 1%, merge transacional por `draftId`, `targetLoteamentoId`, 5 etapas padrão e `MAX_BATCH_OPERATIONS = 500`).
  - Verificação independente: `pytest -q` -> `136 passed, 5 warnings in 8.49s`.
  - Aderência ponta-a-ponta com Story 4 (Flutter + `firestore.rules` + `storage.rules`) confirmada em #17.
