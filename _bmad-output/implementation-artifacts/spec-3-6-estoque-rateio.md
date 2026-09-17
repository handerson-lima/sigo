---
title: 'Story 3.6 — Estoque: Rateio de Despesas e Frete'
type: 'feature'
created: '2026-09-17'
status: 'done'
baseline_commit: '62eb4626117df3c964a337239a6e9ed4746d7544'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-3-context.md'
  - '{project-root}/docs/task.md'
  - '{project-root}/docs/user_flows.md'
  - '{project-root}/docs/archive/2026-09-15-planejamento-anterior/implementation_plan.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O recebimento de materiais no almoxarifado central (`MovimentacaoType.entrada`) registra atualmente apenas a quantidade física e metadados descritivos da compra (NF/fornecedor/evidência), sem suporte ao registro, apropriação e rateio dos custos financeiros acessórios de aquisição (valor dos itens, frete, despesas adicionais de descarga/seguro e eventuais descontos). Consequentemente, o custo unitário efetivo do insumo no estoque não é apurado no ato de recebimento, custos de frete e despesas não são distribuídos com rastreabilidade, e o histórico de movimentações não discrimina a composição financeira do material recebido.

**Approach:** Evoluir o modelo de dados de movimentação de estoque (`Movimentacao`) e a tela de recebimento (`MovimentacaoScreen`) para incluir campos opcionais e estruturados de rateio financeiro em centavos inteiros (`valorItensCentavos`, `freteCentavos`, `despesasCentavos`, `descontoCentavos`, `custoTotalCentavos` e `custoUnitarioCentavos`); prover cálculo automático em tempo real na interface do Custo Total e do Custo Unitário Efetivo do material; validar invariantes de valores não-negativos e bloqueio de descontos superiores ao custo bruto; repassar os dados ao backend transacional (`stockCommand` via `OperationQueue` e `functions/src/index.ts`); e exibir badges informativos com o custo unitário apurado e discriminação do rateio de frete/despesas no histórico de estoque (`StockHistoryScreen`).

## Boundaries & Constraints

**Always:**
- Toda quantia monetária deve ser manipulada e persistida em **centavos inteiros** (`int` seguros, `cents`), sem uso de ponto flutuante para armazenamento monetário permanente.
- Custo Total de Entrada é calculado como: `valorItensCentavos + freteCentavos + despesasCentavos - descontoCentavos`.
- Custo Unitário Efetivo é calculado como `(custoTotalCentavos / quantidade).round()`, apurado em centavos por unidade de estoque.
- O Custo Total não pode ser negativo (`custoTotalCentavos >= 0`). Se `descontoCentavos` for superior a `valorItensCentavos + freteCentavos + despesasCentavos`, a interface e o backend devem bloquear a operação.
- O preenchimento dos custos financeiros na entrada de estoque é opcional (permitindo entradas puramente físicas quando aplicável), mas quando fornecidos, os valores individuais devem ser inteiros não-negativos.
- No histórico de movimentações (`StockHistoryScreen`), entradas com rateio financeiro devem exibir badge com Custo Unitário Efetivo (ex: `R$ 32,50/un`) e detalhamento expansível/discriminado dos componentes de custo (Itens, Frete, Despesas, Descontos).
- Preservar separação contábil e gerencial: O rateio do frete e despesas compõe o custo de entrada dos materiais no almoxarifado, sem gerar débitos automáticos diretos em lotes antes da requisição de saída de material correspondente.
- Preservar retrocompatibilidade total: movimentações pré-existentes sem metadados financeiros devem continuar sendo serializadas e exibidas normalmente sem regressões (`null`-safety garantido).
- Enfileirar via `OperationQueue.instance.enqueue('stockCommand', ...)` com `operationId` estável UUID v4 e idempotência preservada.

