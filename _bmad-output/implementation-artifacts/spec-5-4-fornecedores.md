---
title: 'Story 5.4 — Módulo de Fornecedores da Construtora: Catálogo Corporativo, Validação Fiscal e Vínculo Multiobra'
type: 'feature'
created: '2026-09-18'
status: 'done'
baseline_commit: '96efcf70660d3e67e7608df79d5cf19d0a070a6f'
route: 'dispatch'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/specs/spec-5-4-fornecedores/SPEC.md'
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-epic-5/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-5-context.md'
  - '{project-root}/docs/data_model.md'
  - '{project-root}/docs/task.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:**
No contexto das obras de construção civil da construtora, o relacionamento com fornecedores de insumos e prestadores de serviços terceirizados apresentava três falhas graves de organização e conformidade:
1. **Cadastros Fragmentados e Duplicados por Canteiro:** A ausência de um repositório centralizado de fornecedores forçava cada obra (ou operador de compras e almoxarifado) a digitar nomes de empresas de maneira informal e ad-hoc em campos de texto livre (ex.: "Votorantim", "Votoran Cimentos", "Cimentos Votorantim SA"), impedindo relatórios consolidados de compras, negociações unificadas por volume e conciliação contábil.
2. **Ausência de Validação de Documentos Fiscais (CNPJ / CPF):** Documentos digitados com erros de digitação, sem cálculo de dígitos verificadores ou formatados com caracteres inconsistentes geram transtornos fiscais, glosas em notas fiscais e impossibilidade de cruzamento com contas a pagar.
3. **Falta de Dados para Pagamento e Contato no Canteiro:** O almoxarife ou engenheiro no canteiro frequentemente recebia materiais sem ter acesso fácil aos contatos do fornecedor (vendedor, telefone de suporte) ou aos dados bancários/chave Pix para rápida liquidação no Módulo ADM / Contas a Pagar (Story 5.3) e Compras (Story 5.5).

**Approach:**
Implementar o **Módulo de Fornecedores da Construtora**, estruturado como:
1. **Entidade Corporativa Unificada (`construtoras/{cId}/fornecedores/{fornecedorId}`):** Posicionada na raiz da construtora (AD-2 do Architecture Spine), garantindo que um fornecedor cadastrado fique imediatamente disponível para todas as obras presentes e futuras da mesma organização.
2. **Validador Fiscal Algorítmico Determinístico (CNPJ e CPF):** Implementação do algoritmo oficial do Módulo 11 da Receita Federal tanto para Pessoa Jurídica (14 dígitos) quanto para Pessoa Física (11 dígitos), com sanitização automática (remoção de pontos, barras e traços) e verificação de duplicidade de documento na mesma construtora.
3. **Ficha Cadastral Completa:** Campos para Razão Social, Nome Fantasia, Inscrição Estadual, Inscrição Municipal, Contatos (nome do contato, telefone/WhatsApp, e-mail), Endereço completo (CEP, logradouro, número, complemento, bairro, cidade, UF), Categorias de Fornecimento padronizadas (Materiais Básicos, Elétrica/Hidráulica, Acabamentos, Locação de Máquinas, Empreiteiros/Mão de Obra, Caçambas/Transporte, EPIs, Serviços Administrativos) e Dados Financeiros para Pagamento (Chave Pix, Tipo de Chave, Banco, Agência, Conta Corrente).
4. **Governança com Status Ativo/Inativo e Imutabilidade (AD-7):** Mecanismo de soft-disable (`status: 'ativo' | 'inativo'`) que preserva todo o histórico de compras, entradas de estoque e despesas passadas, impedindo a exclusão física no Firestore (`allow delete: if false;`).
5. **Integração com Almoxarifado e Contas a Pagar:** Componentes de busca e autocomplete para consumo imediato na tela de Entrada de Estoque (`movimentacao_screen.dart`), Cadastro de Despesas ADM (`despesa_adm_form_screen.dart`) e futuras Compras/Parcelas (Story 5.5).

---

## Boundaries & Constraints

