---
id: SPEC-5-6-visao-360-custos
companions:
  - ../implementation-artifacts/spec-5-6-visao-360-custos.md
sources:
  - ../planning-artifacts/architecture/architecture-epic-5/ARCHITECTURE-SPINE.md
  - ../implementation-artifacts/epic-5-context.md
  - ../../docs/data_model.md
---

> **Canonical contract.** This SPEC and the files in `companions:` are the complete, preservation-validated contract for what to build, test, and validate.

# Story 5.6 — Visão 360º de Custos (Consolidação Matricial por Lote, Projeções Agregadas de Materiais, RH, Despesas Diretas e Rateio Indireto)

## Why

Na gestão de obras civis e incorporação imobiliária, a apuração do custo real por unidade construtiva (Lote/Torre/Unidade) é o pilar decisivo para o controle de rentabilidade, medições de avanço e tomada de decisão executiva. Historicamente, os dados financeiros da obra residiam fragmentados em silos operacionais distintos:
1. **Silos Operacionais Desconectados:** As saídas físicas de materiais no Almoxarifado (Epic 3), as chamadas diárias e apontamento de mão de obra de colaboradores do RH (Epic 4) e os lançamentos de notas fiscais, contas a pagar e contratos administrativos (Epic 5) eram gerenciados em telas e coleções isoladas, sem uma visão financeira consolidada por lote.
2. **Inviabilidade de Consultas $O(N)$ em Tempo Real no Cliente:** Calcular o custo total de uma obra com centenas de lotes a partir da varredura bruta de milhares de requisições de estoque, centenas de folhas de ponto e dezenas de despesas diretamente no aplicativo móvel/web degradava a performance, estourava cotas de leitura do Firestore e inviabilizava o uso em campo offline.
3. **Ausência de Metodologia Algébrica de Rateio Indireto:** Custos comuns da obra (energia elétrica, água, locação de guindastes/geradores, despesas de canteiro) não eram rateados entre os lotes de forma sistemática ou geravam furos de centavos, distorcendo o custo real apurado de cada unidade e impossibilitando o comparativo fidedigno entre Orçado vs. Realizado.

## Capabilities

- **CAP-1**
  - **intent:** Consolidar e agregar o cubo de Materiais alocados a cada Lote a partir do histórico de movimentações do Almoxarifado.
  - **success:** O sistema calcula `materiaisCents` para cada lote somando todas as movimentações do tipo saída (`MovimentacaoType.saida`) com `loteId == currentLoteId` e `apropriacaoLote == true`, deduzindo automaticamente estornos e ajustes homologados, armazenando o valor estritamente como inteiro em centavos.

- **CAP-2**
  - **intent:** Consolidar e agregar o cubo de Mão de Obra alocada a cada Lote a partir das chamadas diárias de RH confirmadas.
  - **success:** O sistema calcula `maoDeObraCents` para cada lote agregando os registros `lotCostSummaries` de todas as chamadas diárias com status `fechada` ou `retificada` para a obra ativa, refletindo fielmente as diárias proporcionais de cada trabalhador por lote com precisão de centavos sem perdas de arredondamento.

- **CAP-3**
  - **intent:** Consolidar e agregar o cubo de Despesas Diretas alocadas a cada Lote a partir dos títulos financeiros e medições vinculadas.
  - **success:** O sistema calcula `despesasDiretasCents` para cada lote somando todas as despesas administrativas (`DespesaAdm`) e compras/medições com `loteId == currentLoteId`, desconsiderando registros cancelados e discriminando o total pago vs. o passivo pendente de liquidação.

- **CAP-4**
  - **intent:** Executar o rateio proporcional determinístico de Despesas Indiretas da Obra entre os lotes ativos preservando a conservação total de centavos.
  - **success:** O algoritmo de rateio identifica despesas comuns da obra (`loteId == null`) e as distribui entre os lotes ativos de acordo com a cota-parte configurada (rateio igualitário por lote ou ponderado), alocando eventuais restos da divisão inteira no primeiro lote para garantir a invariante matemática estrita: $\sum_{j=1}^{M} \text{lote}[j].\text{rateioIndiretoCents} \equiv \text{totalDespesasGeraisCents}$.

- **CAP-5**
  - **intent:** Disponibilizar o Painel Executivo da Visão 360º de Custos da Obra com indicadores consolidados e matriz comparativa.
  - **success:** A tela apresenta os KPIs gerais da obra (Custo Total Realizado, Total Materiais, Total Mão de Obra, Total Despesas Diretas, Total Rateio Indireto), gráfico/distribuição percentual entre os 4 cubos e lista de Lotes com indicadores visuais de participação no custo global e desvio em relação ao orçamento previsto (`orcamentoPrevistoCents`).

- **CAP-6**
  - **intent:** Fornecer detalhamento analítico (drill-down) por Lote com extrato discriminado dos 4 cubos e comparativo Orçado vs. Realizado.
  - **success:** Ao selecionar um lote, o usuário visualiza o card consolidado do lote ($\text{totalCustoLoteCents} \equiv \text{materiaisCents} + \text{maoDeObraCents} + \text{despesasDiretasCents} + \text{rateioIndiretoCents}$), status do orçamento (Dentro da Meta vs. Estouro com $\Delta \text{Cents}$), e abas navegáveis contendo o extrato nominal detalhado de cada lançamento que compõe os custos.

## Constraints

- **Topologia Firestore Padronizada:** A Visão 360 adota projeções agregadas materializadas por Lote em `construtoras/{cId}/obras/{oId}/lotes/{loteId}/resumo_custos/consolidado` e visão agregada da obra em memória/StreamProvider (AD-6).
- **Rigor Monetário em Centavos:** Todos os valores financeiros são obrigatoriamente inteiros (`int amountCents`). Fatores de arredondamento em float ou double são proibidos no domínio contábil.
- **Invariante Algébrica de Rateio Indireto:** A soma das parcelas de rateio indireto de todos os lotes deve ser rigorosamente igual ao montante total de despesas indiretas gerais da obra ($\text{discrepanciaCents} \equiv 0$).
- **Imutabilidade e Governança:** Proibição de exclusão física no Firestore (`allow delete: if false;`) em conformidade com AD-7.
- **RBAC Multiobra:** Acesso concedido a membros da obra com permissão nos módulos `adm`, `financeiro`, `rh`, `almoxarifado`, além de administradores (`admin(c)`, `obraAdmin(c,o)`) e `dev_roles`.
- **Compatibilidade Offline / PWA:** Leitura suportada em ambiente desconectado via cache local IndexedDB e estado reativo do Riverpod.

## Non-goals

- Integração bancária direta para débito em conta de tributos imobiliários ou recolhimento automático de encargos (GPS / FGTS).
- Geração automatizada de folha de pagamento contábil oficial ou emissão de holerites para envio ao eSocial.
- Planejamento de fluxo de caixa futuro por curva S projetada com projeção de receitas de vendas de unidades.

## Success signal

- Painel da Visão 360º de Custos da Obra e tela de Detalhes do Lote em pleno funcionamento, integrando harmonicamente os 4 cubos financeiros (Materiais do Estoque, Mão de Obra de RH, Despesas Diretas ADM e Rateio Indireto), com validação algébrica de conservação de centavos, comparativo Orçado vs. Realizado, navegação fluida em abas de extrato, regras de segurança do Firestore atualizadas, 100% dos testes unitários e de widget passando e zero warnings no `flutter analyze`.
