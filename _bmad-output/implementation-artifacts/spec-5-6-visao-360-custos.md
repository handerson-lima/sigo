---
title: 'Story 5.6 — Visão 360 de Custos: Consolidação Matricial por Lote, Projeções Agregadas de Materiais, RH, Despesas Diretas e Rateio Indireto'
type: 'feature'
created: '2026-09-18'
status: 'draft'
baseline_commit: '9b179d78027805e09ba2da04d10af466fa8a4fbf'
route: 'dispatch'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/specs/spec-5-6-visao-360-custos/SPEC.md'
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-epic-5/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-5-context.md'
  - '{project-root}/docs/data_model.md'
  - '{project-root}/docs/task.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:**
Na gestão de engenharia e construção civil do SIGO, o controle de custos por unidade autônoma (Lote/Torre/Fase) sofria de três barreiras fundamentais:
1. **Fragmentação em Silos Operacionais:** Os custos de materiais apropriados na obra (Epic 3), os custos de mão de obra direta de equipes apurados em chamadas diárias (Epic 4) e as despesas financeiras/contratuais gerais (Epic 5) residiam em bancos e fluxos totalmente separados, sem um ponto central de agregação por unidade produtiva.
2. **Inviabilidade de Consultas $O(N)$ em Tempo Real no Cliente:** O cálculo dinâmico de custos varrendo milhares de requisições de almoxarifado e dezenas de folhas de chamada sob demanda na tela causava latência intolerável, alto consumo de leituras no Firestore e inviabilidade de análise no canteiro offline.
3. **Ausência de Rateio Indireto de Custos Comuns:** As despesas globais da obra (ex.: energia elétrica provisória, aluguel de gerador, vigilância, caçambas) não eram rateadas matematicamente entre os lotes, distorcendo o custo real apurado de cada lote e gerando furos contábeis de centavos.

**Approach:**
Implementar o **Módulo de Visão 360º de Custos**, estruturado como:
1. **Domínio Matemático e Algébrico dos 4 Cubos de Custo por Lote:**
   - $\text{materiaisCents}$: Saídas de materiais com `loteId == currentLoteId` e `apropriacaoLote == true`, deduzindo estornos.
   - $\text{maoDeObraCents}$: Somatório de custos dos apontamentos de trabalhadores alocados ao lote nas chamadas diárias de RH confirmadas.
   - $\text{despesasDiretasCents}$: Despesas administrativas (`DespesaAdm`) e compras vinculadas diretamente ao lote (`loteId == currentLoteId`).
   - $\text{rateioIndiretoCents}$: Cota-parte matemática das despesas gerais da obra (`loteId == null`) distribuída entre os lotes ativos.
   - $\text{totalCustoLoteCents} \equiv \text{materiaisCents} + \text{maoDeObraCents} + \text{despesasDiretasCents} + \text{rateioIndiretoCents}$.
2. **Invariante Algébrica de Rateio Indireto (`RateioIndiretoMath`):**
   - Distribuição do total de despesas gerais entre $M$ lotes com alocação determinística do resto da divisão inteira no primeiro lote:
     $$\sum_{j=1}^{M} \text{lote}[j].\text{rateioIndiretoCents} \equiv \text{totalDespesasGeraisCents}$$
3. **Projeções Materializadas e Stream Providers Reativos:**
   - Projeções salvas no Firestore em `construtoras/{cId}/obras/{oId}/lotes/{loteId}/resumo_custos/consolidado` com leitura imediata e cálculo consolidado em tempo real no app para feedback reativo instantâneo.
4. **Painel Executivo da Obra & Drill-down por Lote:**
   - **Visão da Obra:** Indicadores globais (Custo Total, Materiais, RH, Despesas Diretas, Rateio Indireto), gráfico de pizza/barra da composição percentual e grid/tabela de Lotes com participação percentual no custo da obra.
   - **Drill-down do Lote:** Comparativo Orçado vs. Realizado ($\Delta \text{Cents} = \text{totalRealizadoCents} - \text{orcamentoPrevistoCents}$) com badges visuais ("Dentro do Orçamento", "Alerta", "Estourado") e abas para conferência do extrato nominal de cada lançamento dos 4 cubos.
5. **Governança, Imutabilidade e Auditoria (AD-7):**
   - Proteção de regras no Firestore contra exclusão (`allow delete: if false;`), audit trail e controle de acesso RBAC baseado em papéis e módulos permitidos.

