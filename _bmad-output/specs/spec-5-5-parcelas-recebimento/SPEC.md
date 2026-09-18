---
id: SPEC-5-5-parcelas-recebimento
companions:
  - ../implementation-artifacts/spec-5-5-parcelas-recebimento.md
sources:
  - ../planning-artifacts/architecture/architecture-epic-5/ARCHITECTURE-SPINE.md
  - ../implementation-artifacts/epic-5-context.md
  - ../../docs/data_model.md
---

> **Canonical contract.** This SPEC and the files in `companions:` are the complete, preservation-validated contract for what to build, test, and validate.

# Story 5.5 — Parcelas e Recebimento de Compras / NF (Desdobramento em Parcelas, Invariante Algébrica e Recebimento no Canteiro)

## Why

Nas obras da construtora, a aquisição de insumos, materiais e contratação de suprimentos envolve notas fiscais faturadas a prazo, entregas programadas e necessidade de conciliação fiscal e financeira rigorosa. Três lacunas críticas comprometiam a operação:
1. **Divergências Matemáticas em Pagamentos Parcelados:** Compras faturadas a prazo frequentemente sofriam furos de centavos ao dividir valores ímpares por números de parcelas (ex.: R$ 1.000,00 em 3x gerando R$ 333,33 com perda de R$ 0,01 no total), gerando inconsistência contábil no contas a pagar e auditoria.
2. **Descasamento entre Faturamento (NF) e Recebimento Físico:** O almoxarife no canteiro realizava entradas manuais desconectadas do documento fiscal e das condições comerciais negociadas, impedindo conferência entre o que foi faturado na NF e o que efetivamente deu entrada física no estoque.
3. **Risco de Pagamentos Duplicados e Falta de Trilha de Liquidação:** A ausência de um mecanismo transacional de quitação de parcelas com controle idempotente expunha a obra a pagamentos em duplicidade e ausência de comprovantes fiscais vinculados.

## Capabilities

- **CAP-1**
  - **intent:** Registrar compras estruturadas de insumos e notas fiscais vinculadas à obra com metadados comerciais completos.
  - **success:** Compras registradas na coleção `construtoras/{cId}/obras/{oId}/compras/{compraId}` contendo número da NF, série, chave de acesso NF-e (44 dígitos), vínculo obrigatório ao fornecedor corporativo (`fornecedorId`, razão social, CNPJ/CPF via Story 5.4), datas de emissão e recebimento físico, anexo comprobatório (foto/PDF do DANFE) e auditoria de autoria.

- **CAP-2**
  - **intent:** Totalizar a composição financeira da compra estritamente em centavos inteiros a partir dos itens faturados e encargos acessórios.
  - **success:** O documento calcula com precisão matemática absoluta $\text{totalCompraCents} \equiv \text{valorItensCents} + \text{freteCents} + \text{despesasAcessoriasCents} - \text{descontoCents}$, detalhando cada item com `materialId`, descrição, unidade, quantidade, valor unitário em centavos e total do item.

- **CAP-3**
  - **intent:** Desdobrar deterministicamente o valor total da compra em $N$ parcelas garantindo a invariante algébrica de conservação de centavos.
  - **success:** O gerador de parcelas distribui os restos da divisão inteira na primeira parcela via `ParcelamentoMath`, garantindo que $\sum_{i=1}^{N} \text{parcela}[i].\text{valorCents} \equiv \text{totalCompraCents}$, com bloqueio síncrono no cliente e validação no domínio se houver qualquer discrepância ($\text{discrepanciaCents} \neq 0$).

- **CAP-4**
  - **intent:** Controlar o ciclo de vida e a liquidação individual de cada parcela com idempotência e registro de comprovantes.
  - **success:** O operador registra a quitação de cada parcela com data de pagamento, método (Pix, Boleto, etc.), identificação do operador (`pagoPorUid`), upload opcional de comprovante em Storage privado e `idempotencyKey` única para blindagem contra quitação dupla, atualizando o status agregado da compra (`aberto`, `parcial`, `pago`).

- **CAP-5**
  - **intent:** Integrar o recebimento físico dos materiais com a movimentação e saldo do Almoxarifado.
  - **success:** O sistema permite efetivar a entrada física no estoque a partir dos itens da compra/NF, registrando a movimentação no Almoxarifado (Epic 3) com referência ao `compraId` e `numeroNf`, atualizando a `quantidadeRecebida` de cada item e o status de recebimento da compra (`pendente`, `parcial`, `recebido`).

- **CAP-6**
  - **intent:** Assegurar governança com bloqueio estrito de exclusão física e cancelamento auditado.
  - **success:** Documentos de compra e parcelas contam com proteção nas regras de segurança do Firestore (`allow delete: if false;`), permitindo apenas cancelamento lógico auditado com justificativa formal mínima de 10 caracteres, preservando a base histórica para a Visão 360º de Custos (Story 5.6).

## Constraints

- **Topologia Firestore Obrigatória:** `construtoras/{cId}/obras/{oId}/compras/{compraId}` conforme AD-1 e AD-5 do Architecture Spine.
- **Invariante Algébrica Inegociável:** Rigorosa observância de $\sum_{i=1}^{N} \text{parcela}[i].\text{valorCents} \equiv \text{totalCompraCents}$ em inteiros (centavos), com tolerância zero para diferenças de arredondamento.
- **Vínculo Corporativo Obrigatório:** O fornecedor da compra deve existir no catálogo central `construtoras/{cId}/fornecedores/{fId}` (Story 5.4).
- **Imutabilidade e Não-Exclusão:** Proibição estrita de hard delete no Firestore (`allow delete: if false;`) em conformidade com AD-7.
- **RBAC Multiobra:** Operações de compra e liquidação autorizadas apenas para usuários com módulos `compras`, `almoxarifado`, `adm`, `financeiro` no array `allowedModules`, além de administradores (`admin(c)`, `obraAdmin(c,o)`) e `dev_roles`.
- **Resiliência Offline:** Suporte a cache e listagem local compatível com PWA e motor de sincronização offline do SIGO.

## Non-goals

- Consulta automatizada e download de XML da NF-e via webservices síncronos da Receita Estadual/SEFAZ (MDe com certificado A1).
- Integração bancária direta para remessa/retorno de pagamentos via CNAB 240/400 ou Open Finance.
- Contabilização por partidas dobradas em plano de contas contábil comercial ou exportação SPED ECD/ECF.

## Success signal

- Módulo de Compras e Parcelas em pleno funcionamento na obra (`construtoras/{cId}/obras/{oId}/compras/{compraId}`), criação de compras/NF com itens estruturados, cálculo automático de parcelas sem desvios de centavos via `ParcelamentoMath`, liquidação de parcelas com comprovante e chave idempotente, opção de dar entrada direta no estoque do Almoxarifado com rastreabilidade mútua, proteção contra exclusão física no Firestore (`allow delete: if false;`), 100% dos testes unitários e de widget passando e zero warnings no `flutter analyze`.
