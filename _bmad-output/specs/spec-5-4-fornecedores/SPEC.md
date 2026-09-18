---
id: SPEC-5-4-fornecedores
companions:
  - ../implementation-artifacts/spec-5-4-fornecedores.md
sources:
  - ../planning-artifacts/architecture/architecture-epic-5/ARCHITECTURE-SPINE.md
  - ../implementation-artifacts/epic-5-context.md
  - ../../docs/data_model.md
---

> **Canonical contract.** This SPEC and the files in `companions:` are the complete, preservation-validated contract for what to build, test, and validate.

# Story 5.4 — Módulo de Fornecedores da Construtora: Catálogo Corporativo, Validação Fiscal e Vínculo Multiobra

## Why

No gerenciamento de obras da construtora, a ausência de um catálogo corporativo unificado de fornecedores gera severas ineficiências operacionais e riscos fiscais:
1. **Redundância e Descentralização:** Cada obra ou setor (almoxarifado de materiais, despesas de canteiro, compras e contratação de serviços) realizava cadastros isolados ou preenchia campos de texto livre sem padronização, gerando cadastros duplicados da mesma empresa com grafias e dados divergentes.
2. **Erros de Identificação e Riscos Fiscais:** A digitação de CNPJs e CPFs sem validação algorítmica de dígitos verificadores e sem normalização de pontuação compromete a emissão de notas fiscais, conciliações contábeis e a rastreabilidade fiscal perante os órgãos de controle.
3. **Falta de Integração Operacional:** A falta de uma entidade corporativa de fornecedor exigia que encarregados e administradores redigitassem os dados do fornecedor e informações de pagamento (chave Pix, dados bancários) em cada recebimento de material no Almoxarifado (Epic 3) e lançamento de contas a pagar no Módulo ADM (Story 5.3).

## Capabilities

- **CAP-1**
  - **intent:** Cadastrar e gerenciar fornecedores e prestadores de serviço centralizados no escopo da construtora.
  - **success:** Usuários autorizados cadastram e editam fornecedores na coleção `construtoras/{cId}/fornecedores/{fornecedorId}`, tornando-os imediatamente visíveis e reaproveitáveis por todas as obras pertencentes à mesma construtora.

- **CAP-2**
  - **intent:** Validar e normalizar deterministicamente documentos fiscais (CNPJ e CPF) impedindo cadastros duplicados.
  - **success:** O sistema valida os dígitos verificadores pelo algoritmo oficial (módulo 11) de CPF (11 dígitos) e CNPJ (14 dígitos), armazena o documento sem formatação ou máscara e bloqueia cadastros com o mesmo documento dentro da mesma construtora.

- **CAP-3**
  - **intent:** Manter dados cadastrais completos, contatos, categorias de fornecimento e dados de pagamento bancário/Pix.
  - **success:** Cada registro de fornecedor suporta razão social, nome fantasia, inscrição estadual/municipal, telefones/WhatsApp, e-mail, endereço completo, classificação por categorias de insumos/serviços e dados para quitação financeira (chave Pix, banco, agência e conta).

- **CAP-4**
  - **intent:** Integrar a seleção de fornecedores via autocomplete nas telas de Almoxarifado e Contas a Pagar.
  - **success:** As telas de Entrada de Estoque (`movimentacao_screen.dart`) e de Cadastro de Despesas ADM (`despesa_adm_form_screen.dart`) oferecem autocomplete vinculado ao catálogo corporativo, preenchendo automaticamente `fornecedorId`, razão social e dados de pagamento.

- **CAP-5**
  - **intent:** Assegurar governança com ciclo de vida ativo/inativo e bloqueio estrito de exclusão física.
  - **success:** O sistema permite a inativação lógica do fornecedor (`status: 'inativo'`), impedindo novas seleções operacionais sem quebrar integridade referencial com movimentações de estoque, despesas ou compras já existentes, com proteção em `firestore.rules` (`allow delete: if false;`).

## Constraints

- **Topologia de Dados Obrigatória:** Fornecedores residem obrigatoriamente na raiz da construtora: `construtoras/{cId}/fornecedores/{fornecedorId}`, conforme estipulado pela AD-2 do Architecture Spine.
- **Imutabilidade e Não-Exclusão:** Registros de fornecedores não podem sofrer exclusão física no Firestore (`allow delete: if false;`), atendendo à AD-7 (Governança e Trilha de Auditoria).
- **Normalização de Documentos:** CNPJ (14 dígitos) e CPF (11 dígitos) são persistidos estritamente como sequências numéricas sem formatação.
- **Autorização e RBAC:** Leitura autorizada para administradores da construtora/obra e membros com módulos `almoxarifado`, `adm`, `financeiro` ou `compras` no array `allowedModules`, além de `dev_roles`. Escrita restrita a administradores e operadores autorizados com auditoria de `criadoPorUid` e `atualizadoPorUid`.
- **Resiliência Offline:** Listagem e consulta contam com cache local e suporte ao enfileiramento na `OperationQueue`.

## Non-goals

- Integração em tempo real com a API da Receita Federal ou consulta automatizada via Sintegra/ReceitaWS para autopreenchimento por CNPJ (os dados são informados pelo operador).
- Emissão direta de Notas Fiscais Eletrônicas (NF-e/NFS-e) ou escrituração contábil/fiscal automatizada.
- Cálculo automático de retenções na fonte (IRRF, INSS retido, PIS/COFINS/CSLL).

## Success signal

- Catálogo corporativo de fornecedores em pleno funcionamento no app SIGO em `construtoras/{cId}/fornecedores/{fornecedorId}`, validação síncrona com algoritmo oficial de CNPJ/CPF no cliente e no modelo de domínio, integração fluida com autocomplete no Almoxarifado e no Módulo ADM, status ativo/inativo preservando dados passados, regras de segurança bloqueando hard delete (`allow delete: if false;`), 100% dos testes unitários e de widget passando e zero warnings no `flutter analyze`.
