---
title: 'Importação e extração nativa de loteamentos em DWF (coexistindo com DXF)'
type: 'feature'
created: '2026-11-06'
status: 'done'
route: 'dispatch'
baseline_commit: '6f04df9d2206c5db32b98e29cb2e7a89beb4cc0a'
review_loop_iteration: 0
context:
  - '_bmad-output/implementation-artifacts/spec-importacao-dxf-loteamento.md'
  - '_bmad-output/implementation-artifacts/spec-refinamento-extrator-dxf-loteamento.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O fluxo de importação de loteamentos hoje aceita e extrai apenas arquivos `.dxf`, rejeitando pacotes `.dwf` como `LOTEAMENTO_HR_R13A-Model.dwf` na UI Flutter, no repositório, nas regras do Storage e na Cloud Function `processar_dxf`.

**Approach:** Habilitar a importação de `.dwf` em coexistência com `.dxf` (UI, repositório, `storage.rules` e `processar_dxf`) e implementar um extrator nativo em Python (`dwf_extraction.py`) que valida o pacote ZIP DWF 6.0, decodifica o stream vetorial `application/x-w2d` (`W2D V06.00`) sem depender de binários externos e reutiliza o pipeline geométrico/heurístico existente para produzir o mesmo rascunho GeoJSON revisável.

## Boundaries & Constraints

**Always:** Aceitar `.dxf` (`application/dxf`) e `.dwf` (`application/x-dwf`, case-insensitive na extensão) na UI, no repositório, em `storage.rules` e no gatilho `processar_dxf`; gravar `sourceFormat: 'dxf'` ou `sourceFormat: 'dwf'` conforme a extensão enviada; validar no DWF o container ZIP, limite descompactado (`<= 200 MB`), `manifest.xml` e existência do recurso `application/x-w2d`; transformar coordenadas lógicas W2D para coordenadas do modelo via matriz `(Units ...)` e alimentar `_classify`, `associate_lotes_to_quadras` e `build_geojson` mantendo 100% do contrato GeoJSON (`tipo`, `nome`, `quadra`, `status`) e do fluxo de aprovação/consolidação.

**Never:** Aceitar `.dwg`, `.pdf` ou outros formatos na importação de loteamentos; exigir conversor ou binário externo (`DWF_CONVERTER_COMMAND`) para extrair DWF; remover ou quebrar o suporte a `.dxf` existente; publicar entidades definitivas sem aprovação humana; alterar `firestore_utils.py`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| DWF_REFERENCIA_VALIDO | Upload de `LOTEAMENTO_HR_R13A-Model.dwf` (DWF 6.0 com seção W2D) | Gera rascunho `status: 'pendente'`, `sourceFormat: 'dwf'`, com 23 quadras (`Q-01` a `Q-23`, incluindo `Q-19`), 245 lotes `valido` e 18 `ambiguo` | N/A |
| DXF_CONTINUA_VALIDO | Upload de `.dxf` válido | Continua gerando rascunho `status: 'pendente'`, `sourceFormat: 'dxf'` sem regressão | N/A |
| FORMATO_NAO_SUPORTADO | Arquivo `.pdf`, `.dwg`, `.txt` ou extensão/MIME divergentes | Rejeitado na UI/repositório/Storage rules e ignorado no gatilho `processar_dxf` | `ArgumentError` no app; bloqueio nas rules; log estruturado no gatilho |
| DWF_CORROMPIDO_OU_SEM_W2D | Arquivo `.dwf` vazio, não-ZIP, soma descompactada `> 200 MB`, sem `manifest.xml` ou sem recurso `application/x-w2d` válido | Nenhuma entidade definitiva; rascunho terminal `status: 'erro'`, `sourceFormat: 'dwf'` | `DwfExtractionError` capturado em `processar_dxf` com `processingError` descritivo |
| DWF_SEM_LOTES | Pacote DWF/W2D válido porém sem polilinhas classificáveis como lote | Não cria rascunho aprovável | `DwfExtractionError` gera rascunho terminal `status: 'erro'` |

