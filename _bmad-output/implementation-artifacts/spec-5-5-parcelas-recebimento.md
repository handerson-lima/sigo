---
title: 'Story 5.5 — Parcelas e Recebimento de Compras / NF: Desdobramento em Parcelas, Invariante Algébrica e Recebimento no Canteiro'
type: 'feature'
created: '2026-09-18'
status: 'done'
baseline_commit: '96efcf70660d3e67e7608df79d5cf19d0a070a6f'
route: 'dispatch'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/specs/spec-5-5-parcelas-recebimento/SPEC.md'
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-epic-5/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-5-context.md'
  - '{project-root}/docs/data_model.md'
  - '{project-root}/docs/task.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:**
Na gestão de suprimentos e execução de obras civis da construtora, a aquisição de insumos faturados e o recebimento de materiais no canteiro enfrentavam três problemas estruturais:
1. **Divergências Matemáticas de Centavos em Parcelamentos:** Compras faturadas a prazo em múltiplas parcelas (ex.: 28/56 dias ou 3x quinzenais) frequentemente geravam divergências de centavos decorrentes de arredondamentos pontuais (ex.: R$ 1.000,00 parcelado em 3x gerando 3 parcelas de R$ 333,33, acumulando perda de R$ 0,01). Essa discrepância quebra a conciliação contábil do canteiro com o contas a pagar da construtora.
2. **Desconexão entre o Faturamento Comercial (NF) e o Recebimento Físico:** A entrada de materiais no Almoxarifado (Epic 3) era efetuada de forma puramente braçal e isolada, sem conferência item a item contra o documento fiscal de compra e sem rastreabilidade do faturamento global, facilitando perdas, desvios e divergências entre quantidade cobrada e entregue.
3. **Falta de Gestão Individualizada de Liquidação e Idempotência:** A ausência de um fluxo estruturado de quitação de parcelas de compras com comprovantes em anexo e chave idempotente expunha a obra a risco de duplicidade de pagamento e falta de visibilidade sobre o passivo real pendente a fornecedores.

**Approach:**
Implementar o **Módulo de Compras e Parcelas / NF**, estruturado como:
1. **Entidade de Compra na Obra (`construtoras/{cId}/obras/{oId}/compras/{compraId}`):** Registro formal da transação de compra vinculando fornecedor corporativo unificado (Story 5.4), metadados fiscais (número da NF, série, chave de acesso de 44 dígitos), datas civis de emissão e previsão/recebimento, foto/PDF da NF e auditoria.
2. **Totalização Exata em Centavos Inteiros:** Composição detalhada com itens adquiridos (`materialId`, quantidade, valor unitário em centavos), frete, despesas acessórias e desconto:
   $$\text{totalCompraCents} \equiv \text{valorItensCents} + \text{freteCents} + \text{despesasAcessoriasCents} - \text{descontoCents}$$
3. **Invariante Algébrica Rigorosa de Parcelamento (AD-5):** Geração determinística de parcelas onde o resto da divisão inteira de centavos é obrigatoriamente alocado na primeira parcela, garantindo a conservação algébrica total:
   $$\sum_{i=1}^{N} \text{parcela}[i].\text{valorCents} \equiv \text{totalCompraCents}$$
   com validação síncrona que impede submissão caso $\text{discrepanciaCents} \neq 0$.
4. **Controle de Liquidação Individual com Idempotência:** Cada parcela possui ciclo de vida (`pendente`, `pago`, `atrasado`), quitação com data, método de pagamento (Pix, Boleto, etc.), upload de comprovante de quitação em Storage privado e `idempotencyKey` única para blindagem contra quitação dupla, atualizando o status geral da compra (`aberto`, `parcial`, `pago`).
5. **Integração com Recebimento de Estoque no Almoxarifado:** Ação assistida que permite dar entrada física direta nos materiais da compra para o almoxarifado local (`Movimentacao` / `stockCommand` do Epic 3), vinculando `compraId` e `nfNumber`, atualizando as quantidades recebidas e marcando a compra como `recebido`.
6. **Governança, Imutabilidade e Não-Exclusão (AD-7):** Bloqueio de exclusão física no Firestore (`allow delete: if false;`), permitindo apenas cancelamento formal auditado com justificativa.

---

## Boundaries & Constraints

