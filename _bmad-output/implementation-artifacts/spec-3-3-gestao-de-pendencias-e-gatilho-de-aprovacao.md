---
title: 'Story 3.3: Gestão de Pendências e Gatilho de Aprovação'
type: 'feature'
created: '2026-09-27'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context:
  - '/Users/usuario/obras/_bmad-output/implementation-artifacts/epic-3-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O botão de aprovação final está implementado no frontend (habilitado quando os lotes ambíguos chegam a 0), mas seu clique é apenas um stub. O rascunho precisa ser marcado como aprovado no banco de dados para destravar o processamento no backend.

**Approach:** Criar o método `approveDraft(String draftId)` no `LoteamentosImportRepository` para atualizar a raiz do rascunho no Firestore (coleção `loteamentos_drafts`), definindo o campo `status` como `'aprovado'`. Integrar esse método ao botão "Aprovar Definitivamente" no `LoteamentoCanvasScreen`, exibindo um feedback de sucesso e retornando à tela anterior (ex: `context.pop()`). Em caso de erro na gravação, apresentar um SnackBar informando a falha.

</frozen-after-approval>

## Implementation Notes

- Alterada UI para incluir estado interno `_isApproving`, permitindo mostrar spinner durante chamada async.

## Review Triage Log
- `medium` - patch: Falta de loading no botão e dupla submissão (`_isApproving` implementado).
- `low` - defer: Lógica de negócio no UI (adiado).
- `low` - defer: Campos de auditoria ausentes em approveDraft (adiado).
- `low` - false: Erro de grafia de `ambiguos`. Recusado por ser detalhe de nomenclatura local.
- `low` - false: Exceção sem try-catch específico se rascunho não existe. O erro genérico já é lidado no catch.