---

## Boundaries & Constraints

**Always:**
- Armazenar e totalizar todos os valores financeiros estritamente como inteiros em centavos (`int amountCents`). O uso de ponto flutuante para dinheiro é proibido.
- Garantir a conservação algébrica total do rateio indireto: a soma dos rateios distribuídos para todos os lotes deve ser exatamente igual ao montante de despesas indiretas rateadas.
- Persistir resumos consolidados em `construtoras/{cId}/obras/{oId}/lotes/{loteId}/resumo_custos/consolidado`.
- Ignorar movimentações estornadas (`reversedBy != null`) e despesas administrativas canceladas (`status == StatusDespesaAdm.cancelado`) na composição dos custos.
- Permitir a configuração ou atualização de `orcamentoPrevistoCents` no lote para cálculo imediato de variância orçamentária.
- Manter permissão de leitura para membros com perfis administrativos ou autorizados nos módulos `adm`, `financeiro`, `rh` ou `almoxarifado`.
- Proibir a deleção física de projeções ou resumos no Firestore (`allow delete: if false;`).

**Never:**
- Nunca permitir divergência de 1 centavo sequer entre a soma dos 4 cubos e o total de custo do lote.
- Nunca calcular rateio indireto gerando centavos fracionários; utilizar sempre divisão inteira e distribuição do resto.
- Nunca permitir que um lote inativo ou cancelado receba nova cota de rateio a menos que configurado explicitamente.
- Nunca expor operações de hard delete para projeções consolidadas de custo.

---

## I/O & Edge-Case Matrix

| Cenário | Entrada / Estado | Saída Esperada | Tratamento de Erro / Invariante |
|---|---|---|---|
| **Lote sem lançamentos** | Lote recém-criado, 0 saídas, 0 chamadas, 0 despesas diretas, R$ 0 de indiretas | `materiaisCents: 0`, `maoDeObraCents: 0`, `despesasDiretasCents: 0`, `rateioIndiretoCents: 0`, `totalCustoLoteCents: 0` | Renderiza card zerado sem quebrar divisões |
| **Apropriação com Estorno de Material** | Saída de material de R$ 500,00 para Lote 1, seguida de estorno de R$ 200,00 | `materiaisCents = 30000` (R$ 300,00 líquidos) | Movimentações estornadas são compensadas corretamente |
| **Mão de Obra com Rateio Percentual** | Colaborador (diária R$ 100,00) alocado 50% no Lote A e 50% no Lote B | Lote A: 5000 cents (R$ 50,00); Lote B: 5000 cents (R$ 50,00) | Soma das apropriações respeita o `effectiveCostCents` |
| **Despesa Direta vs Indireta** | Despesa 1 (R$ 1.200,00 com `loteId: 'lote-1'`); Despesa 2 (R$ 600,00 com `loteId: null`) para 2 lotes | Lote 1 recebe R$ 1.200,00 em despesas diretas + R$ 300,00 de rateio indireto; Lote 2 recebe R$ 0 diretas + R$ 300,00 indiretas | Segregação límpida entre alocação direta e rateio |
| **Rateio Indireto com Resto Ímpar** | Despesa geral da obra de R$ 100,00 (10000 cents) a ratear entre 3 lotes | Lote 1: 3334 cents (R$ 33,34); Lote 2: 3333 cents (R$ 33,33); Lote 3: 3333 cents (R$ 33,33). Soma = 10000 cents | Distribuição exata do resto de 1 centavo no primeiro lote |
| **Obra sem Lotes Cadastrados** | Despesas gerais existem na obra, porém nenhum lote foi criado ainda | Rateio suspenso temporariamente com aviso informativo; não divide por zero | Proteção contra divisão por zero (`lots.isEmpty`) |
| **Comparativo com Orçamento Previsto** | Lote com Custo Total R$ 45.000,00 e Orçamento Previsto R$ 40.000,00 | $\Delta = +R\$ 5.000,00$ (+12,5% de desvio). Badge visual: "Estourado" (vermelho) | Alerta visual de desvio orçamentário |
| **Lote Dentro da Meta Orçada** | Lote com Custo Total R$ 28.000,00 e Orçamento Previsto R$ 35.000,00 | $\Delta = -R\$ 7.000,00$ (-20% restante). Badge visual: "Dentro do Orçamento" (verde) | Indicador positivo de economia/margem |
| **Exportação ou Impressão de Relatório** | Usuário solicita visualização resumida para prestação de contas | Visualização estruturada com cabeçalho da obra, data de fechamento e tabela matricial dos lotes | Componente pronto para impressão / auditoria |