**Always:**
- Persistir compras na coleção da obra ativa: `construtoras/{cId}/obras/{oId}/compras/{compraId}`.
- Manter todos os valores monetários estritamente como inteiros em centavos (`amountCents`). Fator de arredondamento ou ponto flutuante monetário é estritamente proibido.
- Garantir a invariante matemática $\sum_{i=1}^{N} \text{parcela}[i].\text{valorCents} \equiv \text{totalCompraCents}$ tanto no momento da geração inicial quanto após qualquer ajuste manual pelo operador.
- Vincular o fornecedor obrigatoriamente a um registro existente em `construtoras/{cId}/fornecedores/{fId}` (Story 5.4).
- Gerar e validar chave de idempotência (`idempotencyKey`) na liquidação de cada parcela para evitar duplicidade de quitação.
- Bloquear exclusão física (hard delete) de documentos de compras e parcelas no Firestore (`allow delete: if false;`).
- Registrar auditoria com `criadoPorUid`, `atualizadoPorUid`, `createdAt` e `updatedAt`.
- Permitir cancelamento formal apenas quando a compra possuir justificativa mínima de 10 caracteres e nenhuma parcela estiver com status `pago` (parcelas pagas exigem estorno prévio).

**Never:**
- Nunca permitir que a soma das parcelas divirja em 1 centavo sequer do `totalCompraCents` ($\text{discrepancia} \neq 0$).
- Nunca persistir compras com valores totais negativos ou zerados.
- Nunca permitir a exclusão física de registros de compras faturadas ou parcelas (`allow delete: if false;`).
- Nunca liquidar uma parcela duas vezes com a mesma chave de idempotência.
- Nunca permitir que compras sem vínculo a um fornecedor corporativo válido sejam gravadas.

---

## I/O & Edge-Case Matrix

| Cenário | Entrada / Estado | Saída Esperada | Tratamento de Erro / Bloqueio |
|---|---|---|---|
| **Compra com 1 Parcela (À Vista)** | NF `4567`, Fornecedor `Votorantim`, 100 sc cimento (R$ 3.500,00), frete R$ 150,00 -> Total: R$ 3.650,00 (365000 cents), 1 parcela | Registro criado com 1 parcela de R$ 3.650,00 (365000 cents). Invariante perfeitamente balanceada. | Formulário válido e persistido com sucesso |
| **Parcelamento em 3x com Resto Ímpar** | Total: R$ 1.000,00 (100000 cents) em 3 parcelas | Parcela 1: 33334 cents (R$ 333,34); Parcela 2: 33333 cents (R$ 333,33); Parcela 3: 33333 cents (R$ 333,33). Soma = 100000 cents. | Distribuição determinística de restos via `ParcelamentoMath` |
| **Edição Manual com Discrepância** | Usuário altera manualmente Parcela 1 para R$ 300,00 sem compensar as demais (Soma: R$ 966,66) | Sistema acusa discrepância de +R$ 33,34 e desabilita botão de salvar: "A soma das parcelas deve ser igual ao total da compra". | Bloqueio síncrono com banner visual de alerta |
| **Liquidação de Parcela com Pix** | Parcela 1 (R$ 333,34), método Pix, comprovante anexado | Parcela marcada como `status: 'pago'`, gravados `dataPagamento`, `pagoPorUid`, `comprovanteUrl` e `idempotencyKey`. Status da compra avança para `parcial`. | Validação de campos de liquidação |
| **Quitação da Última Parcela** | Todas as $N$ parcelas da compra passam a ter status `pago` | Status global da compra atualizado automaticamente para `pago`, com saldo devedor zerado (`saldoDevedorCents: 0`). | Atualização automática do status da compra |
| **Recebimento de Materiais no Almoxarifado** | Usuário clica em "Receber no Estoque" na tela da compra | Gera movimentações de entrada (`MovimentacaoType.entrada`) para os itens faturados vinculando `compraId` e `nfNumber`; itens marcados como recebidos e status da compra vira `recebido`. | Evita digitação duplicada no almoxarifado |
| **Tentativa de Cancelar Compra com Parcela Paga** | Compra possui Parcela 1 paga e usuário tenta cancelar compra inteira | Sistema bloqueia: "Não é possível cancelar uma compra com parcelas já pagas. Estorne os pagamentos primeiro." | Bloqueio de integridade contábil |
| **Cancelamento Formal de Compra em Aberto** | Compra pendente com justificativa: "Pedido cancelado pelo fornecedor por falta de estoque" | Status alterado para `cancelado`, gravados `motivoCancelamento`, `canceladoPorUid` e data. | Exige justificativa formal (mínimo 10 caracteres) |
| **Tentativa de Hard Delete** | Usuário tenta deletar compra via console ou API | Operação bloqueada pelas regras de segurança do Firestore (`allow delete: if false;`). | Erro de permissão do Firestore |