</frozen-after-approval>

## Code Map

- `dwg_dxf/LOTEAMENTO_HR_R13A-Model.dwf` (novo fixture, cópia do DWF anexado) -- pacote ZIP DWF 6.0 AutoCAD 2024 com `manifest.xml` e seção `application/x-w2d` (`115.170` bytes, 333 polilinhas e 2.888 textos).
- `functions-python/dwf_extraction.py` (novo) -- validação do pacote ZIP DWF (`MAX_DWF_UNCOMPRESSED_BYTES = 200 * 1024 * 1024`, manifesto XML e recurso `application/x-w2d`), parser nativo do stream `W2D V06.00` (opcodes ASCII `(...)` incluindo matriz 4x4 de `Units`, opcodes binários `O` origin 32-bit, `0x10` polilinhas 16-bit relativas, `0x14`/`0x0c`/`0x92` atualização de origem, `c`/`0x03` cor efetiva, `0x06` fonte, `x` texto 32-bit relativo com strings `'...'` Latin-1 e `{...}` UTF-16LE), adaptando para entidades compatíveis com `_classify`, `associate_lotes_to_quadras` e `build_geojson`. Exporta `DwfExtractionError(ValueError)` e `extract_dwf_geojson(filepath: str) -> dict`.
- `functions-python/heuristics.py:15` -- ajustar `DECIMAL_REGEX` para aceitar prefixo opcional de diâmetro (`^[Øø⌀]?\d+([.,]\d+)+$`), evitando que cotas como `'Ø18.00'` presentes no W2D/DXF completo sejam tratadas como candidatas a nome de lote.
- `functions-python/main.py:21,139-225` -- em `processar_dxf`, aceitar `.dxf` e `.dwf`, definir sufixo temporário e `sourceFormat` (`'dxf'` ou `'dwf'`), rotear `.dwf` para `extract_dwf_geojson` e capturar `(DxfExtractionError, DwfExtractionError)` gravando `status: 'erro'` com o `sourceFormat` correspondente.
- `app/lib/src/features/loteamentos/data/loteamentos_import_repository.dart:55-101` -- aceitar `.dxf` e `.dwf` em `loteamentoNameFromFilename`, definir `contentType` como `'application/dxf'` para `.dxf` e `'application/x-dwf'` para `.dwf` via helper `contentTypeFromFilename`, e atualizar mensagem de `ArgumentError`.
- `app/lib/src/features/loteamentos/presentation/loteamento_import_screen.dart:55-135` -- permitir `allowedExtensions: ['dxf', 'dwf']`, validar `.dxf`/`.dwf` no `onDropFile` e atualizar títulos/textos para `DXF ou DWF`.
- `app/lib/src/features/loteamentos/presentation/loteamentos_list_screen.dart:42` -- atualizar tooltip para `'Importar DXF/DWF'`.
- `storage.rules:44-48` -- permitir `create` em `/loteamentos_drafts_uploads/{uid}/{filename}` quando `(request.resource.contentType == 'application/dxf' && filename.matches('.*\\.([dD][xX][fF])$')) || (request.resource.contentType == 'application/x-dwf' && filename.matches('.*\\.([dD][wW][fF])$'))`.
- `functions-python/tests/test_dwf_extraction.py` (novo) e `functions-python/tests/test_main.py` -- testes unitários e de integração com o fixture DWF real e pacotes DWF sintéticos/inválidos.
- `app/test/src/features/loteamentos/data/loteamentos_import_repository_test.dart` e `functions/test/security-rules.test.cjs:560-599` -- testes cobrindo coexistência `.dxf` + `.dwf` e bloqueio de combinações inválidas.

## Tasks & Acceptance

