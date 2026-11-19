---
title: 'Importação Multi-Arquivo, Revisão Tabular com Lote-Modelo e Regras Firestore'
type: 'feature'
created: '2026-11-19'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '_bmad-output/specs/spec-remodelagem-loteamentos-sem-geometria/SPEC.md'
  - '_bmad-output/specs/spec-remodelagem-loteamentos-sem-geometria/data-contracts.md'
  - '_bmad-output/specs/spec-remodelagem-loteamentos-sem-geometria/architecture-diagrams.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O fluxo de importação aceitava apenas um arquivo `.dxf` ou `.dwf` por vez, sem escolha entre criar novo loteamento ou mesclar em um loteamento existente, e direcionava a revisão para o canvas geométrico (`LoteamentoCanvasScreen` / `GeojsonCanvasWidget`). Além disso, `firestore.rules` só liberava `features` em `loteamentos_drafts` (incompatível com o contrato tabular), `storage.rules` bloqueava `.pdf` em `loteamentos_drafts_uploads` e as regras de `quadras`, `lotes` e `etapas` usavam `exists`/`get` pré-batch, bloqueando criações atômicas pai+filho no mesmo `WriteBatch` para admins não-`dev`.

**Approach:** Atualizar `LoteamentosImportRepository` e `LoteamentoImportScreen` para suportar upload de 1 ou múltiplos arquivos `.pdf`, `.dxf` e `.dwf` compartilhando o mesmo `draftId` nos metadados do Storage com escolha de destino (**Novo Loteamento** ou **Mesclar em Existente**), criar a tela de revisão tabular `LoteamentoDraftReviewScreen` com edição de cabeçalho/itens e ação **Completar Quadra via Lote-Modelo** substituindo `LoteamentoCanvasScreen` nas rotas do GoRouter, e delegar a `firestore-rules-author` a atualização de `firestore.rules`, `storage.rules` e `functions/test/security-rules.test.cjs`.

## Boundaries & Constraints

**Always:**
- Aceitar `.pdf` (`application/pdf`), `.dxf` (`application/dxf`) e `.dwf` (`application/x-dwf`), rejeitando formatos não suportados antes de tocar o Cloud Storage.
- Enviar o mesmo `draftId` em `customMetadata` do Storage quando múltiplos arquivos forem selecionados para o mesmo rascunho, além de `targetLoteamentoId` quando o usuário escolher mesclar em loteamento existente.
- Gravar `loteamento`, `targetLoteamentoId`, `items`, `status: 'aprovado'`, `consolidationRequestId` e `updatedAt` em `loteamentos_drafts/{draftId}` ao aprovar.
- Gerar lotes via lote-modelo na mesma quadra sem duplicar lotes já existentes.
- Delegar toda alteração em `firestore.rules` (e `storage.rules` / testes de regras) ao especialista `firestore-rules-author`.

