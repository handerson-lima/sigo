---
id: SPEC-ativar-desativar-construtora
companions: []
sources: []
---

> **Canonical contract.** This SPEC and the files in `companions:` are the complete, preservation-validated contract for what to build, test, and validate. Source documents listed in frontmatter are for traceability — consult them only if you need narrative rationale or prose color this contract intentionally omits.

# Ativar/Desativar Construtoras no Painel Dev

## Why

Atualmente, não há controle de ativação das construtoras cadastradas no painel. Permitir inativar uma construtora garante que ela não seja mais listada ou acessada indevidamente pelos usuários na seção "Minhas Construtoras", possibilitando uma gestão efetiva no Painel Dev.

## Capabilities

- **CAP-1**
  - **intent:** O perfil Dev pode alterar o status (ativo/inativo) de uma construtora através da listagem do Painel Dev.
  - **success:** Um *toggle* ou botão altera o estado da construtora com sucesso, persistindo a mudança no backend e refletindo visualmente no painel.

- **CAP-2**
  - **intent:** O sistema não exibe construtoras inativas na listagem "Minhas Construtoras".
  - **success:** Ao abrir a tela "Minhas Construtoras", nenhuma construtora com status inativo é exibida ao usuário comum, mesmo que estivesse vinculada a ele anteriormente.

## Constraints

- A restrição de visibilidade deve ser aplicada nas consultas (queries) para evitar que o payload seja baixado desnecessariamente ou contornado pela UI.

## Non-goals

- Excluir o registro da construtora do banco de dados (nenhum tipo de deleção, apenas flag de status).
- Bloquear logins ou deletar os usuários associados; a inativação da construtora apenas remove a construtora da lista de "Minhas Construtoras".

## Success signal

Ao desativar a "Construtora Exemplo S/A" pelo Painel Dev, um usuário que recarregue a sua listagem de "Minhas Construtoras" não verá mais a "Construtora Exemplo S/A" listada.