---

## Data Models & Firestore Topology

### Caminho no Firestore
`construtoras/{cId}/obras/{oId}/compras/{compraId}`

### Esquema do Documento (`CompraNf`)
```json
{
  "id": "compra_20260918_001",
  "construtoraId": "cId",
  "obraId": "oId",
  "fornecedorId": "forn_20260918_001",
  "fornecedorNome": "Votorantim Cimentos S/A",
  "fornecedorDocumento": "01234567000189",
  "numeroNf": "00012345",
  "serieNf": "1",
  "chaveAcessoNf": "35260901234567000189550010000123451000123456",
  "dataEmissao": "2026-09-18T10:00:00.000Z",
  "dataRecebimento": "2026-09-18T14:30:00.000Z",
  "descricao": "Aquisição de cimento CP II-E-32 para fundações do Bloco A",
  "status": "parcial",
  "statusRecebimento": "recebido",
  "valorItensCents": 350000,
  "freteCents": 15000,
  "despesasAcessoriasCents": 0,
  "descontoCents": 0,
  "totalCompraCents": 365000,
  "itens": [
    {
      "id": "item_1",
      "materialId": "mat_cimento_cp2",
      "materialNome": "Cimento Portland CP II-E-32 (Saco 50kg)",
      "unidadeMedida": "sc",
      "quantidade": 100.0,
      "valorUnitarioCents": 3500,
      "valorTotalCents": 350000,
      "quantidadeRecebida": 100.0
    }
  ],
  "parcelas": [
    {
      "numero": 1,
      "valorCents": 182500,
      "dataVencimento": "2026-09-25T00:00:00.000Z",
      "status": "pago",
      "dataPagamento": "2026-09-20T11:00:00.000Z",
      "pagoPorUid": "uid_financeiro",
      "metodoPagamento": "pix",
      "comprovanteUrl": "https://storage.googleapis.com/.../comprovante_p1.pdf",
      "comprovantePath": "construtoras/cId/obras/oId/compras/compra_1/p1_recibo.pdf",
      "idempotencyKey": "compra_20260918_001_p1_1726657200000",
      "observacaoPagamento": "Pago via chave Pix CNPJ do fornecedor"
    },
    {
      "numero": 2,
      "valorCents": 182500,
      "dataVencimento": "2026-10-25T00:00:00.000Z",
      "status": "pendente",
      "dataPagamento": null,
      "pagoPorUid": null,
      "metodoPagamento": null,
      "comprovanteUrl": null,
      "comprovantePath": null,
      "idempotencyKey": null,
      "observacaoPagamento": null
    }
  ],
  "anexoNfUrl": "https://storage.googleapis.com/.../danfe_12345.pdf",
  "anexoNfPath": "construtoras/cId/obras/oId/compras/compra_1/danfe.pdf",
  "criadoPorUid": "uid_almoxarife",
  "atualizadoPorUid": "uid_financeiro",
  "createdAt": "2026-09-18T14:30:00.000Z",
  "updatedAt": "2026-09-20T11:00:00.000Z",
  "motivoCancelamento": null,
  "canceladoPorUid": null,
  "dataCancelamento": null
}
```

---

## Architecture & Implementation Slices

### 1. Domain Layer (`app/lib/src/features/compras_parcelas/domain/`)
- `compra_nf.dart`:
  - Entidade imutável `CompraNf` com serialização JSON robusta e parsing de datas compatível;
  - Getters de auxílio contábil:
    - `totalPagoCents`: Soma do `valorCents` de parcelas com `status == StatusParcelaCompra.pago`;
    - `saldoDevedorCents`: `totalCompraCents - totalPagoCents`;
    - `isQuitada`: `saldoDevedorCents == 0 && parcelas.isNotEmpty`;
    - `isAtrasada`: se possui alguma parcela pendente com vencimento anterior à data de hoje;
    - `quantidadeItens`: quantidade total de itens listados.
- `item_compra.dart`:
  - Entidade `ItemCompraNf` com `materialId`, `materialNome`, `unidadeMedida`, `quantidade`, `valorUnitarioCents`, `valorTotalCents`, `quantidadeRecebida`;
  - Helper `isTotalmenteRecebido`: `quantidadeRecebida >= quantidade`.
