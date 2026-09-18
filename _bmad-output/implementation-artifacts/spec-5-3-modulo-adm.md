---
title: 'Story 5.3 — Módulo ADM / Contas a Pagar: Despesas Operacionais, Parcelamento, Liquidação Idempotente e Comprovantes'
type: 'feature'
created: '2026-09-18'
status: 'done'
baseline_commit: '1283363e91a0fc05c5b3e3760ba0342f377ed634'
route: 'dispatch'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/specs/spec-5-3-modulo-adm/SPEC.md'
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-epic-5/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-5-context.md'
  - '{project-root}/docs/data_model.md'
  - '{project-root}/docs/task.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:**
No cotidiano da gestão de canteiro, a administração financeira descentralizada enfrenta desafios severos de controle de custos, comprovação fiscal e integridade matemática:
1. **Descentralização e Descontrole de Despesas da Obra:** Custos operacionais rotineiros de canteiro — energia e água provisória, caçambas de entulho, locação de andaimes/betoneiras, pequenas compras de ferramentas, combustíveis e alimentação de equipes — eram lançados de forma genérica na construtora ou controlados em papéis e notas dispersas, impedindo a apuração precisa do custo de cada obra.
2. **Furos de Arredondamento em Títulos Parcelados:** Ao desdobrar um título ou nota em $N$ parcelas, o uso ingênuo de divisão em ponto flutuante gera resíduos fracionários ou furos contábeis (ex.: R$ 100,00 em 3x virando 33,33 + 33,33 + 33,33 = 99,99), acumulando passivos de conciliação.
3. **Riscos de Liquidação em Duplicidade:** Em ambientes com conexões oscilantes no canteiro, múltiplos cliques ou retentativas de envio na fila de sincronização podem duplicar lançamentos de pagamento sem uma chave idempotente garantida.
4. **Ausência de Comprovação Documental Auditável:** Boletos, notas e comprovantes de transferência ou Pix frequentemente se perdem em chats de mensagens sem estarem vinculados indelevelmente à despesa correspondente.

**Approach:**
Implementar o **Módulo ADM / Contas a Pagar no escopo da Obra**, composto por:
1. **Coleção de Despesas da Obra (`despesas_adm`):** Registro formal em `construtoras/{cId}/obras/{oId}/despesas_adm/{despesaId}` com valores estritamente inteiros em centavos (`valorTotalCents`), categorias padronizadas, datas de emissão/vencimento e vinculação com fornecedor.
2. **Invariante Matemática Rígida de Parcelamento (AD-5):** Suporte nativo ao desdobramento da despesa em $N$ parcelas onde a soma dos centavos das parcelas DEVE ser aritmeticamente idêntica ao total do título:
   $$\sum_{i=1}^N \text{parcela}[i].\text{valorCents} \equiv \text{valorTotalCents}$$
   O algoritmo de divisão distribui o resto da divisão inteira na primeira parcela (ou conforme ajuste explícito do usuário), impedindo qualquer discrepância.
3. **Mecanismo de Liquidação Idempotente:** Fluxo de pagamento com registro de `dataPagamento`, `pagoPorUid`, `metodoPagamento` (Pix, Boleto, TED/DOC, Dinheiro, Cartão) e chave única de idempotência (`operationId` ou `paymentKey`), rejeitando pagamentos redundantes.
4. **Upload e Arquivamento de Comprovantes no Firebase Storage Privado:** Upload de PDFs ou imagens de documentos fiscais e comprovantes bancários (`construtoras/{cId}/obras/{oId}/despesas_adm/{despesaId}/{arquivoId}.(pdf|jpg|png)`) com metadados de auditoria.
5. **Apropriação de Custo para Visão 360º (Story 5.6):** Campo opcional `loteId` que aloca a despesa diretamente como custo direto de um lote (`despesasDiretasCents`), ou, na sua ausência, classifica a despesa como custo geral da obra destinado a rateio indireto (`rateioIndiretoCents`).
6. **Imutabilidade e Trilha de Auditoria:** Bloqueio de exclusão física no Firestore (`allow delete: if false;`). Cancelamentos requerem justificativa formal (`motivoCancelamento`), registrando quem cancelou e a data/hora.

---

## Boundaries & Constraints

