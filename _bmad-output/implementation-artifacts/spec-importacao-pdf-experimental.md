---
title: 'Importação experimental de loteamento por PDF'
type: 'feature'
created: '2026-09-28'
status: 'in-progress'
route: 'dispatch'
review_loop_iteration: 0
context: []
baseline_commit: 'f4081b4aad784ade28e02de80d2688881722d1b0'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A importação atual aceita somente DXF. O usuário precisa testar o PDF `00-LOTEAMENTO_HR_R13A_CLUSTER_A_QUADRAS_E_LOTES_R2013.pdf` sem publicar dados em produção e sem substituir o fluxo CAD existente.

**Approach:** Disponibilizar uma entrada de PDF marcada como experimental, submetê-la ao mesmo armazenamento e criar um rascunho revisável no Firestore. O backend aproveitará textos e desenho vetorial quando existirem e, para plantas exportadas como imagem como o anexo, aplicará OCR e vetorização de contornos antes de produzir o GeoJSON consumido pelo canvas. O rascunho permanecerá separado até a aprovação explícita.

## Boundaries & Constraints

**Always:** Preservar a importação DXF sem mudança de comportamento; usar o nome-base do PDF como nome do loteamento; enviar `construtoraId` e `loteamentoName` como metadados; criar apenas rascunho pendente antes da revisão; para PDF rasterizado, registrar a origem experimental e marcar como pendência qualquer lote ou quadra cuja identificação/geometria não possa ser determinada com segurança.

**Never:** Não executar OCR, vetorização de imagem ou consolidação de documentos no cliente; não transformar PDFs rasterizados em registros definitivos silenciosamente; não publicar loteamentos sem passar pela tela de revisão e pela ação já existente de aprovação definitiva.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| PDF vetorial válido | PDF de planta com paths e textos extraíveis | Upload cria rascunho GeoJSON e abre a revisão | Lotes sem identificação seguem como pendência existente |
| PDF rasterizado | Página de planta exportada como imagem | OCR e vetorização produzem rascunho somente para contornos confiáveis | Elementos incertos permanecem como pendência; ausência de contornos cancela o rascunho |
| Arquivo inválido ou grande | PDF corrompido ou acima de 50 MiB | Não inicia processamento | Mensagem e log identificam a causa; temporário é removido |
| DXF existente | Upload `.dxf` | Mantém caminho, tipo e processamento atuais | Sem regressão no fluxo DXF |

</frozen-after-approval>

## Code Map

- `app/lib/src/features/loteamentos/presentation/loteamento_import_screen.dart` -- restringe seleção e drop a `.dxf`; deve indicar e encaminhar a opção experimental de PDF.
- `app/lib/src/features/loteamentos/data/loteamentos_import_repository.dart` -- centraliza upload, nome-base e metadados; deve generalizar a validação e o `contentType`, preservando `uploadDxf` para compatibilidade.
- `functions-python/main.py` -- `processar_dxf` filtra extensão, baixa o objeto, transforma entidades e persiste o rascunho; precisa encaminhar PDFs a um extrator dedicado com OCR/vetorização sem afetar a rota DXF.
- `functions-python/geometry_utils.py` e `functions-python/heuristics.py` -- fornecem associação espacial e montagem GeoJSON a reutilizar após a extração de paths/textos do PDF.
- `functions-python/firestore_utils.py` -- persiste o rascunho e consolida apenas após aprovação; não deve materializar no estágio experimental.
- `app/test/src/features/loteamentos/data/loteamentos_import_repository_test.dart` e `functions-python/tests/test_main.py` -- cobertura atual de upload DXF e trigger Storage; adicionar casos PDF e regressão DXF.
- `functions-python/requirements.txt` -- dependências da função; incluir leitor de PDF, OCR e visão computacional necessários ao experimento.

## Tasks & Acceptance

**Execution:**
- [ ] `app/lib/src/features/loteamentos/presentation/loteamento_import_screen.dart` e `app/lib/src/features/loteamentos/data/loteamentos_import_repository.dart` -- permitir seleção/drop de PDF experimental, metadados corretos e nome-base, sem alterar a rota DXF.
- [ ] `functions-python/main.py`, novo extrator PDF e `functions-python/requirements.txt` -- reconhecer PDF, extrair paths/textos quando disponíveis ou aplicar OCR/vetorização de imagem, gerar o mesmo GeoJSON e salvar um rascunho somente quando houver lotes utilizáveis.
- [ ] `functions-python/tests/test_main.py` e testes Flutter de repositório -- cobrir PDF válido, PDF sem geometria aproveitável, validação de extensão/tipo e regressão de DXF.

**Acceptance Criteria:**
- Given uma planta PDF dentro do limite, inclusive exportada como imagem como o anexo, when o usuário selecionar o arquivo na tela de importação, then o sistema criará um rascunho pendente e abrirá a revisão sem publicar quadras ou lotes.
- Given um PDF que não ofereça dados suficientes para gerar lotes revisáveis, when o processamento terminar, then não existirá rascunho vazio e o erro será rastreável nos logs.
- Given um rascunho criado pelo PDF, when o usuário corrigir pendências e aprová-lo definitivamente, then ele utilizará a consolidação existente para criar loteamento, quadras e lotes.
- Given um arquivo DXF, when ele for enviado após a mudança, then o upload e o processamento seguirão o contrato atual.

## Implementation Notes

- A inspeção inicial do anexo mostrou uma página de planta exportada pelo Autodesk Viewer e um recurso de imagem. A extração deve preferir paths/textos reais, usar OCR/vetorização quando necessário e nunca inferir precisão CAD a partir da prévia visual.

## Spec Change Log

## Review Triage Log

## Design Notes

O PDF deve convergir para o contrato de rascunho atual (`features` GeoJSON e metadados), não para um segundo formato. Isso preserva canvas, revisão, aprovação e consolidação e limita o experimento à etapa de extração.

## Verification

**Commands:**
- `functions-python/.venv/bin/pytest functions-python/tests/test_main.py functions-python/tests/test_firestore_utils.py` -- expected: processamento PDF e consolidação existente passam.
- `cd app && flutter analyze lib/src/features/loteamentos && flutter test test/src/features/loteamentos/data/loteamentos_import_repository_test.dart` -- expected: sem diagnósticos e uploads DXF/PDF cobertos.