- `parcela_compra.dart`:
  - Entidade `ParcelaCompra` com `numero`, `valorCents`, `dataVencimento`, `status`, `dataPagamento`, `pagoPorUid`, `metodoPagamento`, `comprovanteUrl`, `idempotencyKey`;
  - Enums `StatusParcelaCompra` (`pendente`, `pago`, `atrasado`, `cancelado`) e `MetodoPagamentoCompra` (`pix`, `boleto`, `transferencia`, `cartao`, `dinheiro`, `outro`).
- `parcelamento_compras_math.dart`:
  - Utilitário matemático determinístico para geração de parcelas de compra;
  - Garante a invariante $\sum \text{parcelas} \equiv \text{totalCompraCents}$ com distribuição do resto na 1ª parcela;
  - Validação de consistência e cálculo de discrepância ($\text{totalCompraCents} - \sum \text{parcelas}$).

### 2. Data Layer (`app/lib/src/features/compras_parcelas/data/`)
- `compras_repository.dart`:
  - `watchCompras(String construtoraId, String obraId)`: Stream reativo de compras com ordenação por `createdAt` desc e cache local `read_cache.dart`;
  - `getCompraById(String construtoraId, String obraId, String compraId)`: Busca pontual com cache;
  - `saveCompra(CompraNf compra)`: Salva ou atualiza documento de compra com validação síncrona de invariante das parcelas;
  - `liquidarParcela(...)`: Baixa idempotente de parcela específica com gravação de comprovante e recálculo atômico de status da compra;
  - `receberItensNoEstoque(...)`: Integração transacional que registra o recebimento físico dos materiais e atualiza o almoxarifado;
  - `cancelarCompra(...)`: Cancelamento lógico auditado com justificativa formal.

### 3. Application / Presentation Layer (`app/lib/src/features/compras_parcelas/presentation/`)
- `compras_list_screen.dart`:
  - Listagem responsiva de compras e notas fiscais com filtros por status (`Todas`, `Abertas`, `Pagas`, `Recebidas`, `Atrasadas`);
  - Busca por número de NF ou nome do fornecedor;
  - Cards com badges de valor total, saldo devedor, status de pagamento e status de recebimento;
  - Botão flutuante para "Nova Compra / NF".
- `compra_form_screen.dart`:
  - Formulário completo para inclusão/edição de compra;
  - Autocomplete de Fornecedor Corporativo via `FornecedorAutocompleteField` (Story 5.4);
  - Campos fiscais: Número NF, Série, Chave de Acesso, Data de Emissão, Data de Recebimento;
  - Tabela dinâmica de Itens da Compra: seleção de material do almoxarifado, quantidade, preço unitário e cálculo em tempo real;
  - Campos de encargos: frete, despesas acessórias e desconto;
  - Gerador assistido de parcelas (escolha do número de parcelas $1 \dots 24$, intervalo de dias ou datas, botão "Gerar Parcelas");
  - Tabela editável de parcelas com validação em tempo real e banner de discrepância;
  - Anexo de foto/PDF da NF.
- `compra_detalhes_screen.dart`:
  - Visão detalhada da compra com cabeçalho, itens faturados, status do recebimento físico e tabela de parcelas;
  - Ações rápidas por parcela: botão "Liquidar Parcela" (abre modal de quitação com Pix/comprovante), visualização de recibo;
  - Ação de "Receber Materiais no Almoxarifado" (quando há itens pendentes de recebimento físico).
- `liquidar_parcela_dialog.dart`:
  - Modal para registro de pagamento de parcela individual, com data, método de pagamento, anexo de comprovante e confirmação.

### 4. Firestore Security Rules (`firestore.rules`)
```rules
match /construtoras/{c}/obras/{o}/compras/{compraId} {
  allow read: if admin(c) || obraAdmin(c, o) || member(c)
    && (module(c, 'compras') || module(c, 'almoxarifado') || module(c, 'adm') || module(c, 'financeiro'));
  allow create: if (admin(c) || obraAdmin(c, o) || module(c, 'compras') || module(c, 'adm') || module(c, 'almoxarifado'))
    && request.resource.data.id == compraId
    && request.resource.data.construtoraId == c
    && request.resource.data.obraId == o
    && request.resource.data.totalCompraCents is int
    && request.resource.data.totalCompraCents > 0
    && request.resource.data.status in ['aberto', 'parcial', 'pago', 'cancelado'];
  allow update: if (admin(c) || obraAdmin(c, o) || module(c, 'compras') || module(c, 'adm') || module(c, 'almoxarifado'))
    && request.resource.data.id == compraId
    && request.resource.data.construtoraId == c
    && request.resource.data.obraId == o
    && request.resource.data.status in ['aberto', 'parcial', 'pago', 'cancelado'];
  allow delete: if false; // Governança AD-7: Bloqueio estrito de hard delete
}
```