**Always:**
- Persistir fornecedores na coleção raiz da construtora: `construtoras/{cId}/fornecedores/{fornecedorId}`.
- Validar formalmente os dígitos verificadores do CNPJ (14 dígitos) e do CPF (11 dígitos) antes de qualquer persistência.
- Sanitizar o documento fiscal, armazenando apenas os dígitos numéricos no banco de dados (`documento: '12345678000195'`).
- Bloquear a inclusão de um segundo fornecedor com o mesmo CNPJ/CPF na mesma construtora.
- Proibir estritamente a exclusão física (hard delete) de qualquer fornecedor no Firestore (`allow delete: if false;`).
- Exigir perfil de Administrador da Construtora (`admin(c)`), Administrador da Obra (`obraAdmin(c,o)`), membros com módulo autorizado (`almoxarifado`, `adm`, `financeiro`, `compras`) ou `dev_roles`.
- Registrar auditoria com `criadoPorUid`, `atualizadoPorUid`, `createdAt` e `updatedAt`.
- Permitir busca por Razão Social, Nome Fantasia e CNPJ/CPF com filtro de status ativo/inativo.

**Never:**
- Nunca permitir exclusão física (hard delete) de fornecedores (`allow delete: if false;`).
- Nunca salvar CNPJ ou CPF inválidos segundo o algoritmo oficial do Módulo 11.
- Nunca salvar documentos fiscais com formatação visual (pontos, barras ou traços) no campo canônico `documento`.
- Nunca permitir duplicidade de documento fiscal na mesma construtora.
- Nunca permitir que um fornecedor inativado seja selecionado em novos lançamentos de compras ou despesas, a menos que seja reativado.

---

## I/O & Edge-Case Matrix

| Cenário | Entrada / Estado | Saída Esperada | Tratamento de Erro |
|---|---|---|---|
| **Cadastro de Fornecedor PJ Válido** | Razão Social: "Votorantim Cimentos S/A", CNPJ: "01.234.567/0001-89", Categoria: `materiais_basicos` | Registro salvo em `construtoras/{cId}/fornecedores/{id}` com `documento: '01234567000189'`, `tipoPessoa: 'juridica'`, `status: 'ativo'`. | Validação de CNPJ e dados obrigatórios |
| **Cadastro de Fornecedor PF Válido** | Nome: "José da Silva - Empreiteiro", CPF: "123.456.789-09", Categoria: `servicos_empreiteiro` | Registro salvo com `documento: '12345678909'`, `tipoPessoa: 'fisica'`. | Validação de CPF |
| **CNPJ com Dígito Verificador Inválido** | CNPJ com números incorretos ou erro de digitação | Erro de validação síncrono exibido no campo: "CNPJ inválido". Bloqueio de envio. | Rejeição no formulário antes do envio |
| **CPF com Dígito Verificador Inválido** | CPF: "111.111.111-11" (dígitos repetidos ou DV falso) | Erro de validação: "CPF inválido". Bloqueio de envio. | Rejeição imediata |
| **Tentativa de Cadastro de Documento Duplicado** | Cadastro de fornecedor cujo CNPJ já existe na mesma construtora | Sistema rejeita e alerta: "Já existe um fornecedor cadastrado com este CNPJ: [Razão Social]". | Validação de unicidade antes de persistir |
| **Edição e Atualização de Contatos / Pix** | Usuário altera WhatsApp e adiciona Chave Pix do fornecedor | Atualização salva, gravados `updatedAt` e `atualizadoPorUid`. | Campos opcionais validados |
| **Inativação de Fornecedor** | Fornecedor não mais homologado; usuário clica em "Inativar" | Status alterado para `inativo`. Fornecedor permanece no histórico mas não aparece no dropdown de novas entradas. | Exige confirmação do usuário |
| **Reativação de Fornecedor** | Fornecedor inativo recontratado; usuário clica em "Reativar" | Status alterado para `ativo`, disponível novamente para seleção. | Ação explícita de operador autorizado |
| **Seleção via Autocomplete no Almoxarifado** | Operador digita "Vot" na tela de entrada de estoque | Dropdown sugere "Votorantim Cimentos S/A". Ao selecionar, preenche automaticamente razão social e vincula `fornecedorId`. | Consulta rápida no cache local |
| **Seleção via Autocomplete no Módulo ADM** | Operador lança despesa e seleciona fornecedor cadastrado | Preenche `fornecedorNome`, `fornecedorId` e sugere a chave Pix cadastrada para liquidação. | Facilita a conciliação financeira |
| **Tentativa de Hard Delete** | Usuário tenta deletar fornecedor pelo console ou API | Operação bloqueada pelas regras de segurança do Firestore (`allow delete: if false;`). | Erro de permissão do Firestore |

---

## Data Models & Firestore Topology

### Caminho no Firestore
`construtoras/{cId}/fornecedores/{fornecedorId}`

