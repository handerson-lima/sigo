---
title: 'Story 3.2: Fluxo Rápido de Correção via Painel Lateral e Teclado'
type: 'feature'
created: '2026-09-27'
status: 'implemented'
baseline_commit: 'a410f4687fccc1235d0649386ca5cf3bee782aea'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '/Users/usuario/obras/_bmad-output/implementation-artifacts/epic-3-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Atualmente, embora a tela de revisão mostre o rascunho com os lotes (neutros e ambíguos), o usuário não consegue interagir com eles para corrigir os problemas de ambiguidade reportados pela validação (ex: falta de nome/número).

**Approach:** Implementar a interação no `GeojsonCanvasWidget` para permitir a seleção de lotes (clique) e adicionar um Painel Lateral (Sidebar) fixo. Ao selecionar um lote ambíguo, o painel exibe um formulário de correção com foco automático; o usuário digita o nome/número correto, pressiona `ENTER` para salvar no banco (via atualização parcial do documento ou repositório) e atualiza o estado da tela, liberando o fluxo de aprovação caso o progresso chegue a 100%. Adicionar também um Chip indicador de progresso ("X Lotes Ambíguos").

## Boundaries & Constraints

**Always:**
- Salvar a correção no Firestore (coleção `loteamentos_drafts`), atualizando a propriedade do lote modificado de forma eficiente, para que a tela reaja à mudança reativamente (via StreamProvider atual).
- O Painel Lateral deve ganhar foco automaticamente no input de texto assim que um lote for selecionado, permitindo o uso exclusivo do teclado para submeter a correção (atalho `ENTER`).
- O Chip de Progresso deve ficar visível na barra superior (AppBar) reagindo à contagem total de lotes com `status: 'ambiguo'`.
- Garantir que um polígono selecionado ganhe um destaque visual (stroke diferente/mais espesso).

**Never:**
- Não reprocessar o GeoJSON inteiro no backend ou frontend ao corrigir um lote; apenas as propriedades do lote específico (ex: nome, status) devem ser manipuladas no documento do Firestore.
- Não usar navegação/modal bloqueante (dialog) para a edição; a correção deve ser fluida via side-panel convivendo com o canvas.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Seleção de Lote | Clique sobre a área de um polígono ambíguo | O polígono ganha destaque (stroke azul), o Painel Lateral abre preenchido com dados atuais e foco no campo de texto | Se não clicar em nada válido, fechar o painel lateral ou limpar seleção |
| Correção com Sucesso | Usuário digita texto e aperta ENTER | Atualiza o documento no Firestore, alterando status para 'resolvido'. O Stream redesenha com cor verde; o indicador de progresso decrementa | Mostrar snackbar de erro e manter o status original se a escrita falhar |
| Atalho Teclado | Foco no input de correção + ENTER | Aciona a ação de salvar | - |
| Conclusão | Último lote ambíguo é resolvido (progresso = 0) | O botão "Aprovar Definitivamente" é habilitado | - |

**Decisions:**
- Detecção de clique: Usar Hit-Testing nativo calculando `path.contains(point)`.
- Estratégia de atualização: Ler todo o array de features, modificar localmente a feature alvo e regravar via set/update completo no Firestore.

</frozen-after-approval>



## Code Map

- `app/lib/src/features/loteamentos/presentation/loteamento_canvas_screen.dart` -- Gerenciar layout Scaffold com body contendo Row (Canvas Expandido + Painel Lateral fixo à direita), gerenciar estado do lote selecionado. Adicionar Chip de Progresso no AppBar.
- `app/lib/src/features/loteamentos/presentation/widgets/geojson_canvas_widget.dart` -- Implementar detecção de tap e passar evento para o pai (`onFeatureTap`), adicionar destaque visual para a feature selecionada.
- `app/lib/src/features/loteamentos/presentation/widgets/lote_correcao_panel.dart` -- Novo widget de formulário rápido (Painel Lateral) com `FocusNode` automático e submissão via enter.
- `app/lib/src/features/loteamentos/data/loteamentos_import_repository.dart` -- Adicionar método para atualizar a feature específica dentro do rascunho.

## Tasks & Acceptance

**Execution:**
- [x] `app/lib/src/features/loteamentos/data/loteamentos_import_repository.dart` -- Implementar função `updateDraftFeature(draftId, featureIndex, newProperties)` para atualizar a feature modificada no Firestore.
- [x] `app/lib/src/features/loteamentos/presentation/widgets/geojson_canvas_widget.dart` -- Envolver `CustomPaint` num `GestureDetector` e usar `Path.contains` no `onTapUp` para calcular qual feature foi tocada. Passar índice ou ID de volta. Renderizar contorno de seleção se uma feature estiver ativa.
- [x] `app/lib/src/features/loteamentos/presentation/widgets/lote_correcao_panel.dart` -- Criar form reativo que requisite foco ao iniciar (usando `FocusScope`) e detecte teclado (onFieldSubmitted).
- [x] `app/lib/src/features/loteamentos/presentation/loteamento_canvas_screen.dart` -- Alterar layout para alocar painel à direita quando houver seleção. Implementar contador reativo e habilitar botão de Aprovação.

## Review Triage Log
- `medium` - patch: `setState` called without `mounted` check in `onSave` inside `LoteamentoCanvasScreen`.
- `false` - patch: "InteractiveViewer repaints continuously" is false, but caching paths in `GeojsonCanvasWidget` state avoids reallocation on hit-test and paint, improving UX.
- `low` - patch: Type cast hazard in `LoteamentoCanvasScreen` ambiguity count. Needs explicit map cast.
- `low` - patch: Empty submission in `LoteCorrecaoPanel` fails silently. Add validation.
- `low` - patch: `didUpdateWidget` in `LoteCorrecaoPanel` resets cursor. Use `TextSelection.collapsed`.
- `defer` - defer: Polygon holes not supported. Known limitation for this MVP phase.
- `low` - patch: Array changes between selection and save. ID usage is ideal, but GeoJSON might not have IDs. For now, add a defensive bound check or type cast.
- `high` - patch: Hit-Testing and Rendering Bounds bug. The `offset` translates coordinates to negative space, rendering half of the polygons outside the `CustomPaint` layout box, making them un-clickable. Paths must be translated by `-minX, -minY` to fit perfectly into `Size(width, height)`.
- `low` - patch: Missing repository test for draft feature update transaction.
- `low` - patch: Missing interaction test for polygon tap detection.
- `low` - patch: Missing test for ambiguous count and approval button state.


**Acceptance Criteria:**
- Given o Canvas renderizado com lotes ambíguos, when o usuário clica num polígono laranja, then o painel lateral deve ser exibido focado automaticamente no campo de nome.
- Given o painel aberto e focado, when o usuário digita e aperta ENTER, then o lote é salvo, sua cor atualiza para verde ("resolvido") e o contador de progresso reduz.
- Given a correção do último lote, when o sistema identificar zero ambíguos, then o botão de aprovação final é liberado.

## Implementation Notes

## Spec Change Log

## Review Triage Log

## Verification

**Commands:**
- `cd app && flutter analyze` -- expected: Sem erros de linting.
- `cd app && flutter test` -- expected: Testes devem passar.

**Manual checks (if no CLI):**
- Abrir uma importação com erro; clicar em lote ambíguo; digitar e apertar enter; verificar cor e progresso alterando de forma responsiva.
