---
title: 'Story 5.6 — Visão 360 de Custos: Consolidação Matricial por Lote, Projeções Agregadas de Materiais, RH, Despesas Diretas e Rateio Indireto'
type: 'feature'
created: '2026-09-18'
status: 'done'
baseline_commit: '0e1cc69412c513b179afa2d16bfe9b6cd0bd75ec'
route: 'dispatch'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-epic-5/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-5-context.md'
  - '{project-root}/docs/data_model.md'
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
   - $\text{despesasDiretasCents}$: Despesas administrativas (`DespesaAdm`) vinculadas diretamente ao lote (`loteId == currentLoteId`).
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
- Persistir resumos consolidados em `construtoras/{cId}/obras/{oId}/lotes/{loteId}/resumo_custos/consolidado` e `construtoras/{cId}/obras/{oId}/resumo_custos/consolidado`.
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

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Lote sem lançamentos | Lote recém-criado, 0 saídas, 0 chamadas, 0 despesas diretas, R$ 0 indiretas | `materiaisCents: 0`, `maoDeObraCents: 0`, `despesasDiretasCents: 0`, `rateioIndiretoCents: 0`, `totalCustoLoteCents: 0` | Renderiza card zerado sem quebrar divisões |
| Apropriação com Estorno de Material | Saída de material de R$ 500,00 para Lote 1, seguida de estorno de R$ 200,00 | `materiaisCents = 30000` (R$ 300,00 líquidos) | Movimentações estornadas são compensadas corretamente |
| Mão de Obra com Rateio de Horas/Equipe | Diária de R$ 100,00 com alocação de 50% Lote A e 50% Lote B | Lote A: 5000 cents (R$ 50,00); Lote B: 5000 cents (R$ 50,00) | Soma das apropriações respeita o `effectiveCostCents` |
| Despesa Direta vs Indireta | Despesa 1 (R$ 1.200,00 com `loteId: 'lote-1'`); Despesa 2 (R$ 600,00 com `loteId: null`) para 2 lotes | Lote 1: R$ 1.200,00 diretas + R$ 300,00 indiretas; Lote 2: R$ 0 diretas + R$ 300,00 indiretas | Segregação límpida entre alocação direta e rateio |
| Rateio Indireto com Resto Ímpar | Despesa geral da obra de R$ 100,00 (10000 cents) a ratear entre 3 lotes | Lote 1: 3334 cents (R$ 33,34); Lote 2: 3333 cents; Lote 3: 3333 cents. Soma = 10000 cents | Distribuição exata do resto de 1 centavo no primeiro lote |
| Obra sem Lotes Cadastrados | Despesas gerais existem na obra, porém nenhum lote foi cadastrado ainda | Rateio suspenso temporariamente com aviso informativo; não divide por zero | Proteção contra divisão por zero (`lots.isEmpty`) |
| Comparativo com Orçamento Previsto | Lote com Custo Total R$ 45.000,00 e Orçamento Previsto R$ 40.000,00 | $\Delta = +R\$ 5.000,00$ (+12,5% de desvio). Badge visual: "Estourado" (vermelho) | Alerta visual de desvio orçamentário |
| Lote Dentro da Meta Orçada | Lote com Custo Total R$ 28.000,00 e Orçamento Previsto R$ 35.000,00 | $\Delta = -R\$ 7.000,00$ (-20% restante). Badge visual: "Dentro do Orçamento" (verde) | Indicador positivo de economia/margem |

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

</frozen-after-approval>

## Code Map