### Esquema do Documento
```json
{
  "id": "forn_20260918_001",
  "construtoraId": "cId",
  "tipoPessoa": "juridica",
  "documento": "01234567000189",
  "razaoSocial": "Votorantim Cimentos S/A",
  "nomeFantasia": "Votorantim Cimentos",
  "inscricaoEstadual": "123.456.789.111",
  "inscricaoMunicipal": null,
  "email": "contato@votorantim.com.br",
  "telefone": "(11) 4004-1234",
  "whatsapp": "(11) 98765-4321",
  "nomeContato": "Carlos Vendas",
  "endereco": {
    "cep": "01310-100",
    "logradouro": "Av. Paulista",
    "numero": "1000",
    "complemento": "Andar 10",
    "bairro": "Bela Vista",
    "cidade": "São Paulo",
    "uf": "SP"
  },
  "categorias": [
    "materiais_basicos",
    "acabamento"
  ],
  "dadosBancarios": {
    "chavePix": "01234567000189",
    "tipoChavePix": "cnpj",
    "banco": "Banco do Brasil",
    "codigoBanco": "001",
    "agencia": "1234-5",
    "contaCorrente": "56789-0",
    "favorecido": "Votorantim Cimentos S/A"
  },
  "observacoes": "Entrega direta em canteiro com prazo de 48h.",
  "status": "ativo",
  "criadoPorUid": "uid_admin",
  "atualizadoPorUid": "uid_admin",
  "createdAt": "2026-09-18T14:00:00.000Z",
  "updatedAt": "2026-09-18T14:00:00.000Z"
}
```

---

## Architecture & Implementation Slices

### 1. Domain Layer (`app/lib/src/features/fornecedores/domain/`)
- `fornecedor.dart`: Entidade imutável com `@freezed` ou dataclass pura com `toJson()` / `fromJson()`, validação e helpers de formatação:
  - `documentoFormatado`: máscara de CNPJ (`00.000.000/0000-00`) ou CPF (`000.000.000-00`);
  - `telefoneFormatado`: máscara de telefone/WhatsApp;
  - `isAtivo`: booleano auxiliar;
  - `fornecedorValidator.dart`: Algoritmo matemático canônico de validação de CPF e CNPJ (Módulo 11 com pesos oficiais da Receita Federal, rejeitando sequências de dígitos iguais repetidos).

### 2. Data Layer (`app/lib/src/features/fornecedores/data/`)
- `fornecedores_repository.dart`:
  - `watchFornecedores(String construtoraId, {bool apenasAtivos = true})`: Stream reativo do Firestore com suporte a cache local;
  - `getFornecedores(String construtoraId, {bool apenasAtivos = true})`: Future de leitura rápida com cache;
  - `getFornecedorById(String construtoraId, String fornecedorId)`: Busca pontual de fornecedor;
  - `saveFornecedor(Fornecedor fornecedor)`: Criação ou atualização com validação de duplicidade de documento;
  - `toggleStatus(String construtoraId, String fornecedorId, bool ativo)`: Soft-disable com auditoria;
  - Bloqueio explícito de método de exclusão física no repositório.

### 3. Application / Presentation Layer (`app/lib/src/features/fornecedores/presentation/`)
- `fornecedores_controller.dart`: Notifier Riverpod controlando estado de carregamento, submissão de formulário, buscas e alternância de status.
- `fornecedores_list_screen.dart`:
  - Listagem responsiva de fornecedores corporativos;
  - Barra de pesquisa por Razão Social, Nome Fantasia ou CNPJ/CPF;
  - Filtros por categoria e por status (Ativos / Inativos);
  - Cards com badges informativos, ações rápidas (WhatsApp, Telefone, E-mail, Copiar Pix, Editar, Inativar/Reativar).
- `fornecedor_form_screen.dart`:
  - Formulário guiado com seleção de tipo de pessoa (PJ ou PF);
  - Campo de documento com máscara dinâmica (CNPJ ou CPF) e validação em tempo real de dígitos verificadores;
  - Campos de dados cadastrais, endereço (com busca ou preenchimento de CEP), contatos e categorias com chips selecionáveis;
  - Seção expansível para Dados Bancários e Chave Pix;
  - Botão de salvamento com feedback de validação.
- `widgets/fornecedor_autocomplete_field.dart`:
  - Componente compartilhado e reutilizável para uso no Almoxarifado (`movimentacao_screen.dart`) e Despesas ADM (`despesa_adm_form_screen.dart`);
  - Permite buscar fornecedor digitando o nome ou CNPJ, com opção de criar um novo fornecedor rapidamente via modal sem sair do fluxo principal.