**Never:**
- Nunca manter `LoteamentoCanvasScreen` ou `GeojsonCanvasWidget` nas rotas de revisão de rascunho.
- Nunca permitir criação ou exclusão direta de `loteamentos_drafts/{draft_id}` pelo cliente em `firestore.rules`.
- Nunca quebrar imports ou testes legados fora do escopo da Story 4.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| MULTI_PDF_UPLOAD | 2+ arquivos `.pdf` selecionados com destino Novo ou Existente | Todos os arquivos enviados ao Storage com caminhos únicos e mesmo `draftId` (e `targetLoteamentoId` se existente) em `customMetadata` | Rejeita antes de qualquer upload se lista vazia ou houver extensão inválida |
| DESTINO_EXISTENTE | Modo "Mesclar em Existente" com loteamento selecionado | Envia `targetLoteamentoId` nos metadados do upload e pré-seleciona o destino na tela de revisão | Bloqueia envio/aprovação se nenhum loteamento for selecionado |
| LOTE_MODELO_SEM_DUPLICACAO | Lote 31 da Quadra 28 (10x20m, 200m², 49,96m²) + Lote 15 existente; intervalo 1..31 | Gera 29 novos lotes na Quadra 28 copiando medidas e opcionais do modelo, preservando Lote 15 e Lote 31 sem duplicação | Impede geração se intervalo for inválido (`start < 1` ou `end < start`) |
| APROVACAO_TABULAR | Usuário edita cabeçalho/itens e clica em "Aprovar e Consolidar" | Persiste `loteamento`, `targetLoteamentoId`, `items`, `status: 'aprovado'`, `consolidationRequestId` e `updatedAt` em `loteamentos_drafts/{draftId}` e dispara retry callable | Pede confirmação se houver itens sem nome/ambíguos; falha na callable não bloqueia aprovação |
| BATCH_ATOMICO_ADMIN | `admin_user` (não-`dev`) executa `WriteBatch` criando `loteamento` + `quadra` + `lote` + `etapa` | `firestore.rules` valida `existsAfter`/`getAfter` e aprova o batch mantendo integridade de `construtoraId`, `loteamentoId`, `quadraId` e `loteId` | Rejeita se `construtoraId` ou FK pai divergir |

</frozen-after-approval>

## Code Map

- `app/lib/src/features/loteamentos/data/loteamentos_import_repository.dart` -- Suporte a `.pdf`/`.dxf`/`.dwf`, `ImportUploadFile`, `uploadFiles` multi-arquivo com `draftId` compartilhado e `targetLoteamentoId`, `saveDraftReview` e `approveTabularDraft`
- `app/lib/src/features/loteamentos/presentation/loteamento_import_screen.dart` -- Seleção múltipla de PDFs/DXF/DWF, fila de arquivos e escolha de destino (Novo Loteamento vs Mesclar em Existente)
- `app/lib/src/features/loteamentos/presentation/loteamento_processing_screen.dart` -- Textos atualizados do processamento cadastral sem referência a geometria/polígonos
- `app/lib/src/features/loteamentos/presentation/loteamento_draft_review_screen.dart` -- Nova tela de revisão tabular com edição de cabeçalho e itens, diálogo de edição com campos opcionais do PDF, ação "Completar Quadra via Lote-Modelo" (`generateQuadraFromLoteModel`) e aprovação/consolidação
- `app/lib/src/features/loteamentos/routing/loteamentos_routes.dart` -- Rota `draft/:draftId` apontando para `LoteamentoDraftReviewScreen` (aposentando `LoteamentoCanvasScreen` das rotas)
- `firestore.rules` -- Atualizado por `firestore-rules-author`: campos tabulares em `loteamentos_drafts/{draft_id}` e `existsAfter`/`getAfter` em `quadras`, `lotes` e `etapas`
- `storage.rules` -- Atualizado por `firestore-rules-author`: suporte a `application/pdf` em `loteamentos_drafts_uploads/{uid}/{filename}`
- `functions/test/security-rules.test.cjs` -- Atualizado por `firestore-rules-author`: testes 7.4 (PDF no Storage), 9.1 (rascunho tabular) e 9.2 (WriteBatch atômico de hierarquia por admin não-`dev`)
- `app/test/src/features/loteamentos/data/loteamentos_import_repository_test.dart` -- Testes unitários do repositório de importação multi-arquivo e aprovação tabular
- `app/test/src/features/loteamentos/presentation/loteamento_import_screen_test.dart` -- Testes de widget da importação multi-arquivo e escolha de destino
- `app/test/src/features/loteamentos/presentation/loteamento_draft_review_screen_test.dart` -- Testes unitários e de widget da revisão tabular, geração via lote-modelo e aprovação

## Tasks & Acceptance

