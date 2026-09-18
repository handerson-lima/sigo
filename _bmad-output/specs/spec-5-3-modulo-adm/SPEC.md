---
id: SPEC-5-3-modulo-adm
companions:
  - ../implementation-artifacts/spec-5-3-modulo-adm.md
sources:
  - ../planning-artifacts/architecture/architecture-epic-5/ARCHITECTURE-SPINE.md
  - ../implementation-artifacts/epic-5-context.md
---

> **Canonical contract.** This SPEC and the files in `companions:` are the complete, preservation-validated contract for what to build, test, and validate.

# Story 5.3 — Módulo ADM / Contas a Pagar: Despesas Operacionais, Parcelamento, Liquidação Idempotente e Comprovantes

## Why

A administração financeira de canteiro e o controle de despesas operacionais no SIGO demandam um controle formal de contas a pagar da obra para sanar três gargalos críticos:
1. **Falta de Segregação e Rastreabilidade por Obra:** Muitas despesas de canteiro (energia/água provisória, caçambas de entulho, alimentação da equipe, locação de andaimes, pequenas ferramentas e serviços de terceiros) eram registradas de forma dispersa ou anotadas em recibos de papel, impedindo a apuração exata do custo operacional direto da obra.
2. **Divergência de Arredondamento e Furos de Parcelamento:** Títulos faturados em várias parcelas sofriam riscos de furos contábeis em centavos decorrentes de divisão em ponto flutuante sem controle rígido, violando a integridade contábil do sistema.
3. **Riscos de Pagamento em Duplicidade e Falta de Comprovação Fiscal:** Liquidações sem chave de idempotência e sem arquivamento auditável de notas, boletos e comprovantes em PDF deixavam a construtora exposta a pagamentos duplicados e desorganização fiscal.

## Capabilities

- **CAP-1**
  - **intent:** Cadastrar e gerenciar despesas operacionais e contas a pagar no escopo da obra com valores estritamente em centavos.
  - **success:** Usuários autorizados cadastram despesas (`construtoras/{cId}/obras/{oId}/despesas_adm/{despesaId}`) contendo descrição, categoria padronizada (Utilidades, Locação de Equipamentos, Serviços de Terceiros, Alimentação, Combustível, Taxas/Licenças, Outros), data de vencimento, data de emissão, fornecedor e valor estritamente inteiro em centavos (`amountCents`).

- **CAP-2**
  - **intent:** Desdobrar despesas em parcelas com garantia matemática da invariante contábil de soma dos centavos.
  - **success:** O sistema permite desdobrar uma despesa em $N$ parcelas, assegurando de forma síncrona e determinística que a soma exata das parcelas seja idêntica ao valor total do título ($\sum_{i=1}^N \text{parcela}[i].\text{amountCents} \equiv \text{totalDocumentoCents}$), bloqueando gravações com discrepâncias de centavos.

- **CAP-3**
  - **intent:** Realizar a liquidação idempotente de despesas ou parcelas prevenindo pagamento duplo.
  - **success:** O operador registra a liquidação informando data do pagamento, método de quitação (Pix, Boleto, Transferência, Dinheiro, Cartão) e chave única de idempotência (`operationId` ou `paymentKey`), atualizando o status para `pago` e impedindo liquidação em duplicidade tanto online quanto em contingência offline.

- **CAP-4**
  - **intent:** Anexar e visualizar comprovantes e documentos fiscais em PDF ou imagens no Storage privado.
  - **success:** O sistema efetua upload seguro de boletos, notas fiscais e comprovantes bancários para `construtoras/{cId}/obras/{oId}/despesas_adm/{despesaId}/{arquivoId}.(pdf|jpg|png)`, registrando metadados de auditoria e restringindo o acesso exclusivamente a usuários com perfil autorizado.

- **CAP-5**
  - **intent:** Apropriar despesas diretas ao lote ou classificá-las para rateio indireto da Visão 360º.
  - **success:** Ao cadastrar ou editar uma despesa, o usuário pode associá-la a um `loteId` específico da obra (alimentando o cubo de `despesasDiretasCents`) ou classificá-la como despesa geral da obra (destinada a compor o `rateioIndiretoCents` na Story 5.6).

## Constraints

- **Imutabilidade Contábil:** Despesas e parcelas liquidadas (`status: 'pago'`) ou confirmadas não podem sofrer exclusão física no Firestore (`allow delete: if false;`). Cancelamentos requerem justificativa formal (`motivoCancelamento`) e preservam trilha histórica.
- **Invariante Monetária Rígida:** Todos os valores financeiros são expressos exclusivamente em números inteiros de centavos (`amountCents` / `valorEmCentavos`), proibindo cálculos ou arredondamentos em ponto flutuante.
- **Invariante de Parcelamento:** Para qualquer despesa parcelada, $\sum \text{parcelas} \equiv \text{totalCents}$. A violação dessa condição rejeita a gravação.
- **Segurança e RBAC:** Acesso restrito a usuários com módulo `adm` (ou legado `financeiro`) em `allowedModules`, administradores da obra (`obraAdmin`), administradores gerais (`admin`) ou `dev_roles`.
- **Storage Privado:** Comprovantes e PDFs residem sob caminhos protegidos com limite de tamanho (até 10MB) e tipagem segura (`application/pdf`, `image/jpeg`, `image/png`, `image/webp`).
- **Resiliência Offline:** Listagens e registros suportam cache offline (`read_cache`) e enfileiramento na `OperationQueue` com conciliação síncrona no retorno da rede.

## Non-goals

- Integração bancária direta via APIs de Open Finance ou conciliação automática com arquivos CNAB 240/400 (liquidação é declaratória com comprovante anexado).
- Extração automática de dados via OCR ou parser de XML de NF-e (campos são informados pelo operador nesta release).
- Emissão de notas fiscais ou retenção automática de tributos municipais/federais (ISS, IRRF, INSS retido na fonte).

## Success signal

- Gestão completa de contas a pagar da obra no app, parcelamento com garantia matemática de centavos, upload e visualização de comprovantes em PDF/imagem no Storage privado, fluxo de liquidação idempotente com chave de segurança, integração com regras Firestore/Storage atualizadas (`allow delete: if false;`), 100% dos testes unitários e de widget passando e zero warnings no `flutter analyze`.