**Always:**
- Salvar as despesas no caminho hierárquico `construtoras/{cId}/obras/{oId}/despesas_adm/{despesaId}`.
- Tratar e armazenar valores monetários estritamente como inteiros em centavos (`valorTotalCents`, `valorCents`, `saldoDevedorCents`).
- Garantir a invariante $\sum \text{parcelas} \equiv \text{valorTotalCents}$ antes de persistir qualquer despesa parcelada.
- Exigir `operationId` / `paymentKey` em cada liquidação para garantir idempotência em contingência offline e retentativas.
- Proibir estritamente a exclusão física (hard delete) de qualquer despesa confirmada ou liquidada (`allow delete: if false;`).
- Exigir justificativa formal (`motivoCancelamento`) de pelo menos 10 caracteres para cancelamento de despesas em aberto.
- Restringir leitura e escrita a usuários autorizados com o módulo `adm` (ou legado `financeiro`) no array `allowedModules`, administradores da obra (`obraAdmin`), administradores da construtora (`admin`) ou `dev_roles`.
- Proteger o Storage privado contra uploads com mais de 10MB ou formatos não permitidos (permitidos apenas `application/pdf`, `image/jpeg`, `image/png`, `image/webp`).

**Never:**
- Nunca permitir exclusão física de registros de despesa (`allow delete: if false;`).
- Nunca usar ponto flutuante (`double` ou `float`) para armazenar valores monetários ou verificar saldos.
- Nunca permitir a liquidação de uma despesa ou parcela que já possua status `pago` ou `cancelado`.
- Nunca salvar uma despesa parcelada cuja soma das parcelas divirja em 1 centavo sequer do valor total.
- Nunca permitir alteração de valor ou parcelas em despesas já liquidadas.

---

## I/O & Edge-Case Matrix

| Cenário | Entrada / Estado | Saída Esperada | Tratamento de Erro |
|---|---|---|---|
| **Cadastro de Despesa à Vista** | Descrição: "Locação de Andaimes", Categoria: `locacao`, Vencimento: `2026-10-15`, Valor: `R$ 450,00` (`45000` centavos) | Documento salvo em `despesas_adm` com `valorTotalCents: 45000`, `status: 'pendente'`, `isParcelado: false`. | Bloqueio se valor <= 0 ou descrição vazia |
| **Parcelamento Automático sem Resto** | Valor: `R$ 300,00` (`30000`), 3 parcelas mensais | Gera 3 parcelas de `R$ 100,00` (`10000` centavos cada), somando exatamente `30000`. | Invariante validada síncronamente |
| **Parcelamento com Resto de Centavos** | Valor: `R$ 100,00` (`10000`), 3 parcelas mensais | Parcela 1: `R$ 33,34` (`3334`); Parcela 2: `R$ 33,33` (`3333`); Parcela 3: `R$ 33,33` (`3333`). Soma: `10000`. | Algoritmo distribui os centavos excedentes na primeira parcela |
| **Edição Manual de Parcelas com Discrepância** | Usuário altera manualmente as parcelas para somar `9999` centavos em documento de `10000` | Sistema bloqueia gravação com alerta: "A soma das parcelas (R$ 99,99) difere do valor total (R$ 100,00) por R$ 0,01". | Validação síncrona na UI e rejeição no Firestore |
| **Liquidação de Despesa com Sucesso** | Despesa pendente, Método: `pix`, Data: Hoje, Operação: `pay-d123-uuid` | Status atualizado para `pago`, gravados `dataPagamento`, `pagoPorUid` e chave idempotente. | Atualização atômica |
| **Tentativa de Pagamento Duplo** | Operador clica duas vezes rapidamente no botão "Marcar como Pago" | Primeira requisição processa a liquidação; segunda requisição é descartada pela chave idempotente sem efeitos colaterais. | Idempotência garantida |
| **Upload de Comprovante em PDF** | Arquivo `recibo_pagamento.pdf` (1.2 MB) | Arquivo enviado para `despesas_adm/{id}/{arquivoId}.pdf`, gravando URL e metadados no documento da despesa. | Validação de extensão e tamanho máximo (10MB) |
| **Upload de Formato Inválido** | Arquivo `.exe` ou arquivo > 10MB | Upload bloqueado pelo cliente e rejeitado pelas regras do Storage. | Erro amigável exibido na UI |
| **Alocação Direta a um Lote** | Despesa de "Pintura Externa Lote 05" com `loteId: 'lote_05'` | Despesa salva com `loteId: 'lote_05'`, pronta para agregação direta na Visão 360 do lote. | Lote deve existir na obra |
| **Cancelamento de Despesa Pendente** | Usuário clica em Cancelar e informa motivo: "Boleto cancelado pelo fornecedor" | Status alterado para `cancelado`, gravados `motivoCancelamento`, `canceladoPorUid` e `dataCancelamento`. | Mínimo de 10 caracteres de justificativa |
| **Tentativa de Hard Delete** | Usuário tenta deletar documento de despesa | Operação bloqueada pelas regras de segurança (`allow delete: if false;`). | Erro de permissão do Firestore |

