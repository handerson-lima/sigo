---
title: 'Importação exclusiva de loteamento por DWF'
type: 'feature'
created: '2026-09-28'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
context: []
baseline_commit: 'f1961dddf700ef53f143c27cfcb29661fce418af'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A importação de loteamentos aceita DXF e PDF, mas o arquivo de referência agora é `LOTEAMENTO_HR_R13A-Model.dwf`. Nesta fase, nenhum outro formato deve poder iniciar a criação de loteamento, quadras e lotes.

**Approach:** Tornar DWF o único contrato de entrada, extraindo sua planta para o mesmo rascunho GeoJSON revisável e reutilizando a aprovação e consolidação já existentes para materializar loteamento, quadras e lotes.

## Boundaries & Constraints

**Always:** Aceitar somente arquivos `.dwf`; preservar a revisão humana antes da persistência definitiva; enviar `construtoraId` e nome-base do arquivo como metadados; validar tamanho, caminho e formato antes de processar; manter falhas em estado terminal rastreável para que a tela não aguarde indefinidamente.

**Never:** Aceitar DXF, DWG ou PDF na interface, no repositório ou no gatilho Storage; converter silenciosamente um desenho sem geometrias/lotes confiáveis em entidades definitivas; alterar o contrato de consolidação idempotente já adotado para rascunhos aprovados.

**Decision:** A geometria W2D interna será extraída no backend por um conversor/serviço compatível com Autodesk. O DWF continua sendo o único formato aceito no produto; a integração externa recebe o pacote internamente e devolve os dados necessários para o rascunho GeoJSON.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|---------------|---------------------------|----------------|
| DWF de referência válido | Pacote DWF AutoCAD com seção vetorial W2D | Gera GeoJSON revisável e, após aprovação, loteamento, quadras e lotes | Pendências seguem para o canvas; nenhuma publicação antes da aprovação |
| Formato não suportado | DXF, DWG, PDF ou extensão diferente | É rejeitado antes do upload ou ignorado no gatilho | Mensagem explícita ao usuário e log estruturado |
| DWF inválido/incompleto | ZIP/DWF sem manifesto ou seção gráfica aproveitável | Rascunho terminal de erro, sem entidades finais | Erro identifica arquivo e motivo; temporário é removido |
| Extração sem contornos utilizáveis | DWF válido, mas sem polígonos classificáveis | Não cria rascunho aprovável | Erro terminal evita espera infinita |

</frozen-after-approval>

## Code Map

- `dwg_dxf/LOTEAMENTO_HR_R13A-Model.dwf` -- referência real: pacote ZIP DWF 6.0 criado pelo AutoCAD 2024; o manifesto aponta a seção `application/x-w2d`.
- `app/lib/src/features/loteamentos/presentation/loteamento_import_screen.dart` -- seleção e drop hoje permitem `dxf` e `pdf`; deve restringir extensão, textos e título a DWF.
- `app/lib/src/features/loteamentos/data/loteamentos_import_repository.dart` -- valida extensão, deriva nome e faz upload; deve expor contrato DWF e `application/x-dwf` sem alterar o identificador do rascunho.
- `functions-python/main.py` -- gatilho `processar_dxf` hoje roteia DXF/PDF, baixa temporário, grava rascunho e aciona o fluxo de consolidação; deve ser renomeado/generalizado para DWF e delegar a um extrator próprio.
- `functions-python/geometry_utils.py` e `functions-python/heuristics.py` -- associação espacial e montagem GeoJSON a reutilizar caso o extrator produza polígonos e textos equivalentes; não dependem da extensão em si.
- `functions-python/pdf_extraction.py` e dependências PDF/OCR -- caminho experimental anterior a remover do fluxo de loteamento, sem tocar em outros módulos.
- `functions-python/tests/test_main.py` e `app/test/src/features/loteamentos/data/loteamentos_import_repository_test.dart` -- regressão de tipo MIME, extensão, roteamento, falha e geração de rascunho.
- `storage.rules` -- limita tamanho e autenticação do caminho de uploads; deve restringir também MIME/extensão DWF conforme as regras de Storage permitirem.

## Tasks & Acceptance