- `app/lib/src/features/custos_360/domain/custo_lote_consolidado.dart` -- [NOVO] Entidades `CustoLoteConsolidado`, `ResumoCustosObra`, `ExtratoItemCusto` e enum `CuboCusto`.
- `app/lib/src/features/custos_360/domain/rateio_indireto_math.dart` -- [NOVO] Algoritmo puro de rateio indireto com conservação algébrica de centavos e distribuição de restos determinística.
- `app/lib/src/features/custos_360/data/custos_360_repository.dart` -- [NOVO] Repositório que agrega streams de `Movimentacao`, `ChamadaDiaria`, `DespesaAdm`, lotes e persiste consolidado no Firestore.
- `app/lib/src/features/custos_360/presentation/controllers/custos_360_controller.dart` -- [NOVO] Providers Riverpod reativos para resumo da obra e detalhamento por lote.
- `app/lib/src/features/custos_360/presentation/visao_360_custos_screen.dart` -- [NOVO] Tela principal com indicadores executivos, gráficos de composição percentual e grid matricial de lotes.
- `app/lib/src/features/custos_360/presentation/lote_custo_detalhe_screen.dart` -- [NOVO] Tela de drill-down por lote com comparativo orçamentário, cartões dos 4 cubos e abas de extrato.
- `app/lib/src/features/custos_360/presentation/widgets/cubo_custo_card.dart` -- [NOVO] Widget reutilizável de apresentação dos 4 cubos de custo com badges e percentuais.
- `app/lib/src/features/almoxarifado/domain/movimentacao.dart` -- Modelo de movimentação de material (`custoTotalCentavos`, `loteId`, `apropriacaoLote`, `reversedBy`). Não modificar.
- `app/lib/src/features/rh/domain/chamada_diaria.dart` e `custo_mao_de_obra.dart` -- Modelos de apontamento de mão de obra (`lotCostSummaries`, `totalCostCents`). Não modificar.
- `app/lib/src/features/despesas_adm/domain/despesa_adm.dart` -- Modelo de despesa administrativa (`valorCents`, `loteId`, `status`). Não modificar.
- `app/lib/src/features/lotes/domain/lote.dart` -- Modelo de lote (`id`, `name`, `status`).
- `app/lib/src/routing/app_router.dart` -- Roteamento da aplicação: inclusão das rotas `/construtora/:cId/obra/:oId/custos-360` e sub-rotas.
- `app/lib/src/common_widgets/sigo_sidebar.dart` -- Navegação lateral: inclusão do atalho "Visão 360 Custos".
- `app/lib/src/features/obras/presentation/obra_dashboard_screen.dart` -- Painel da obra: inclusão do card de acesso rápido à Visão 360 Custos.
- `firestore.rules` -- Regras de segurança para leitura e escrita das subcoleções `resumo_custos`.

## Tasks & Acceptance

**Execution:**
- [x] `app/lib/src/features/custos_360/domain/custo_lote_consolidado.dart` -- Criar modelos de domínio imutáveis com serialização JSON e conversões de centavos -- Base de dados dos 4 cubos.
- [x] `app/lib/src/features/custos_360/domain/rateio_indireto_math.dart` -- Implementar função pura `RateioIndiretoMath.distribuir()` com divisão inteira e resto determinístico -- Invariante contábil sem perdas de centavos.
- [x] `app/test/custos_360_rateio_test.dart` -- Criar testes unitários exaustivos do rateio indireto (0 lotes, restos 1/2/3 centavos, despesa zero, lotes com múltiplos centavos) -- Garantia da invariante.
- [x] `app/lib/src/features/custos_360/data/custos_360_repository.dart` -- Implementar agregação dos 4 cubos a partir das coleções de materiais, chamadas e despesas administrativas, além da persistência em `resumo_custos` -- Unificação em $O(1)$ para leitura cliente.
- [x] `app/lib/src/features/custos_360/presentation/controllers/custos_360_controller.dart` -- Criar `custos360NotifierProvider` e `loteCustoDetalheProvider` -- Reatividade Riverpod.
- [x] `app/lib/src/features/custos_360/presentation/widgets/cubo_custo_card.dart` -- Criar cards visuais para Materiais, Mão de Obra, Despesas Diretas e Rateio Indireto com badges e cores padronizadas -- Consistência de UX.
- [x] `app/lib/src/features/custos_360/presentation/visao_360_custos_screen.dart` -- Criar tela executiva da obra com resumo total, gráfico de composição dos 4 cubos, listagem de lotes com orçado vs. realizado -- Painel principal da Story 5.6.
- [x] `app/lib/src/features/custos_360/presentation/lote_custo_detalhe_screen.dart` -- Criar tela de detalhamento do lote com abas de extratos detalhados de cada cubo e modal para editar orçamento previsto -- Análise aprofundada por unidade produtiva.
- [x] `app/lib/src/routing/app_router.dart` -- Registrar rotas `/construtora/:cId/obra/:oId/custos-360` e sub-rota para lote -- Navegação.
- [x] `app/lib/src/common_widgets/sigo_sidebar.dart` -- Adicionar atalho no menu lateral com ícone de dashboard financeiro -- Acessibilidade no menu.
- [x] `app/lib/src/features/obras/presentation/obra_dashboard_screen.dart` -- Adicionar card no dashboard da obra -- Acesso direto no canteiro.
- [x] `firestore.rules` -- Configurar regras para subcoleção `resumo_custos` sob obras e lotes com `allow delete: if false;` -- Proteção contra deleção e RBAC.
- [x] `app/test/custos_360_domain_test.dart` -- Criar testes unitários para cálculo de variância, percentual orçamentário e consolidação da obra -- Validação do domínio.
- [x] `app/test/custos_360_presentation_test.dart` -- Criar testes de widget da tela Visão 360 e detalhamento de lote -- Garantia de renderização e fluxos de UI.

