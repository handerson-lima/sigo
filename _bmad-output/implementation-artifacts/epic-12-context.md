# Epic 12 Context: Gestão de Construtoras no Painel Dev

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Devs podem ativar ou desativar o status das construtoras para suspender acesso global no app.

## Stories

- Story 12.1: Adicionar controle de ativação de construtora no Painel Dev
- Story 12.2: Ocultar construtoras inativas na listagem do usuário

## Requirements & Constraints

- O Painel Dev deve permitir alterar a flag `isActive` da construtora.
- O sistema não exibe construtoras inativas (onde `isActive == false`) na listagem "Minhas Construtoras".
- A restrição de visibilidade deve ser aplicada nas consultas (`.where('isActive', isEqualTo: true)`) e forçada via Security Rules (Firestore) para barrar acesso de usuários comuns a projetos inativos.
- O ato de inativar não deve excluir dados, apenas mascará-los via flag.