**Execution:**
- [x] `app/lib/src/features/loteamentos/presentation/loteamento_import_screen.dart`, `app/lib/src/features/loteamentos/data/loteamentos_import_repository.dart` e testes Flutter -- aceitar exclusivamente `.dwf`, usar MIME DWF e comunicar a restrição claramente.
- [x] `functions-python/main.py`, novo extrator DWF e dependências/configuração escolhidas -- validar o pacote e transformar a seção vetorial em dados que alimentem o GeoJSON existente, sem rotas DXF/PDF.
- [x] `functions-python/tests/*` e `storage.rules` -- cobrir DWF válido, rejeição de formatos antigos, arquivo inválido, ausência de geometria e segurança de upload.

**Acceptance Criteria:**
- Given o arquivo DWF de referência, when ele for enviado e a extração for bem-sucedida, then o usuário recebe um rascunho revisável que, quando aprovado, cria loteamento, quadras e lotes pelas rotinas existentes.
- Given um DXF, DWG ou PDF, when o usuário tentar selecioná-lo, then a interface o rejeita e o backend não o processa caso seja enviado diretamente ao Storage.
- Given um DWF malformado ou sem geometria aproveitável, when o processamento terminar, then não há entidades definitivas nem rascunho aprovável e o motivo fica disponível para diagnóstico.

## Implementation Notes

- A inspeção do arquivo confirma `manifest.xml` DWF 6.0 e um recurso `application/x-w2d` de 115.170 bytes. Não há DXF incorporado e `ezdxf` não lê W2D.
- A árvore local já substitui os arquivos CAD antigos pelo DWF; essa mudança autorizada será preservada.

## Spec Change Log

- 2026-09-28: implementação DWF concluída; o conversor externo é configurado por `DWF_CONVERTER_COMMAND` e deve preencher `{input}` e `{output}`.

## Review Triage Log

- false — A revisão alegou que UI, repositório, gatilho e regras não foram alterados; o diff contém mudanças nesses quatro pontos, restringindo extensão, MIME e rota a DWF.
- medium / patch — Um `Polygon` com coordenadas vazias é aceito; isso pode criar rascunho inválido. Validar anéis, fechamento e pares numéricos antes de persistir.
- medium / patch — O manifesto apenas contém a string W2D, sem confirmar o recurso ZIP apontado. Validar o `href` do recurso `application/x-w2d` contra as entradas do pacote.
- medium / patch — Um ZIP compacto pode declarar descompressão excessiva. Rejeitar pacote cuja soma descompactada exceda um limite seguro antes de ler o manifesto.
- medium / patch — Placeholder inválido em `DWF_CONVERTER_COMMAND` escapa como exceção genérica e pode gerar retries. Convertê-lo em `DwfExtractionError` terminal.
- medium / patch — O `stderr` integral do conversor pode vazar detalhes e exceder o documento Firestore. Descartar a saída do processo e usar erro genérico rastreável.
- medium / patch — Capturar stdout/stderr sem limite permite consumo excessivo de memória. Executar o conversor com ambas as saídas descartadas.
- false — A integração não fixa fornecedor/credencial porque a decisão aprovada permite conversor compatível configurado no backend; `DWF_CONVERTER_COMMAND` é o contrato operacional, e sua ausência já produz erro terminal seguro.
- low / patch — A suíte não protege a estrutura do manifesto real. Adicionar teste que valide o DWF de referência versionado.
- medium / patch — Faltam casos de geometria inválida; cobrir anéis vazios, não numéricos e não fechados para impedir GeoJSON aprovável inválido.
- medium / carried patch — A saída com coordenadas vazias permanece sem validação; mesmo defeito de geometria inválida, coberto pela correção e testes acima.
- medium / carried patch — Template de conversor vazio ou com placeholder inválido não é normalizado; mesma correção de configuração terminal acima.
- medium / carried patch — Limite descompactado do ZIP é ausente; mesma correção de defesa contra pacote expansível acima.

## Design Notes

O DWF deve convergir para o mesmo contrato GeoJSON de rascunho. Isso conserva canvas, correção humana, aprovação e a consolidação idempotente, isolando a complexidade no adaptador de extração.

## Verification

**Commands:**
- `functions-python/.venv/bin/pytest functions-python/tests/test_main.py` -- expected: rota DWF e falhas cobertas sem aceitar formatos antigos.
- `cd app && flutter analyze lib/src/features/loteamentos && flutter test test/src/features/loteamentos/data/loteamentos_import_repository_test.dart` -- expected: UI/repositório exclusivos para DWF sem diagnósticos.