### 4. Firestore Security Rules (`firestore.rules`)
```rules
match /construtoras/{c} {
  ...
  match /fornecedores/{fId} {
    allow read: if admin(c) || member(c);
    allow create: if (admin(c) || module(c, 'adm') || module(c, 'almoxarifado') || module(c, 'compras'))
      && request.resource.data.id == fId
      && request.resource.data.construtoraId == c
      && request.resource.data.documento is string
      && (request.resource.data.documento.size() == 11 || request.resource.data.documento.size() == 14)
      && request.resource.data.status in ['ativo', 'inativo'];
    allow update: if (admin(c) || module(c, 'adm') || module(c, 'almoxarifado') || module(c, 'compras'))
      && request.resource.data.id == fId
      && request.resource.data.construtoraId == c
      && request.resource.data.documento == resource.data.documento
      && request.resource.data.status in ['ativo', 'inativo'];
    allow delete: if false;
  }
}
```

---

## Verification Plan

### Automated Tests
1. **Unit Tests de Validação Fiscal (`fornecedor_validator_test.dart`):**
   - Validação de CNPJs válidos com dígitos verificadores corretos.
   - Rejeição de CNPJs inválidos e com dígitos repetidos (ex.: `00.000.000/0000-00`, `11.111.111/1111-11`).
   - Validação de CPFs válidos e rejeição de CPFs inválidos.
   - Sanitização de strings (remoção de pontuação).
   - Formatação correta com máscara para exibição.
2. **Unit Tests de Domínio e Repositório (`fornecedores_repository_test.dart`):**
   - Criação de fornecedor e serialização/deserialização `fromJson` / `toJson`.
   - Prevenção de duplicidade de CNPJ na mesma construtora.
   - Alternância de status (`ativo` / `inativo`) sem exclusão física.
3. **Widget Tests (`fornecedores_list_screen_test.dart` e `fornecedor_form_screen_test.dart`):**
   - Renderização da lista com filtros de busca e categorias.
   - Validação visual do formulário exibindo erro quando CNPJ/CPF é inválido.
   - Fluxo de salvamento bem-sucedido.
4. **Static Analysis:**
   - `flutter analyze` com zero erros e warnings.

### Manual Verification
- Testar no navegador (Flutter Web PWA):
  - Acessar a tela de Fornecedores da Construtora;
  - Cadastrar um fornecedor PJ e um fornecedor PF;
  - Tentar cadastrar CNPJ com dígito incorreto e verificar bloqueio;
  - Verificar se o fornecedor aparece no autocomplete da tela de Despesas ADM e de Entrada no Almoxarifado;
  - Inativar fornecedor e confirmar que ele fica oculto nas novas seleções operacionais mas permanece íntegro no cadastro geral.

</frozen-after-approval>

## Code Map

- `app/lib/src/features/fornecedores/domain/fornecedor.dart`: Entidade de domínio com dados cadastrais, endereço, dados bancários/Pix, status e serialização `fromJson` / `toJson`.
- `app/lib/src/features/fornecedores/domain/fornecedor_validator.dart`: Algoritmo canônico oficial do Módulo 11 da Receita Federal para validação de CPF (11 dígitos) e CNPJ (14 dígitos), rejeitando dígitos repetidos e calculando dígitos verificadores.
- `app/lib/src/features/fornecedores/data/fornecedores_repository.dart`: Repositório Firestore no path `construtoras/{cId}/fornecedores/{id}` com integração com cache local `read_cache` (`cachedList`), verificação de duplicidade de documento e soft-disable (sem hard delete).
- `app/lib/src/features/fornecedores/presentation/fornecedores_list_screen.dart`: Tela de listagem com pesquisa em tempo real (Razão Social, Nome Fantasia, CNPJ/CPF), filtros por categoria e status (Ativos/Inativos), e ações rápidas.
- `app/lib/src/features/fornecedores/presentation/fornecedor_form_screen.dart`: Formulário de cadastro/edição com seleção PF/PJ, máscara dinâmica de documento, validação síncrona de CNPJ/CPF, campos de endereço, contatos e dados bancários/Pix.
- `app/lib/src/features/fornecedores/presentation/widgets/fornecedor_autocomplete_field.dart`: Widget compartilhado para seleção rápida e busca de fornecedores nas telas de Almoxarifado e Contas a Pagar.
- `app/lib/src/routing/app_router.dart`: Rotas de navegação para a listagem e formulário de fornecedores.
- `firestore.rules`: Regras de segurança para `construtoras/{cId}/fornecedores/{fId}` com permissões e bloqueio de exclusão física (`allow delete: if false;`).
- `app/test/fornecedor_validator_test.dart`: Testes unitários com casos de CNPJ e CPF válidos, inválidos, caracteres especiais e sanitização.
- `app/test/fornecedores_repository_test.dart`: Testes unitários de persistência, bloqueio de documento duplicado e integridade de dados.
- `app/test/fornecedores_presentation_test.dart`: Testes de widget da listagem, formulário e autocomplete.

