---
title: 'Story 1.1: Componente de Upload de Arquivo DXF e Sala de Espera'
type: 'feature'
created: '2026-09-26'
status: 'review'
baseline_commit: 'cb5d391c6345e645e65f4476fe59ea1f61c547ff'
route: 'dispatch'
review_loop_iteration: 0
context: ["_bmad-output/implementation-artifacts/epic-1-context.md"]
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O sistema necessita receber a planta de loteamentos enviada pelo usuário no formato CAD (.dxf) para convertê-la em GeoJSON sem sobrecarregar a interface web, garantindo a visualização contínua do estado do processamento assíncrono.

**Approach:** Criar uma interface web de upload que permita arrastar e soltar (drag and drop) arquivos DXF ou selecioná-los via file picker. Ao enviar, o arquivo é enviado diretamente ao Cloud Storage, e a interface entra em modo de espera (ouvindo a coleção Firestore `loteamentos_drafts`), exibindo uma animação até que o processamento do backend retorne o rascunho GeoJSON para avançar ao Canvas de Revisão.

## Boundaries & Constraints

**Always:**
- O Flutter deve fazer o upload diretamente para o Firebase Cloud Storage.
- A escuta pela finalização do processamento deve usar Stream/Listener no Firestore (`loteamentos_drafts`), sem polling (AD-4).
- As rotas da UI devem usar GoRouter (AD-2).

**Never:**
- Não processar, parsear ou bloquear a thread principal do Flutter web com o DXF. O frontend não executa cálculos Point-in-Polygon (AD-3).
- Não exibir barras de progresso "fakes" de carregamento de processamento; usar uma animação/micro-interação contínua ("Processando Geometria...").

**Decisions:**
- Biblioteca de File Picker e Dropzone: Utilizar `file_picker` + `flutter_dropzone`.
- Gatilho da Tela de Importação: Adicionar botão de acesso na `loteamentos_list_screen` atual.
- Path no Storage: Utilizar `loteamentos_drafts_uploads/{userId}/{timestamp}.dxf`.

</frozen-after-approval>

## Code Map

- `lib/src/features/loteamentos/presentation/` -- Adicionar a nova tela de importação e espera.
- `lib/src/features/loteamentos/routing/` -- Adicionar as novas rotas.
- `lib/src/features/loteamentos/data/` -- Adicionar os repositórios/serviços de upload para Storage e Listener do Firestore.
- `pubspec.yaml` -- Adicionar dependências de arquivos.

## Tasks & Acceptance

**Execution:**
- [ ] `pubspec.yaml` -- Adicionar dependências de file picker.
- [ ] `lib/src/features/loteamentos/data/loteamentos_import_repository.dart` -- Implementar funções de envio pro Storage e Listener de stream do documento `loteamentos_drafts/{id}`.
- [ ] `lib/src/features/loteamentos/presentation/loteamento_import_screen.dart` -- Criar a tela com área de dropzone para upload.
- [ ] `lib/src/features/loteamentos/presentation/loteamento_processing_screen.dart` -- Criar a tela de sala de espera com listener animado e transição automática ao receber os dados via goRouter.
- [ ] `lib/src/features/loteamentos/routing/loteamentos_router.dart` -- Configurar as rotas e navegação do fluxo de importação.

**Acceptance Criteria:**
- Given que o usuário acessa a tela de Importação, when ele arrasta um .dxf e envia, then o app faz upload pro Cloud Storage e exibe visualmente o envio.
- Given o upload recém concluído, when o rascunho ainda não existe no Firestore, then a tela exibe animação contínua "Processando Geometria...".
- Given a tela "Processando", when o snapshot correspondente é persistido no Firestore, then a tela redireciona automaticamente para o fluxo de revisão do Canvas.

## Implementation Notes

## Spec Change Log

## Review Triage Log

## Verification

**Commands:**
- `flutter analyze` -- expected: Sem warnings ou errors de sintaxe.
- `flutter test` -- expected: Testes de unidade e widgets passam.