**Execution:**
- [x] `dwg_dxf/LOTEAMENTO_HR_R13A-Model.dwf` e `functions-python/heuristics.py` -- versionar o fixture DWF anexado em `dwg_dxf/LOTEAMENTO_HR_R13A-Model.dwf` e ajustar `DECIMAL_REGEX` em `heuristics.py` para ignorar prefixo `Ø`/`ø`/`⌀` em cotas decimais -- garante que o fixture real esteja disponível para a suíte e que `'Ø18.00'` não contamine candidatos a nome de lote.
- [x] `functions-python/dwf_extraction.py` -- implementar `DwfExtractionError`, validação de pacote DWF (ZIP, limite descompactado de 200 MB, `manifest.xml` e entrada `application/x-w2d`) e parser nativo `W2D V06.00` conectado a `_classify`, `associate_lotes_to_quadras` e `build_geojson` -- extrai quadras, lotes e textos de arquivos `.dwf` sem conversores externos.
- [x] `functions-python/main.py` -- atualizar `processar_dxf` para aceitar `.dxf` e `.dwf`, selecionar o extrator e `sourceFormat` (`'dxf'`/`'dwf'`) conforme a extensão e tratar `DwfExtractionError` como erro terminal no Firestore -- integra a extração DWF ao gatilho do Storage.
- [x] `functions-python/tests/test_dwf_extraction.py`, `functions-python/tests/test_heuristics.py` e `functions-python/tests/test_main.py` -- testar extração do `LOTEAMENTO_HR_R13A-Model.dwf` (23 quadras incluindo `Q-19`, 245 válidos, 18 ambíguos), pacotes DWF sintéticos/corrompidos/sem W2D/acima do limite/sem lotes e roteamento `.dxf`/`.dwf` em `processar_dxf` -- cobre toda a matriz de I/O no backend.
- [x] `app/lib/src/features/loteamentos/data/loteamentos_import_repository.dart`, `app/lib/src/features/loteamentos/presentation/loteamento_import_screen.dart`, `app/lib/src/features/loteamentos/presentation/loteamentos_list_screen.dart` e `app/test/src/features/loteamentos/data/loteamentos_import_repository_test.dart` -- aceitar `.dxf` e `.dwf` com MIME correspondente (`application/dxf` e `application/x-dwf`) e atualizar textos/testes -- habilita seleção, drag-and-drop e upload dos dois formatos no app.
- [x] `storage.rules` e `functions/test/security-rules.test.cjs` -- permitir upload de `.dxf` (`application/dxf`) e `.dwf` (`application/x-dwf`) casando cada MIME com sua extensão e atualizar o teste 7.4 -- mantém a segurança de upload no Storage para ambos os formatos.

**Acceptance Criteria:**
- Given o arquivo `dwg_dxf/LOTEAMENTO_HR_R13A-Model.dwf`, when processado por `extract_dwf_geojson`, then retorna `FeatureCollection` com 23 quadras (`Q-01` a `Q-23`, incluindo `Q-19`), 245 lotes `valido` e 18 lotes `ambiguo`, compatível com `consolidate_approved_draft`.
- Given um upload `.dwf` ou `.dxf` em `loteamentos_drafts_uploads/{uid}/{filename}`, when processado pela UI, `storage.rules` e `processar_dxf`, then é aceito com seu respectivo `contentType` e `sourceFormat` (`'dwf'` ou `'dxf'`), enquanto `.pdf`/`.dwg` ou pares MIME/extensão trocados são rejeitados.
- Given um arquivo `.dwf` corrompido, sem seção `application/x-w2d` ou sem lotes, when processado por `processar_dxf`, then grava rascunho terminal `status: 'erro'` com `sourceFormat: 'dwf'` e `processingError` preenchido.

## Implementation Notes