---

## Data Models & Firestore Topology

### 1. Despesa Operacional da Obra (`despesas_adm`)
Path: `construtoras/{cId}/obras/{oId}/despesas_adm/{despesaId}`

```json
{
  "id": "desp_20260918_001",
  "construtoraId": "cId",
  "obraId": "oId",
  "descricao": "Locação de Andaimes Fachadeiros - 30 dias",
  "categoria": "locacao",
  "fornecedorNome": "Andaimes & Cia Ltda",
  "fornecedorId": "forn_123",
  "loteId": null,
  "valorTotalCents": 150000,
  "status": "pendente",
  "dataEmissao": "2026-09-18T10:00:00.000Z",
  "dataVencimento": "2026-10-10",
  "dataPagamento": null,
  "pagoPorUid": null,
  "metodoPagamento": null,
  "comprovanteUrl": null,
  "comprovantePath": null,
  "comprovanteNome": null,
  "isParcelado": true,
  "parcelas": [
    {
      "numero": 1,
      "valorCents": 75000,
      "dataVencimento": "2026-10-10",
      "status": "pendente",
      "dataPagamento": null,
      "pagoPorUid": null,
      "metodoPagamento": null,
      "comprovanteUrl": null,
      "comprovantePath": null,
      "idempotencyKey": null
    },
    {
      "numero": 2,
      "valorCents": 75000,
      "dataVencimento": "2026-11-10",
      "status": "pendente",
      "dataPagamento": null,
      "pagoPorUid": null,
      "metodoPagamento": null,
      "comprovanteUrl": null,
      "comprovantePath": null,
      "idempotencyKey": null
    }
  ],
  "motivoCancelamento": null,
  "canceladoPorUid": null,
  "dataCancelamento": null,
  "responsavelId": "uid_admin",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp",
  "schemaVersion": 1
}
```

### 2. Categorias Padronizadas de Despesa ADM
- `utilidades` (Energia, Água, Internet canteiro, Gás)
- `locacao` (Equipamentos, Andaimes, Betoneiras, Caçambas, Banheiros químicos)
- `servicosTerceiros` (Projetos complementares, Topografia, Sondagem, Limpeza de obra, Ensaio tecnológico)
- `alimentacao` (Café da manhã, Marmitas, Refeições de equipe)
- `combustivel` (Abastecimento de veículos, Geradores)
- `taxasLicencas` (Alvarás, ARTs/RRTs, Licenças ambientais, Taxas municipais)
- `outros` (Despesas administrativas gerais não classificadas)

### 3. Enums de Domínio
- **`StatusDespesaAdm`:** `pendente`, `pago`, `atrasado`, `cancelado`
- **`MetodoPagamento`:** `pix`, `boleto`, `transferencia`, `dinheiro`, `cartao`, `outro`

---

## Invariante Algébrica de Parcelamento

Para desdobrar um montante $V$ em $N$ parcelas mensais com vencimento inicial em $D_0$:
```dart
List<ParcelaDespesa> gerarParcelas({
  required int totalCents,
  required int numeroParcelas,
  required DateTime primeiroVencimento,
}) {
  assert(totalCents > 0);
  assert(numeroParcelas > 0);

  final baseCents = totalCents ~/ numeroParcelas;
  final restoCents = totalCents % numeroParcelas;

  return List.generate(numeroParcelas, (index) {
    // Distribui o resto da divisão inteira na primeira parcela
    final valorParcela = index == 0 ? baseCents + restoCents : baseCents;
    final vencimento = DateTime(
      primeiroVencimento.year,
      primeiroVencimento.month + index,
      primeiroVencimento.day,
    );

    return ParcelaDespesa(
      numero: index + 1,
      valorCents: valorParcela,
      dataVencimento: vencimento,
      status: StatusDespesaAdm.pendente,
    );
  });
}
```
**Garantia:** $\sum_{i=1}^N \text{parcela}[i].\text{valorCents} \equiv \text{totalCents}$ em 100% dos casos.

---

## Security Rules & RBAC

