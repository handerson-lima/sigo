---
id: SPEC-5-7-gestao-proprietario-owner
companions:
  - ../../implementation-artifacts/spec-5-7-gestao-proprietario-owner.md
sources:
  - ../../docs/data_model.md
  - ../../docs/implementation_plan.md
  - ../../firestore.rules
  - ../../functions/src/index.ts
---

> **Canonical contract.** This SPEC and the files in `companions:` are the complete, preservation-validated contract for what to build, test, and validate.

# Story 5.7 — Gestão e Atribuição de Proprietário (Owner) da Construtora: Governança, Proteção de Titularidade e Identificação Visual

## Why

No modelo multi-tenant do SIGO, cada construtora possui seus administradores, engenheiros e operadores. A figura do **Proprietário / Owner** (`isOwner: true`, `role: 'owner'`) foi concebida nas regras de segurança ([firestore.rules](file:///Users/usuario/obras/firestore.rules)) como a autoridade máxima dentro da organização da construtora, hierarquicamente superior aos administradores delegados. 

Entretanto, uma lacuna na camada de aplicação e nas Cloud Functions impede seu uso pleno:
1. **Bloqueio no Backend:** A Cloud Function transacional `setMembership` / `setConstrutoraRole` restringe os papéis aceitos estritamente a `['admin', 'member', 'operario']`. Qualquer tentativa de definir `role: 'owner'` gera erro de argumento inválido. Adicionalmente, a função apenas preserva a flag `isOwner` existente (`isOwner: existing?.isOwner === true`), sem disponibilizar mecanismo de concessão do papel mesmo para desenvolvedores globais autenticados.
2. **Ausência de Vínculo na Criação de Construtora:** A tela do Painel Dev (`dev_construtoras_list_screen.dart`) cria o documento da construtora no Firestore sem vincular o usuário proprietário inicial, deixando a construtora sem dono explícito.
3. **Invisibilidade e Falta de Suporte na UI:** O modelo Dart `Membro` não mapeia a propriedade `isOwner`, e as telas de gestão (`add_membro_dialog.dart`, `membros_screen.dart` e `user_details_screen.dart`) exibem apenas "Operário" ou "Administrador", tornando o papel de Proprietário inalcançável e visualmente indistinguível no aplicativo.

## Capabilities

- **CAP-1**
  - **intent:** Permitir que desenvolvedores globais ativos (`dev`) atribuam o papel de Proprietário (`role: 'owner'`, `isOwner: true`) a membros de uma construtora via Cloud Function.
  - **success:** A Cloud Function `setMembership` / `setConstrutoraRole` aceita `role: 'owner'` quando executada por usuário com papel `dev` ativo (`dev_roles/{uid}` com `isActive: true`), persistindo no documento `construtoras/{cId}/construtora_members/{uid}` os campos `role: 'owner'`, `isAdmin: true`, `isOwner: true` e `isActive: true`, registrando auditoria em `/audit`.

- **CAP-2**
  - **intent:** Bloquear estritamente que administradores comuns da construtora (não-devs) se autopromovam a Proprietário ou alterem/rebaixem o vínculo de um Proprietário existente.
  - **success:** Tentativas de usuários que não possuem o papel `dev` de passar `role: 'owner'` ou de modificar um membro que já possui `isOwner: true` ou `role: 'owner'` são rejeitadas pelo backend com erro `permission-denied: 'Apenas dev altera proprietário'`.

- **CAP-3**
  - **intent:** Viabilizar a indicação do Proprietário inicial no fluxo de criação de nova construtora pelo Desenvolvedor.
  - **success:** O diálogo de criação de construtora (`dev_construtoras_list_screen.dart`) disponibiliza um campo opcional para informar o e-mail ou UID do proprietário inicial. Ao salvar, o sistema vincula o usuário diretamente com `isOwner: true` e `role: 'owner'`.

- **CAP-4**
  - **intent:** Mapear o status de Proprietário no modelo de domínio `Membro` e identificá-lo visualmente na listagem de membros.
  - **success:** O modelo `Membro` passa a ler e expor `isOwner: data['isOwner'] == true || data['role'] == 'owner'`. Na tela `membros_screen.dart`, o membro proprietário exibe ícone de destaque (ex.: estrela ou insígnia de proprietário) e o subtítulo/badge `"Proprietário"`, distinguindo-se de `"Administrador"` e `"Operário"`.

- **CAP-5**
  - **intent:** Disponibilizar o papel "Proprietário" no dropdown de cargos nas telas administrativas para desenvolvedores.
  - **success:** No Painel do Desenvolvedor (`user_details_screen.dart`) e no diálogo `add_membro_dialog.dart` (quando visualizado por dev), o menu de cargos passa a listar a opção `Proprietário` (`owner`), permitindo a seleção e envio direto ao backend.

- **CAP-6**
  - **intent:** Garantir a cobertura automatizada de testes para concessão, proteção de invariantes e exibição do papel de proprietário.
  - **success:** Suite de testes automatizados com novos cenários cobrindo: dev atribuindo owner com sucesso; admin comum sendo barrado ao tentar conceder owner; admin comum sendo barrado ao tentar editar um owner existente; e testes de widget validando a renderização correta de `"Proprietário"` na interface.

## Constraints

- **Segurança e Privilégio Exclusivo:** A alteração, destituição e promoção ao status de Proprietário é um privilégio exclusivo do papel global `dev` (`dev_roles/{uid}` com `isActive: true`). Administradores de construtora não possuem essa prerrogativa.
- **Invariante de Direitos:** Todo `owner` possui implicitamente todos os privilégios de `admin(c)` no Firestore e nas Cloud Functions (`isAdmin: true`).
- **Compatibilidade Retroativa:** Documentos preexistentes em `construtora_members` que já possuam `isOwner: true` ou `role: 'owner'` continuam válidos e protegidos.
- **Trilha de Auditoria:** Toda concessão ou modificação de titularidade deve registrar entrada atômica na coleção `/audit` com `action: 'setMembership'`, `actor: uid`, `target: path` e `isOwner: true`.
- **Qualidade de Código:** 100% dos testes unitários e de integração aprovados e conformidade estrita com `flutter analyze` sem warnings.

## Non-goals

- Alteração de contratos sociais externos, autenticação cartorária ou assinaturas jurídicas digitais de transferência de cotas de empresas.
- Limitação de apenas um proprietário por construtora (uma construtora pode possuir mais de um sócio com status `isOwner: true`, caso o desenvolvedor assim defina).
- Modificação na estrutura de papéis das obras filhas (o papel `owner` atua na raiz da construtora; nas obras os papéis permanecem `obraAdmin` e operadores).

## Success signal

- Desenvolvedor global consegue definir e alterar membros como "Proprietário" diretamente pelo aplicativo SIGO ou via Cloud Function.
- Administradores delegados comuns são impedidos de alterar membros proprietários ou de se tornarem proprietários.
- A tela de membros da construtora exibe com clareza o título de "Proprietário" para os devidos titulares.
- 100% dos testes de backend e frontend passam com sucesso.