---

## Verification Plan

### Automated Tests
1. **Testes Unitários de Domínio e Matemática (`compra_parcelamento_math_test.dart`):**
   - Validação da divisão determinística em parcelas sem perda de centavos (ex.: 100000 centavos em 3x).
   - Validação de compras à vista (1 parcela).
   - Detecção síncrona de discrepância quando o usuário altera manualmente o valor de uma parcela.
   - Validação de datas de vencimento sequenciais (30/60/90 dias ou mensal).
2. **Testes Unitários de Repositório (`compras_repository_test.dart`):**
   - Criação e serialização `fromJson` / `toJson` de `CompraNf` com itens e parcelas.
   - Cálculo correto de `totalPagoCents`, `saldoDevedorCents` e transição de status (`aberto` -> `parcial` -> `pago`).
   - Bloqueio de cancelamento de compras que possuem parcelas pagas.
   - Cancelamento com justificativa gravando auditoria.
   - Quitação idempotente de parcela com chave estável.
3. **Testes de Integração com Almoxarifado (`compra_recebimento_estoque_test.dart`):**
   - Geração de movimentações de entrada a partir dos itens da compra/NF com vínculo a `compraId` e `nfNumber`.
   - Atualização da `quantidadeRecebida` e do status de recebimento.
4. **Testes de Widget (`compras_screens_test.dart`):**
   - Renderização da tela de listagem de compras com chips de status e totais.
   - Validação visual do formulário de compra bloqueando submissão quando a soma das parcelas difere do total.
   - Modal de liquidação de parcela com seleção de método de pagamento.
5. **Static Analysis:**
   - `flutter analyze` com 0 erros e 0 warnings.

### Manual Verification
- Acessar a obra ativa no navegador (Flutter Web PWA);
- Acessar o menu de Compras / NF e clicar em "Nova Compra";
- Selecionar um Fornecedor corporativo existente via autocomplete;
- Informar número de NF, adicionar 2 itens com quantidades e valores unitários;
- Solicitar parcelamento em 3 parcelas e verificar a distribuição automática de centavos;
- Salvar a compra e verificar a criação na listagem com status "Aberto";
- Acessar os detalhes e clicar em "Liquidar Parcela 1", selecionando Pix e confirmando;
- Verificar que o status da compra mudou para "Parcial" e o saldo devedor foi abatido;
- Executar o recebimento físico dos materiais e conferir que a movimentação de entrada foi gerada no Almoxarifado com a identificação da NF;
- Tentar excluir a compra e confirmar que a exclusão física é terminantemente bloqueada.

</frozen-after-approval>

## Code Map

- `app/lib/src/features/compras_parcelas/domain/compra_nf.dart`: Entidade agregadora de compra contendo dados fiscais, fornecedor, itens, parcelas, status e totais em centavos.
- `app/lib/src/features/compras_parcelas/domain/item_compra.dart`: Entidade representando item faturado na compra com vínculo a material do almoxarifado e controle de quantidade recebida.
- `app/lib/src/features/compras_parcelas/domain/parcela_compra.dart`: Entidade da parcela com valor em centavos, vencimento, quitação idempotente e comprovante.
- `app/lib/src/features/compras_parcelas/domain/parcelamento_compras_math.dart`: Funções matemáticas puras garantindo a conservação algébrica estrita $\sum \text{parcelas} \equiv \text{totalCompraCents}$.
- `app/lib/src/features/compras_parcelas/data/compras_repository.dart`: Repositório Firestore em `construtoras/{c}/obras/{o}/compras/{id}` com integração com cache local `read_cache.dart`, liquidação idempotente e recebimento no estoque.
- `app/lib/src/features/compras_parcelas/presentation/compras_list_screen.dart`: Tela de listagem responsiva de compras com filtros, indicadores de saldo devedor e busca.
- `app/lib/src/features/compras_parcelas/presentation/compra_form_screen.dart`: Formulário de criação e edição com autocomplete de fornecedor, tabela de itens, cálculo de encargos e gerador de parcelas com validação síncrona de invariante.
- `app/lib/src/features/compras_parcelas/presentation/compra_detalhes_screen.dart`: Visão detalhada de faturamento, liquidação de parcelas e recebimento de estoque.
- `app/lib/src/features/compras_parcelas/presentation/widgets/liquidar_parcela_dialog.dart`: Diálogo de quitação de parcela com dados de pagamento e comprovante.
- `app/lib/src/routing/app_router.dart`: Rotas de navegação para a listagem, cadastro e detalhes de compras da obra.
- `firestore.rules`: Regras de segurança para `compras` com controle de RBAC e bloqueio de exclusão física (`allow delete: if false;`).
- `app/test/compra_parcelamento_math_test.dart`: Testes unitários para a invariante matemática de centavos.
- `app/test/compras_repository_test.dart`: Testes de repositório, integridade de dados e liquidação idempotente.
- `app/test/compras_screens_test.dart`: Testes de widget da listagem e formulário de compras.

