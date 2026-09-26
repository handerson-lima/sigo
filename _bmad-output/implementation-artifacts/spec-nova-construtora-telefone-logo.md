---
title: 'Implementar campos de telefone e logo para Nova Construtora'
type: 'feature'
created: '2026-09-25'
status: 'done'
route: 'dispatch'
baseline_commit: '3691a74a6f57b028af3537bc12b21af6986bfa44'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A tela de criação/edição de construtora atual não permite informar um telefone de contato (WhatsApp) nem fazer o upload da logo da construtora.

**Approach:** Adicionar os campos de Telefone e Logo no modelo `Construtora` e atualizar as modais de Criação e Edição em `dev_construtoras_list_screen.dart` para suportar esses campos, incluindo uma máscara visual padrão para o telefone ("84 9999-9999") e a lógica de upload da logo.

**Decisions:**
- A logo será salva no Firebase Storage, guardando apenas a URL no Firestore.
- A logo será um campo opcional no formulário.
- A validação do telefone será estrita, ou seja, bloqueará a submissão do formulário caso o número não esteja completo no formato "84 9999-9999".

</frozen-after-approval>


## Code Map

- `app/lib/src/features/construtoras/domain/construtora.dart` -- Adicionar os campos `telefone` e `logoUrl` (e rodar build_runner).
- `app/lib/src/features/developer/presentation/dev_construtoras_list_screen.dart` -- Atualizar `_AddConstrutoraDialog` e `_EditConstrutoraDialog` para incluir UI de upload de imagem e campo com máscara de telefone.

## Tasks & Acceptance

**Execution:**
- [x] `app/lib/src/features/construtoras/domain/construtora.dart` -- Atualizar modelo e factory JSON.
- [x] `app/lib/src/features/developer/presentation/dev_construtoras_list_screen.dart` -- Integrar inputs e regras de salvar logo.

**Acceptance Criteria:**
- Given a modal de nova construtora, when o usuário seleciona uma imagem e preenche um telefone, then esses dados são salvos corretamente junto à construtora.
- Given a modal de edição, when aberta, then a logo atual e o telefone devem ser exibidos e permitirem alteração.

## Implementation Notes

## Spec Change Log

## Review Triage Log

## Verification

**Commands:**
- `flutter test` -- expected: Todos os testes existentes passam.
- `dart run build_runner build -d` -- expected: Código gerado com sucesso para o modelo de Construtora.