- `functions-python/dwf_extraction.py`: implementado extrator nativo de pacotes DWF 6.0 sem binários externos (`DwfExtractionError`, `extract_dwf_geojson`), validando container ZIP, orçamento de leitura descompactada (`<= 200 MB`), `manifest.xml` e streams `application/x-w2d`, decodificando opcodes ASCII e binários do stream `W2D V06.00` e adaptando polilinhas/textos para `_classify`, `associate_lotes_to_quadras` e `build_geojson`.
- `functions-python/heuristics.py`: `DECIMAL_REGEX` ajustado para `^[Øø⌀]?\d+([.,]\d+)+$`, descartando cotas de diâmetro como `'Ø18.00'`.
- `functions-python/main.py`: `processar_dxf` aceita `.dxf` e `.dwf`, define `sourceFormat` (`'dxf'`/`'dwf'`) e trata `(DxfExtractionError, DwfExtractionError)` como falha terminal no Firestore.
- App Flutter (`loteamentos_import_repository.dart`, `loteamento_import_screen.dart`, `loteamentos_list_screen.dart`) e `storage.rules`: habilitada coexistência de `.dxf` (`application/dxf`) e `.dwf` (`application/x-dwf`), rejeitando combinações MIME/extensão trocadas e outros formatos.

## Spec Change Log

## Review Triage Log