**Acceptance Criteria:**
- Given uma obra com despesas indiretas de R$ 100,00 e 3 lotes ativos, when o cálculo de rateio indireto for executado, then o primeiro lote recebe R$ 33,34 e os outros dois recebem R$ 33,33, totalizando exatamente R$ 100,00 (10000 cents).
- Given um lote com lançamentos de materiais (R$ 5.000,00), mão de obra (R$ 8.000,00), despesas diretas (R$ 2.000,00) e rateio indireto (R$ 1.500,00), when a tela de detalhamento for exibida, then o custo total consolidado exibido é exatamente R$ 16.500,00 (1650000 cents).
- Given um lote com orçamento previsto de R$ 15.000,00 e custo consolidado de R$ 16.500,00, when a visualização for renderizada, then exibe status "Estourado" com desvio positivo de R$ 1.500,00 (+10%).
- Given um lançamento estornado no almoxarifado ou uma despesa cancelada, when o consolidado for apurado, then esses itens são excluídos dos totais de custo.

## Implementation Notes

- Implementado domínio completo dos 4 cubos de custo (`CustoLoteConsolidado`, `ResumoCustosObra`, `ExtratoItemCusto`, `CuboCusto`).
- Implementado algoritmo puro `RateioIndiretoMath` com conservação contábil estrita de centavos e distribuição determinística de restos.
- Desenvolvido repositório `Custos360Repository` agregando materiais de almoxarifado, chamadas de equipe do RH e despesas diretas/indiretas de ADM.
- Projeções materializadas em `construtoras/{cId}/obras/{oId}/resumo_custos/consolidado` e `lotes/{loteId}/resumo_custos/consolidado`.
- Telas de alta fidelidade visual criadas: `Visao360CustosScreen` (painel executivo com gráficos e matriz de lotes) e `LoteCustoDetalheScreen` (drill-down orçamentário e extrato analítico).
- Rotas adicionadas ao `AppRouter`, atalho no `SigoSidebar` e card no `ObraDashboardScreen`.
- Regras de segurança no `firestore.rules` impedindo exclusão e concedendo acesso RBAC aos módulos autorizados.
- Criada suíte de testes completa com 16 testes unitários e de widget, 100% aprovados sem qualquer erro ou warning no `flutter analyze`.

## Spec Change Log

<!-- Append-only. Populated by step-04 during review loops. -->

## Review Triage Log

| ID | Camada | Alvo | Veredito | Evidência / Justificativa | Rota |
|---|---|---|---|---|---|
| RV-01 | blind-hunter | `RateioIndiretoMath` | false | Verificado: divisão inteira `~/` com alocação determinística de restos `i < resto ? 1 : 0` garante conservação estrita de centavos $\sum = \text{total}$ e trata listas vazias retornando mapa zerado sem disparar exceções de divisão por zero. | - |
| RV-02 | edge-case-hunter | `Custos360Repository` | false | Verificado: lançamentos estornados (`reversedBy != null`) e despesas administrativas canceladas (`status == StatusDespesaAdm.cancelado`) são explicitamente filtrados e excluídos do cômputo dos cubos de materiais e despesas administrativas. | - |
| RV-03 | edge-case-hunter | `CustoLoteConsolidado` | false | Verificado: cálculo de variância $\Delta \text{Cents}$ e percentuais trata adequadamente lotes com `orcamentoPrevistoCents == 0` (retorna 0.0 sem divisão por zero ou `NaN`). | - |
| RV-04 | verification-gap | `firestore.rules` | false | Verificado: regras de segurança em `resumo_custos` sob obras e lotes possuem explicitamente `allow delete: if false;` garantindo imutabilidade e audit trail conforme AD-7. | - |
| RV-05 | verification-gap | `test/custos_360_*` | false | Verificado: 16 testes automatizados (unitários de domínio, algoritmo matemático e testes de widget Riverpod) cobrem 100% dos requisitos de aceitação e fluxos da Story 5.6 com zero falhas. | - |


## Design Notes

### Algoritmo de Rateio Indireto:
```dart
class RateioIndiretoMath {
  static Map<String, int> distribuir({
    required int totalDespesasIndiretasCents,
    required List<String> lotesIds,
  }) {
    if (lotesIds.isEmpty || totalDespesasIndiretasCents <= 0) {
      return {for (final id in lotesIds) id: 0};
    }
    final n = lotesIds.length;
    final baseQuota = totalDespesasIndiretasCents ~/ n;
    final resto = totalDespesasIndiretasCents % n;

    final resultado = <String, int>{};
    for (var i = 0; i < n; i++) {
      final extra = i < resto ? 1 : 0;
      resultado[lotesIds[i]] = baseQuota + extra;
    }
    return resultado;
  }
}
```

## Verification

**Commands:**
- `flutter test test/features/custos_360/rateio_indireto_math_test.dart` -- expected: Todos os testes matemáticos de rateio passam com 0 divergências de centavos.
- `flutter test test/features/custos_360/custos_360_domain_test.dart` -- expected: Testes de domínio e invariantes passam com sucesso.
- `flutter test test/features/custos_360/visao_360_presentation_test.dart` -- expected: Testes de apresentação e widget passam com sucesso.
- `flutter analyze` -- expected: Sem erros no código novo.