### `firestore.rules`
```javascript
// Despesas ADM no escopo da obra
match /construtoras/{cId}/obras/{oId}/despesas_adm/{dId} {
  allow read: if isObraMember(cId, oId) || isAdmin(cId) || isDev();
  allow create: if (hasObraModule(cId, oId, 'adm') || hasObraModule(cId, oId, 'financeiro') || isObraAdmin(cId, oId) || isAdmin(cId) || isDev())
    && request.resource.data.id == dId
    && request.resource.data.construtoraId == cId
    && request.resource.data.obraId == oId
    && request.resource.data.valorTotalCents is int
    && request.resource.data.valorTotalCents > 0
    && request.resource.data.status in ['pendente', 'pago', 'atrasado', 'cancelado'];

  allow update: if (hasObraModule(cId, oId, 'adm') || hasObraModule(cId, oId, 'financeiro') || isObraAdmin(cId, oId) || isAdmin(cId) || isDev())
    && request.resource.data.id == resource.data.id
    && request.resource.data.construtoraId == cId
    && request.resource.data.obraId == oId
    // Proibido alterar valor de despesas já liquidadas
    && (resource.data.status != 'pago' || request.resource.data.valorTotalCents == resource.data.valorTotalCents)
    // Cancelamento exige justificativa formal
    && (request.resource.data.status != 'cancelado' || (request.resource.data.motivoCancelamento is string && request.resource.data.motivoCancelamento.size() >= 10));

  allow delete: if false; // Proibido hard delete de despesas contábeis
}
```

### `storage.rules`
```javascript
// Anexos e comprovantes de despesas ADM
match /construtoras/{c}/obras/{o}/despesas_adm/{despesaId}/{filename} {
  allow read: if access(c,o);
  allow create: if access(c,o)
    && request.resource.size > 0
    && request.resource.size <= 10 * 1024 * 1024 // Até 10MB
    && (request.resource.contentType.matches('image/(jpeg|png|webp)') || request.resource.contentType == 'application/pdf');
  allow update, delete: if false; // Imutabilidade de comprovantes anexados
}
```

---

## Estrutura de Código no Flutter

```text
app/lib/src/features/despesas_adm/
  domain/
    despesa_adm.dart             # Entidade DespesaAdm, ParcelaDespesa e Enums de Status/Categoria/Método
    parcelamento_math.dart       # Algoritmo determinístico de parcelamento e verificação de soma de centavos
  data/
    despesas_adm_repository.dart # Streams, CRUD, liquidação idempotente e upload Storage
  presentation/
    despesas_adm_list_screen.dart # Lista de contas a pagar da obra com cards de resumo (A Pagar / Pago / Atrasado)
    despesa_adm_form_screen.dart  # Cadastro/Edição de despesa com desdobramento de parcelas e anexo de PDF
    despesa_liquidar_dialog.dart  # Modal de quitação/liquidação com método de pagamento e comprovante
    widgets/
      parcelas_editor_widget.dart # Componente interativo para edição e conferência da soma de parcelas
      despesa_card.dart           # Card com badges de status, categoria, vencimento e lote associado
```

---

## Roteamento (`app_router.dart`)

1. `/construtora/:cId/obra/:oId/despesas`: Tela principal de contas a pagar da obra (`DespesasAdmListScreen`).
2. `/construtora/:cId/obra/:oId/despesas/nova`: Formulário de cadastro de nova despesa (`DespesaAdmFormScreen`).
3. `/construtora/:cId/obra/:oId/despesas/:despesaId`: Detalhes, visualização de parcelas, comprovantes e ações de liquidação.

Ambas as rotas protegidas via `AccessGuard(construtoraId: cId, obraId: oId, module: 'adm')`.

</frozen-after-approval>

## Code Map

