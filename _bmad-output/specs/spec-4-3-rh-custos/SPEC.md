---
id: SPEC-4-3-rh-custos
companions:
  - ../implementation-artifacts/spec-4-3-rh-custos.md
sources:
  - ../implementation-artifacts/epic-4-context.md
  - ../implementation-artifacts/spec-4-1-rh-cadastro.md
  - ../implementation-artifacts/spec-4-2-rh-chamada.md
---

> **Canonical contract.** This SPEC and the files in `companions:` are the complete, preservation-validated contract for what to build, test, and validate.

# Story 4.3 — RH: Custos de Mão de Obra e Apropriação

## Why

O SIGO registra presenças nominais e rateio percentual de lotes nas chamadas diárias de campo (Story 4.2), porém esses apontamentos não são monetizados nem apropriados às despesas de mão de obra da obra e dos lotes. A ausência de snapshots imutáveis causaria distorção retroativa caso o salário base de um trabalhador fosse reajustado posteriormente no cadastro corporativo. Além disso, diferentes construtoras exigem políticas contábeis específicas (ex.: divisor de 30 dias corridos com DSR versus 22 dias úteis), demandando um motor determinístico de apropriação em centavos com conservação exata de valores.

## Capabilities

- **CAP-1**
  - **intent:** Calcular de forma determinística o custo diário efetivo de cada colaborador apontado na chamada diária com suporte a divisor mensal configurável por obra.
  - **success:** Colaboradores presentes recebem 100% da diária calculada em centavos inteiros (`baseSalaryCents + additionalCostsCents ~/ monthlyDivisor`), meio-período recebe 50% (`~/ 2`), e faltas recebem rigorosamente 0 centavos.

- **CAP-2**
  - **intent:** Apropriar o custo diário efetivo do colaborador nos lotes alocados com distribuição exata em centavos e compensação de resíduo de arredondamento.
  - **success:** A soma dos centavos atribuídos a cada lote é rigorosamente idêntica ao custo efetivo do trabalhador (`sum(costCents) == effectiveCostCents`), sem criação ou perda de centavos.

- **CAP-3**
  - **intent:** Registrar snapshots imutáveis dos custos aplicados e da política da obra no ato de confirmação do fechamento diário da chamada.
  - **success:** Chamadas salvas no Firestore preservam os valores salariais históricos e o divisor aplicado no documento; alterações cadastrais posteriores de funcionários não afetam chamadas passadas.

- **CAP-4**
  - **intent:** Exibir na interface móvel e web os custos consolidados do expediente e detalhamento financeiro por lote.
  - **success:** A interface exibe o custo total do dia, prévia em tempo real nos cards dos operários, valores calculados em reais no rateio de lotes e resumo consolidado por lote.

## Constraints

- Todos os valores financeiros são armazenados estritamente como números inteiros (`int`) em centavos de Real (`effectiveCostCents`, `lotCostCents`, `totalDayCostCents`).
- Proibida exclusão física no Firestore (`allow delete: if false;`).
- Trabalhadores ausentes (`falta`) têm 0% de apropriação e custo estritamente zero.
- Os snapshots gravados em chamadas confirmadas são imutáveis; retificações geram nova versão com auditoria (`status: 'retificada'`).

## Non-goals

- Emissão de folha de pagamento corporativa completa, holerites ou guias de recolhimento de tributos (FGTS/INSS) nesta história.
- Fechamento contábil mensal consolidado (escopo futuro do módulo de custos/visão 360).

## Success signal

- A execução do fechamento diário de chamada gera e persiste os snapshots de custos com soma exata de centavos por lote, 100% dos testes unitários e de integração aprovados, e análise estática do Flutter sem nenhum aviso.