---

## Data Models & Firestore Topology

### Topologia Firestore:
```
construtoras/{cId}/obras/{oId}/lotes/{loteId}/resumo_custos/consolidado
construtoras/{cId}/obras/{oId}/resumo_custos/consolidado
```

### Entidade: `CustoLoteConsolidado`
```dart
class CustoLoteConsolidado {
  final String loteId;
  final String loteNome;
  final int materiaisCents;
  final int maoDeObraCents;
  final int despesasDiretasCents;
  final int rateioIndiretoCents;
  final int totalCustoLoteCents;
  final int orcamentoPrevistoCents;
  final int varianciaCents; // totalCustoLoteCents - orcamentoPrevistoCents
  final double percentualConsumido; // total / orcamento (se orcamento > 0)
  final DateTime ultimaAtualizacao;
}
```

### Entidade: `ResumoCustosObra`
```dart
class ResumoCustosObra {
  final String obraId;
  final int totalGeralCents;
  final int totalMateriaisCents;
  final int totalMaoDeObraCents;
  final int totalDespesasDiretasCents;
  final int totalDespesasIndiretasCents;
  final int orcamentoTotalPrevistoCents;
  final List<CustoLoteConsolidado> lotesCustos;
  final DateTime apuradoEm;
}
```

### Entidade: `ExtratoItemCusto`
```dart
enum CuboCusto { material, maoDeObra, despesaDireta, rateioIndireto }

class ExtratoItemCusto {
  final String id;
  final CuboCusto cubo;
  final String descricao;
  final DateTime data;
  final int valorCents;
  final String? documentoReferencia;
  final String? responsavelNome;
}
```

---

## Implementation Tasks

1. **Domínio e Algoritmo (`features/custos_360/domain`):**
   - Criar entidades puras `CustoLoteConsolidado`, `ResumoCustosObra`, `ExtratoItemCusto`.
   - Implementar `RateioIndiretoMath.distribuir()` garantindo a conservação algébrica de centavos e distribuição de restos determinística.
2. **Camada de Serviço e Repositório (`features/custos_360/data`):**
   - Implementar `Custos360Repository` agregando streams/queries de `Movimentacao` (Almoxarifado), `ChamadaDiaria` (RH) e `DespesaAdm` (ADM) por lote e gerais da obra.
   - Implementar persistência de snapshot materializado em `resumo_custos/consolidado`.
3. **Controladores e Providers (`features/custos_360/presentation`):**
   - Criar `custos360NotifierProvider` para a obra ativa, com cálculo instantâneo e caching.
   - Provider para detalhe e extrato de um lote específico (`custoLoteDetalheProvider(loteId)`).
4. **Telas e Componentes de Apresentação:**
   - `Visao360CustosScreen`: Painel executivo da obra com cards de KPI, gráficos de distribuição dos 4 cubos e lista de lotes com barras de progresso orçamentário.
   - `LoteCustoDetalheScreen`: Tela de drill-down por lote com cartões dos 4 cubos, alerta orçamentário, diálogo para ajuste de orçamento previsto e abas para cada cubo com seu extrato detalhado.
5. **Integração de Navegação e Menus:**
   - Adicionar rotas no `AppRouter`: `/obras/:obraId/custos-360` e `/obras/:obraId/custos-360/lotes/:loteId`.
   - Adicionar atalho no menu lateral (`SigoSidebar`) e no dashboard da obra (`ObraDashboardScreen`).
6. **Regras de Segurança (`firestore.rules`):**
   - Autorizar leitura e criação/atualização de `resumo_custos` para membros com módulos autorizados, bloqueando exclusão física (`allow delete: if false;`).
7. **Bateria de Testes:**
   - Testes unitários do algoritmo matemático `RateioIndiretoMath` (conservação de centavos, restos, zero divisões).
   - Testes de domínio para as entidades e agregadores.
   - Testes de widget e apresentação para as telas da Visão 360 e detalhamento do lote.

</frozen-after-approval>