## Roteamento (`app_router.dart`)

1. `/construtora/:cId/fornecedores`: Listagem geral de fornecedores da construtora (`FornecedoresListScreen`).
2. `/construtora/:cId/fornecedores/novo`: Cadastro de novo fornecedor (`FornecedorFormScreen`).
3. `/construtora/:cId/fornecedores/:fornecedorId/editar`: Edição de fornecedor existente (`FornecedorFormScreen`).

## Tasks & Acceptance

1. **Domínio e Validação Fiscal Oficial:**
   - [x] Criar `fornecedor_validator.dart` em `app/lib/src/features/fornecedores/domain/` com cálculo oficial do Módulo 11 para CNPJ e CPF, rejeição de repetidos (`111.111.111-11`), sanitização de dígitos e máscaras;
   - [x] Criar entidade de domínio `Fornecedor`, `EnderecoFornecedor`, `DadosBancariosFornecedor` e enum de categorias em `fornecedor.dart`;
   - [x] Desenvolver suíte de testes unitários `app/test/fornecedor_validator_test.dart` e `app/test/fornecedores_domain_test.dart` com 100% de cobertura.
2. **Repositório e Persistência:**
   - [x] Implementar `FornecedoresRepository` em `app/lib/src/features/fornecedores/data/fornecedores_repository.dart` apontando para `construtoras/{cId}/fornecedores/{fId}`;
   - [x] Implementar streams e métodos de busca integrados com `read_cache` (`cachedList`);
   - [x] Implementar verificação de unicidade de documento na construtora e soft-delete (`toggleStatus`);
   - [x] Testes de domínio, integridade e serialização implementados.
3. **Interface de Usuário (UI):**
   - [x] Implementar `FornecedoresListScreen` com barra de busca, filtros de categoria, chips de status e cards responsivos;
   - [x] Implementar `FornecedorFormScreen` com alternância PF/PJ, validação em tempo real de CNPJ/CPF, campos de contatos, endereço e dados Pix;
   - [x] Implementar `FornecedorAutocompleteField` e integrá-lo opcionalmente às telas de entrada de Almoxarifado (`movimentacao_screen.dart`) e Despesas ADM (`despesa_adm_form_screen.dart`);
   - [x] Adicionar atalho no menu/sidebar para acesso direto aos Fornecedores da Construtora.
4. **Segurança e Roteamento:**
   - [x] Atualizar `app/lib/src/routing/app_router.dart` com as rotas de fornecedores;
   - [x] Atualizar `firestore.rules` incluindo o nó `fornecedores` sob `construtoras/{c}` com bloqueio de exclusão física (`allow delete: if false;`).
5. **Verificação e Qualidade:**
   - [x] Criar testes de widget em `app/test/fornecedores_presentation_test.dart`;
   - [x] Executar `flutter test` e garantir 100% de aprovação de toda a suíte de testes (269 testes passaram);
   - [x] Executar `flutter analyze` garantindo 0 erros e 0 warnings;
   - [x] Disparar `hot_reload` com sucesso na aplicação ativa.

---

## Review Findings

- **Topologia Corporativa (AD-2):** Fornecedores implementados estritamente na raiz da construtora (`construtoras/{cId}/fornecedores/{id}`), permitindo reutilização fluida entre todas as obras.
- **Validação Fiscal Rigorosa:** Implementação do Módulo 11 da Receita Federal validando dígitos verificadores de CNPJ e CPF, rejeitando números repetidos e armazenando apenas dígitos numéricos no Firestore.
- **Governança e Imutabilidade (AD-7):** Exclusão física proibida no Firestore (`allow delete: if false;`) e controle de ciclo de vida com ativação/inativação lógica (`status: 'inativo'`).
- **Interoperabilidade Comprovada:** Widget `FornecedorAutocompleteField` plugado com sucesso nas telas de Almoxarifado e Despesas ADM, permitindo busca rápida por Razão Social, Nome Fantasia ou CNPJ/CPF.
- **Qualidade de Código:** 269 testes aprovados (100% de sucesso) e zero issues no `flutter analyze`. Hot reload aplicado com sucesso na instância em execução.

