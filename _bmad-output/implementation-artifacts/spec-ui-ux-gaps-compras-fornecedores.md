---
title: 'UX/UI — Harmonização Visual: SigoLayout em Compras e Acesso Rápido a Fornecedores'
type: 'enhancement'
created: '2026-09-18'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-5-4-fornecedores.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-5-5-parcelas-recebimento.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-ui-ux-gaps-harmonizacao.md'
---

# UX/UI — Harmonização Visual: SigoLayout em Compras e Acesso Rápido a Fornecedores

## Intent
Envelopar as três telas do módulo de Compras e NF (`ComprasListScreen`, `CompraDetalhesScreen`, `CompraFormScreen`) com `SigoLayout` para que o usuário mantenha o contexto da obra, a barra lateral de navegação (`SigoSidebar`) no Desktop e o Drawer no Mobile.
Adicionar o botão de acesso rápido a **Fornecedores** na barra de ações superiores do Painel da Construtora (`ObrasListScreen`).

## Tasks
1. **ObrasListScreen (`obras_list_screen.dart`):**
   - Adicionar botão de acesso rápido a Fornecedores no `actions` de `SigoLayout`.
2. **ComprasListScreen (`compras_list_screen.dart`):**
   - Substituir `Scaffold` por `SigoLayout(title: 'Compras e Notas Fiscais', activeRoute: '/construtora/$construtoraId/obra/$obraId/compras')`.
3. **CompraDetalhesScreen (`compra_detalhes_screen.dart`):**
   - Substituir `Scaffold` por `SigoLayout(title: 'Detalhes da Compra / NF', activeRoute: '/construtora/$construtoraId/obra/$obraId/compras')`.
4. **CompraFormScreen (`compra_form_screen.dart`):**
   - Substituir `Scaffold` por `SigoLayout(title: widget.compraId == null ? 'Nova Compra / NF' : 'Editar Compra', activeRoute: '/construtora/$construtoraId/obra/$obraId/compras')`.
5. **Validação:**
   - Executar `flutter test` e `flutter analyze`.
   - Executar `hot_reload` via DTD.