- EC1 (`dwf_extraction.py:_read_member_bounded` / `_read_w2d_streams` — exceções de descompressão/CRC/criptografia de membro ZIP escapam de `DwfExtractionError`) — `medium` (rota: `patch`) — Verificado: `zf.open` e `stream.read` estavam fora do bloco `try/except`, permitindo que `zlib.error`, `BadZipFile`, `EOFError`, `RuntimeError` ou `NotImplementedError` escapassem sem gravar estado terminal `status: 'erro'`.
- EC2 (`dwf_extraction.py:_read_ascii_opcode` — strings binárias UTF-16LE `{...}` dentro de opcodes ASCII `(...)`) — `medium` (rota: `patch`) — Verificado: `_read_ascii_opcode` não delegava `{` para `_read_wt_string`, podendo encerrar o opcode prematuramente se os bytes UTF-16LE contivessem `0x29` (`)`) ou `0x27` (`'`).
- EC3 (`dwf_extraction.py:_parse_w2d_stream` — matriz `(Units ...)` com rotação de 90° ou termos fora da diagonal) — `medium` (rota: `patch`) — Verificado: `_parse_w2d_stream` ignorava `m01`/`m10` e exigia diagonal não nula; inverter a matriz 2×2 completa pelo determinante `det = m00*m11 - m01*m10` suporta rotações mantendo o caso diagonal idêntico.
- BH1 (`dwf_extraction.py:_UNITS_MATRIX_RE` e `_parse_w2d_stream` — descarte dos termos fora da diagonal `m01`/`m10` na matriz `Units`) — `medium` (rota: `patch`, agrupado com EC3) — Mesma causa-raiz de EC3; resolvido pela inversão da matriz afim 2×2 completa.
- BH2 (`dwf_extraction.py:_parse_w2d_stream` — contagem estendida de vértices em `0x10`/`0x14` quando `count == 0`) — `medium` (rota: `patch`) — Verificado: na especificação WHIP! `WT_Point_Set`, o byte `0` seguido de `uint16` codifica `256 + uint16` vértices; sem somar `256`, polilinhas com `>= 256` vértices desalinham o stream em 1.024 bytes.
- BH3 (`dwf_extraction.py:_read_ascii_opcode` e `_UNITS_MATRIX_RE` — strings `{...}` em opcodes ASCII e parênteses no nome da unidade em `_UNITS_MATRIX_RE`) — `medium` (rota: `patch`, agrupado com EC2) — Verificado: delegar `{` a `_read_wt_string` e permitir parênteses antes da matriz 4×4 em `_UNITS_MATRIX_RE` resolve ambos os casos.
- BH4 (`dwf_extraction.py:extract_dwf_geojson` — escala de unidades em `(Units '<unidade>' ...)`) — `maybe-false` (rota: `defer`, severidade `medium` não verificada) — No DWF de referência a matriz `Units` já converte o espaço lógico W2D para metros; confirmar se exportações reais do AutoCAD produzem coordenadas pós-matriz em mm/cm requer inspecionar DWFs exportados nessas unidades.
- BH5 (`dwf_extraction.py:_read_w2d_streams` — concatenação de múltiplos recursos `application/x-w2d`) — `maybe-false` (rota: `defer`, severidade `medium` não verificada) — O fixture possui apenas uma seção `ePlot` (`Model`); definir heurística de seleção entre `Model` e `Layout` exige amostras reais de pacotes DWF multi-prancha.
- BH6 (`dwf_extraction.py:_parse_w2d_stream` — opcodes W2D adicionais como polilinha 32-bit `0x50` ou geometria ASCII) — `maybe-false` (rota: `defer`, severidade `medium` não verificada) — O parser falha explicitamente com `DwfExtractionError` terminal se encontrar opcode desconhecido; avaliar a ocorrência real de `0x50` ou `(PolyLine ...)` requer novos fixtures exportados pelo AutoCAD.
- BH7 (`dwf_extraction.py:_parse_w2d_stream` — polilinhas `0x10` abertas com `>= 3` pontos fechadas em `ezdxf_entity_to_polygon`) — `false` (rejeitado) — No fixture de referência (`LOTEAMENTO_HR_R13A-Model.dwf` e `.dxf`), diversos lotes reais foram desenhados com 3 ou 4 vértices sem repetir o primeiro ponto (`pts[0] != pts[-1]`), sendo intencionalmente fechados por `ezdxf_entity_to_polygon` e filtrados por área mínima e cor predominante.
- BH8 (`dwf_extraction.py:_read_w2d_streams` — `ET.fromstring` sem bloqueio de `<!DOCTYPE>`/`<!ENTITY>`) — `medium` (rota: `patch`) — Verificado: `xml.etree.ElementTree.fromstring` expande entidades internas declaradas em `<!DOCTYPE>`, expondo a função a XML bomb; rejeitar `<!DOCTYPE`/`<!ENTITY` antes do parse bloqueia o vetor.
- BH9 (`loteamento_import_screen.dart:107` — checagem manual duplicada de extensão no `onDropFile`) — `low` (rota: `patch`) — Verificado: `onDropFile` validava apenas o sufixo em vez de usar `LoteamentosImportRepository.loteamentoNameFromFilename(name)`, aceitando `.dwf` sem nome-base no drop.
- VG1 (`loteamento_import_screen.dart:55-59,107-119` — ausência de teste de widget para `DropzoneView`/`FilePicker` com `.dwf`) — `medium` (pré-verificado por `verification-gap`, rota: `defer`) — `DropzoneView` exige runtime Web e `FilePicker.pickFiles` é chamado estaticamente, enquanto a validação de extensão e MIME já está coberta em `loteamentos_import_repository_test.dart`.

## Design Notes

No stream `W2D V06.00`, cada ponto relativo atualiza o acumulador lógico `(ox, oy)` em 32 bits antes de aplicar a inversa da matriz afim 4×4 declarada em `(Units '' ((sx ...)(... sy ...)(...)(tx ty 0 1)))`: `x_world = (ox - tx) / sx`, `y_world = (oy - ty) / sy`. Polilinhas vêm do opcode `0x10` (`POLYLINE_POLYGON_16R`) e textos do opcode `0x78` (`x`, `DRAW_TEXT` com `dx, dy` `int32` seguidos de `'...'` Latin-1 ou `{nchars_u32 + utf16le}`).

## Verification

**Commands:**
- `cd functions-python && ./venv/bin/python -m pytest tests/test_dwf_extraction.py tests/test_dxf_extraction.py tests/test_heuristics.py tests/test_main.py -q` -- expected: todos os testes passam.
- `cd app && flutter analyze lib/src/features/loteamentos test/src/features/loteamentos && flutter test test/src/features/loteamentos/data/loteamentos_import_repository_test.dart` -- expected: zero diagnósticos e testes passam.