## Roteamento (`app_router.dart`)

1. `/construtora/:cId/obra/:oId/compras`: Listagem geral de compras e notas fiscais da obra (`ComprasListScreen`).
2. `/construtora/:cId/obra/:oId/compras/nova`: Cadastro de nova compra/NF (`CompraFormScreen`).
3. `/construtora/:cId/obra/:oId/compras/:compraId`: Detalhes, liquidação e recebimento (`CompraDetalhesScreen`).
4. `/construtora/:cId/obra/:oId/compras/:compraId/editar`: Edição de compra pendente (`CompraFormScreen`).

## Tasks & Acceptance

1. **Domínio e Invariantes Algébricas (AD-5):**
   - [x] Implementar `ParcelamentoComprasMath` com divisão determinística de resto na 1ª parcela e validação de conservação de centavos;
   - [x] Implementar entidades imutáveis `CompraNf`, `ItemCompraNf`, `ParcelaCompra` e enums de status e método de pagamento;
   - [x] Criar suíte de testes unitários `compra_parcelamento_math_test.dart` e `compras_domain_test.dart` cobrindo todas as variações de parcelamento e centavos.
2. **Repositório e Persistência:**
   - [x] Implementar `ComprasRepository` em `construtoras/{c}/obras/{o}/compras/{id}`;
   - [x] Implementar métodos reativos com `read_cache.dart` e `OperationQueue`;
   - [x] Implementar liquidação idempotente de parcelas com controle de chave e recálculo atômico do status da compra;
   - [x] Implementar cancelamento lógico auditado (com justificativa mínima de 10 caracteres) e bloqueio de cancelamento com parcelas pagas.
3. **Integração com Estoque (Epic 3):**
   - [x] Implementar rotina de recebimento físico gerando movimentação de entrada no Almoxarifado com vínculo de `compraId` e `nfNumber`;
   - [x] Atualizar `quantidadeRecebida` dos itens da compra e marcar status de recebimento.
4. **Interface de Usuário (UI):**
   - [x] Implementar `ComprasListScreen` com resumo financeiro (total faturado, total pago, a pagar), filtros e busca;
   - [x] Implementar `CompraFormScreen` integrando `FornecedorAutocompleteField`, lista de itens, encargos e gerador de parcelas com alerta visual de discrepância;
   - [x] Implementar `CompraDetalhesScreen` com visão de faturamento, liquidação de parcelas e recebimento de materiais;
   - [x] Adicionar atalho de Compras / NF no menu/sidebar da Obra e no dashboard.
5. **Segurança e Roteamento:**
   - [x] Adicionar rotas de compras em `app/lib/src/routing/app_router.dart`;
   - [x] Configurar regras de segurança no `firestore.rules` e `storage.rules` com bloqueio estrito de exclusão física (`allow delete: if false;`).
6. **Verificação e Qualidade:**
   - [x] Desenvolver testes de apresentação em `test/compras_presentation_test.dart`;
   - [x] Executar `flutter test` garantindo 100% de aprovação de toda a suíte de testes (283/283 testes passando);
   - [x] Executar `flutter analyze` garantindo 0 erros, 0 warnings e 0 infos;
   - [x] Disparar `hot_reload` na aplicação em execução via DTD.