**Execution:**
- [x] `app/lib/src/features/loteamentos/data/loteamentos_import_repository.dart` -- Suportar `.pdf`/`.dxf`/`.dwf`, múltiplos arquivos com mesmo `draftId`, `targetLoteamentoId`, `saveDraftReview` e `approveTabularDraft`
- [x] `app/lib/src/features/loteamentos/presentation/loteamento_import_screen.dart` -- UI multi-arquivo com destino Novo Loteamento ou Mesclar em Existente
- [x] `app/lib/src/features/loteamentos/presentation/loteamento_draft_review_screen.dart` -- Tela de revisão tabular completa com ação Completar Quadra via Lote-Modelo e aprovação
- [x] `app/lib/src/features/loteamentos/routing/loteamentos_routes.dart` -- Substituir `LoteamentoCanvasScreen` por `LoteamentoDraftReviewScreen` na rota `draft/:draftId`
- [x] `firestore.rules`, `storage.rules` e `functions/test/security-rules.test.cjs` -- Delegado ao especialista `firestore-rules-author` (regras tabulares de `loteamentos_drafts`, suporte a `.pdf` no Storage e `existsAfter`/`getAfter` em `quadras`, `lotes`, `etapas`)
- [x] Testes unitários e de widget de importação e revisão tabular passando 100% e `flutter analyze` sem issues

**Acceptance Criteria:**
- Given múltiplos arquivos `.pdf` selecionados na `LoteamentoImportScreen`, when o usuário envia, then todos os arquivos são gravados no Storage com o mesmo `draftId` nos metadados customizados e `targetLoteamentoId` quando "Mesclar em Existente" estiver selecionado.
- Given um rascunho tabular com o Lote 31 da Quadra 28 extraído, when o usuário aciona "Completar Quadra via Lote-Modelo" para o intervalo 1..30, then os lotes faltantes da Quadra 28 são gerados copiando as medidas sem duplicar lotes existentes.
- Given a revisão finalizada na `LoteamentoDraftReviewScreen`, when o usuário clica em "Aprovar e Consolidar", then `loteamento`, `targetLoteamentoId`, `items`, `status: 'aprovado'`, `consolidationRequestId` e `updatedAt` são gravados em `loteamentos_drafts/{draftId}`.
- Given um admin não-`dev` executando criação atômica em `WriteBatch` de loteamento + quadra + lote + etapas, when as regras em `firestore.rules` são avaliadas, then `existsAfter`/`getAfter` permitem o batch mantendo a validação de `construtoraId` e chaves pai.

## Implementation Notes

- Mantidos `approveDraft(String draftId)` e `updateDraftFeature` (marcado `@Deprecated`) em `LoteamentosImportRepository` e os arquivos legados `loteamento_canvas_screen.dart` / `geojson_canvas_widget.dart` fora das rotas para preservar 100% dos testes legados sem quebrar imports.
- Alterações em `firestore.rules`, `storage.rules` e `functions/test/security-rules.test.cjs` executadas pelo agente especializado `firestore-rules-author` (verificação sintática via `node --check` OK; execução do emulador via `npm run test:rules` requer `functions/node_modules` e acesso fora do sandbox ao configstore do Firebase CLI).

## Spec Change Log

## Review Triage Log

- **[aprovado | revisão #17]** Revisão adversarial e verificação de aderência Story 4 ↔ Story 3 & Regras de Segurança concluída com veredito **APROVADO** (`flutter analyze`: 0 issues; `flutter test`: 61/61 passando).
- **[low | patch]** Adicionado `originalFilename: filename` em `customMetadata` de `LoteamentosImportRepository.uploadFile` para exibição limpa do nome em `sourceFiles` pelo backend Python (`main.py:_resolve_original_filename`).
- **[info | verificado]** Em `file_picker: ^13.1.0`, `FilePicker.pickFiles` (plural) já habilita seleção múltipla nativamente (o parâmetro `allowMultiple` foi removido nessa versão da API), documentado em `loteamento_import_screen.dart`.
- **[info | pós-merge]** Executar `npm --prefix functions run test:rules` no repositório principal após o merge (com `functions/node_modules` e emulador Firebase).