**Never:**
- Nunca usar números em ponto flutuante (`double`) para armazenamento monetário persistente.
- Nunca permitir valores negativos para valor dos itens, frete ou despesas.
- Nunca permitir custo total negativo decorrente de descontos arbitrários.
- Nunca criar pendência ou débito financeiro direto a um lote no recebimento central de suprimentos.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Recebimento com Rateio Completo (Itens + Frete + Despesas - Desconto) | Quantidade: `50 Saco`. Valor Itens: `R$ 1.500,00` (150000¢), Frete: `R$ 100,00` (10000¢), Despesas: `R$ 50,00` (5000¢), Desconto: `R$ 20,00` (2000¢) | Interface calcula e exibe Custo Total `R$ 1.630,00` e Custo Unitário `R$ 32,60 / Saco`. Enfileira `stockCommand` com metadados financeiros completos | SnackBar de confirmação pendente |
| Recebimento com Apenas Frete Rateado | Quantidade: `100 m²`. Valor Itens: `R$ 2.000,00` (200000¢), Frete: `R$ 250,00` (25000¢), Despesas: `0`, Desconto: `0` | Custo Total calculado `R$ 2.250,00`, Custo Unitário `R$ 22,50 / m²`. Comando enfileirado com sucesso | SnackBar de confirmação pendente |
| Desconto Maior que Custo Bruto | Valor Itens: `R$ 100,00`, Frete: `R$ 0,00`, Desconto: `R$ 150,00` | Interface detecta custo total negativo, exibe aviso vermelho e bloqueia submissão com "Desconto não pode exceder o valor total" | Bloqueio síncrono no formulário |
| Valor Monetário Negativo ou Inválido | Usuário digita `-50` ou caractere inválido nos campos de frete/despesas | Campo acusa "Informe um valor monetário válido" | Validação síncrona de campo |
| Entrada Simples sem Informação Financeira | Quantidade: `30 Saco`. Seção de rateio financeiro mantida em branco | Movimentação registrada sem campos de custos (`null`), preservando compatibilidade retroativa | N/A |
| Exibição de Rateio no Histórico | Movimentação de entrada com rateio carregada em `StockHistoryScreen` | Exibe badge de Custo Unitário (`R$ 32,60/un`) e linha discriminada com `Itens: R$ 1.500,00 | Frete: R$ 100,00 | Desp: R$ 50,00 | Desc: R$ 20,00` | N/A |
| Movimentação Histórica Antiga sem Custos | Movimentação legada com `valorItensCentavos == null` | Card renderiza normalmente dados da movimentação sem exibir blocos financeiros ou gerar erros de nulo | N/A |

</frozen-after-approval>

## Code Map

- `app/lib/src/features/almoxarifado/domain/movimentacao.dart` -- Expandir modelo `Movimentacao` com campos `valorItensCentavos`, `freteCentavos`, `despesasCentavos`, `descontoCentavos`, `custoTotalCentavos`, `custoUnitarioCentavos`.
- `app/lib/src/features/almoxarifado/domain/movimentacao.g.dart` -- Atualizar serialização e desserialização JSON do modelo.
- `app/lib/src/features/almoxarifado/data/almoxarifado_repository.dart` -- Incluir campos financeiros no payload do comando transacional enfileirado (`stockCommand`).
- `app/lib/src/features/almoxarifado/presentation/movimentacao_screen.dart` -- Adicionar seção expansível/acessível de custos e rateio na entrada de materiais com campos para Itens, Frete, Despesas e Descontos, cálculo reativo em tempo real de Custo Total e Custo Unitário, e validações de consistência.
- `app/lib/src/features/almoxarifado/presentation/stock_history_screen.dart` -- Apresentar chip/badge de Custo Unitário Efetivo e painel discriminado de rateio no card da movimentação de entrada.
- `functions/src/index.ts` -- Persistir campos financeiros de rateio no documento de movimentação criado na transação de `stockCommand`.
- `app/test/stock_rateio_test.dart` -- Suíte abrangente de testes automatizados unitários e de widget cobrindo cálculos de rateio, validações da matriz I/O e renderização no histórico.

## Tasks & Acceptance

**Execution:**
- [x] `app/lib/src/features/almoxarifado/domain/movimentacao.dart` -- Implementar campos financeiros de rateio (`valorItensCentavos`, `freteCentavos`, `despesasCentavos`, `descontoCentavos`, `custoTotalCentavos`, `custoUnitarioCentavos`).
- [x] `app/lib/src/features/almoxarifado/domain/movimentacao.g.dart` -- Regenerar serializadores do modelo `Movimentacao`.
- [x] `app/lib/src/features/almoxarifado/data/almoxarifado_repository.dart` -- Mapear e repassar campos de rateio no payload de `stockCommand`.
- [x] `app/lib/src/features/almoxarifado/presentation/movimentacao_screen.dart` -- Construir interface de custos e rateio com cálculo dinâmico de Custo Total e Custo Unitário Efetivo e validações.
- [x] `app/lib/src/features/almoxarifado/presentation/stock_history_screen.dart` -- Exibir badge de custo unitário efetivo e discriminação do rateio de frete e despesas no histórico de movimentações.
- [x] `functions/src/index.ts` -- Gravar metadados de rateio financeiro na movimentação na Cloud Function transacional `stockCommand`.
- [x] `app/test/stock_rateio_test.dart` -- Criar testes unitários e de widget cobrindo todos os cenários da Matriz I/O.