- `app/lib/src/features/despesas_adm/domain/despesa_adm.dart`: Modelos de domínio com serialização e cálculo de centavos.
- `app/lib/src/features/despesas_adm/domain/parcelamento_math.dart`: Lógica pura de cálculo de parcelas e validação da invariante $\sum \text{parcelas} \equiv \text{totalCents}$.
- `app/lib/src/features/despesas_adm/data/despesas_adm_repository.dart`: Repositório com suporte a Firestore, Storage e cache offline `read_cache`.
- `app/lib/src/features/despesas_adm/presentation/despesas_adm_list_screen.dart`: Listagem de contas a pagar com filtros por status (todos, pendentes, pagos, atrasados) e cards de totais.
- `app/lib/src/features/despesas_adm/presentation/despesa_adm_form_screen.dart`: Formulário de despesa com gerador de parcelas, seleção de lote e upload de PDF/imagem.
- `app/lib/src/features/despesas_adm/presentation/despesa_liquidar_dialog.dart`: Diálogo de confirmação de liquidação com seleção do método de pagamento e anexo de comprovante.
- `app/lib/src/routing/app_router.dart`: Rotas de navegação protegidas por RBAC para o módulo `adm`.
- `app/lib/src/core/contracts.dart`: Mapeamento e normalização do módulo `financeiro` -> `adm` em `normalizeModule`.
- `firestore.rules`: Regras de segurança para `despesas_adm` na obra com proibição de hard delete.
- `storage.rules`: Regras de segurança para upload de PDFs e imagens comprovatórias em `despesas_adm`.
- `app/test/despesas_adm_math_test.dart`: Testes unitários para a invariante matemática de parcelamento e cálculos em centavos.
- `app/test/despesas_adm_repository_test.dart`: Testes unitários de repositório e liquidação idempotente.
- `app/test/despesas_adm_presentation_test.dart`: Testes de widget da listagem e formulário de despesas.

## Tasks & Acceptance

1. **Domínio e Invariante de Parcelamento:**
   - [x] Implementar `DespesaAdm`, `ParcelaDespesa` e enums em `app/lib/src/features/despesas_adm/domain/despesa_adm.dart`;
   - [x] Criar `parcelamento_math.dart` com gerador de parcelas e validação da soma exata em centavos;
   - [x] Desenvolver suíte de testes unitários `app/test/despesas_adm_math_test.dart` com 100% de cobertura dos casos limites (valores ímpares, 3x, 7x, 12x, resto de centavos).
2. **Repositório e Operações Contábeis:**
   - [x] Criar `DespesasAdmRepository` em `app/lib/src/features/despesas_adm/data/despesas_adm_repository.dart`;
   - [x] Implementar streams reativas integradas ao `read_cache` (`cachedList`);
   - [x] Implementar fluxo de liquidação idempotente com registro de `operationId`, `dataPagamento` e `pagoPorUid`;
   - [x] Implementar upload e anexo de comprovantes em PDF/imagem no Storage.
3. **Interface de Usuário (UI):**
   - [x] Implementar `DespesasAdmListScreen` com resumo financeiro (Total A Pagar, Total Pago, Total Vencido) e cards de despesas;
   - [x] Implementar `DespesaAdmFormScreen` com alternador de despesa única/parcelada, gerador automático de parcelas, seleção de lote e anexo de arquivo;
   - [x] Desenvolver modal `DespesaLiquidarDialog` para quitação com seleção do método de pagamento e anexo de comprovante Pix/TED;
   - [x] Integrar atalho para o módulo ADM na navegação da Obra (`obras_list_screen` / menu de módulos).
4. **Segurança e Roteamento:**
   - [x] Atualizar `app/lib/src/routing/app_router.dart` com as rotas do módulo `adm` protegidas por `AccessGuard`;
   - [x] Atualizar `firestore.rules` incluindo o nó `despesas_adm` sob `obras/{o}` com bloqueio de exclusão física (`allow delete: if false;`);
   - [x] Atualizar `storage.rules` permitindo upload seguro de PDFs e imagens para `despesas_adm/{despesaId}/...`.
5. **Verificação e Qualidade:**
   - [x] Criar testes de widget e de fluxo em `app/test/despesas_adm_presentation_test.dart`;
   - [x] Executar `flutter test` garantindo que todos os testes passem (252 testes passaram com 100% de aprovação);
   - [x] Executar `flutter analyze` garantindo 0 erros e 0 warnings.

---

## Review Findings

- **Conformidade de Tipos:** Valores monetários manipulados e persistidos estritamente como inteiros em centavos (`int`), sem desvios de precisão ou ponto flutuante.
- **Invariante de Parcelamento:** Cobertura de testes unitários comprova preservação estrita de $\sum_{i=1}^N \text{parcela}[i].\text{valorCents} \equiv \text{valorTotalCents}$ distribuindo restos determinísticos na primeira parcela.
- **Segurança Contábil:** Imutabilidade de histórico garantida com proibição de hard delete em `firestore.rules` (`allow delete: if false;`) e cancelamento auditado com exigência de justificativa de no mínimo 10 caracteres.
- **Auditoria de Liquidação:** Registro de `paymentKey` / `operationId`, data e UID do operador de quitação.
- **Qualidade de Código:** 252 testes automatizados aprovados na suíte e análise estática limpa (0 issues). Hot reload aplicado com sucesso na sessão ativa do aplicativo.