**Acceptance Criteria:**
- Given um usuário no formulário de entrada de material, when informa quantidade de 50 unidades, valor dos itens R$ 1.500,00, frete R$ 100,00, despesas R$ 50,00 e desconto R$ 20,00, then o formulário exibe em tempo real Custo Total de R$ 1.630,00 e Custo Unitário de R$ 32,60/unidade, e ao submeter enfileira `stockCommand` com todos os valores em centavos inteiros.
- Given um usuário preenchendo o rateio financeiro, when o valor do desconto informado for maior que a soma de itens + frete + despesas, then o sistema impede a submissão e exibe alerta de que o desconto não pode exceder o valor total.
- Given uma movimentação de entrada confirmada com dados de rateio, when o histórico de estoque é aberto, then o card da movimentação apresenta o badge destacado de custo unitário e o detalhamento dos valores de frete, despesas e desconto.
- Given movimentações de estoque antigas gravadas sem campos de rateio, when carregadas na aplicação, then são renderizadas normalmente sem erros de serialização ou nulos.

## Implementation Notes

- **Modelagem em Centavos:** Todos os valores financeiros de entrada (`valorItensCentavos`, `freteCentavos`, `despesasCentavos`, `descontoCentavos`, `custoTotalCentavos`, `custoUnitarioCentavos`) são tipados como inteiros (`int?`), eliminando erros de arredondamento inerentes a ponto flutuante.
- **Helper de Conversão Robusto:** Implementado `_parseCurrencyToCents` na tela para tratar tanto separador decimal brasileiro (`1.500,50`) quanto ponto (`1500.50`), com validação regex estrita.
- **Transacionalidade e Validação em Camadas:** A Cloud Function transacional valida que `custoTotalCentavos >= 0` antes de gravar no Firestore, enquanto o frontend previne antecipadamente o envio com validação de formulário.
- **Compatibilidade Retroativa:** Movimentações de estoque pré-existentes sem rateio retornam `temRateio == false` e são renderizadas sem impacto ou regressão visual no histórico.
- **Suíte de Testes:** Criados 9 testes em `test/stock_rateio_test.dart` exercitando todas as linhas da matriz I/O (cálculos puros, validações, persistência via mock de fila e renderização no histórico). Suíte completa de 157 testes no Flutter e 8 suítes nas Cloud Functions passando com 100% de sucesso.

## Spec Change Log

*Nenhuma alteração de escopo ou de freeze requerida durante a implementação.*

## Review Triage Log

| Finding | Severity | Category | Decision / Action |
|---|---|---|---|
| Possibilidade de divisão por zero ao calcular custo unitário com quantidade zero | High | patch | Prevenido por guarda explícita `if (quantidade <= 0) return 0` no helper e validação de quantidade mínima > 0 |
| Desconto superior ao custo bruto dos itens + frete + despesas | Medium | patch | Validado sincronicamente no `validator` do campo e no `_submitForm` com bloqueio de envio e feedback visual claro |
| Falha de compatibilidade com movimentações legadas sem campos financeiros | High | patch | Campos são opcionais (`int?`), getters `temRateio` blindados contra `null`, e testes garantem renderização suave sem erros |
| Timeout ou overflow de renderização em telas menores com campos adicionais | Low | patch | Formulário envelopado em `ListView` com rolagem vertical livre e `tester.ensureVisible` nos testes de widget |

## Verification

**Commands:**
- `cd app && flutter test test/stock_rateio_test.dart` -- expected: All tests passed! (Resultado: 9/9 passaram)
- `cd app && flutter test` -- expected: All tests passed! (Resultado: 157/157 passaram)
- `cd app && flutter analyze` -- expected: No issues found! (Resultado: 0 errors, 0 warnings)
- `cd functions && npm test` -- expected: All tests passed! (Resultado: 8/8 suites passaram)

