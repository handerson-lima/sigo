---
title: 'Story 4.3 — RH: Custos de Mão de Obra e Apropriação'
type: 'feature'
created: '2026-09-17'
status: 'in-progress'
baseline_commit: '297136a01b36e16915c89c2034921dac76c5c8dc'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-4-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-4-1-rh-cadastro.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-4-2-rh-chamada.md'
  - '{project-root}/docs/data_model.md'
  - '{project-root}/docs/user_flows.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O SIGO atualmente permite o apontamento nominal de colaboradores e a distribuição percentual de presença entre lotes na chamada diária (Story 4.2), porém esses apontamentos não são monetizados nem apropriados como despesas de mão de obra da obra e dos lotes. Além disso, se o salário base ou os encargos de um colaborador forem reajustados no cadastro corporativo (Story 4.1), a falta de snapshots imutáveis causaria recálculo retroativo indevido das despesas de chamadas passadas. Ademais, cada construtora ou obra pode adotar políticas contábeis distintas para apuração da diária (ex.: divisor padrão de 30 dias corridos com DSR versus divisor de 22 dias úteis), exigindo divisor e política versionados para garantir rastreabilidade jurídica e contábil.

**Approach:** Implementar o motor de **Cálculo de Custos e Apropriação de Mão de Obra** integrado ao ciclo de vida da Chamada Diária (`construtoras/{cId}/obras/{oId}/chamadas/{chId}`), com os seguintes pilares:
1. **Cálculo Determinístico da Taxa Diária Efetiva:**
   - `presente`: 100% da taxa diária do colaborador (`effectiveCostCents = baseDailyRateCents`).
   - `meio-periodo`: 50% da taxa diária (`effectiveCostCents = baseDailyRateCents ~/ 2`, com divisão inteira).
   - `falta`: R$ 0,00 (`effectiveCostCents = 0`).
2. **Divisor Configurável e Política Versionada:** Suportar política de custos versionada (`CostPolicy`, ex: versão `"v1"`), com divisor mensal configurável por obra (padrão 30 dias com DSR, podendo ser definido para 20, 22 ou 30 conforme diretriz da empresa).
3. **Apropriação Financeira Exata em Centavos por Lote:** Algoritmo determinístico de distribuição de centavos que rateia `effectiveCostCents` entre os lotes alocados (`AlocacaoLote.percentage`), compensando eventuais resíduos de arredondamento (`remainder`) no lote de maior alocação para garantir que a soma dos lotes seja estritamente igual ao custo efetivo do trabalhador (zero perda ou criação de centavos).
4. **Snapshots Imutáveis no Fechamento:** Persistir no documento da chamada o snapshot completo dos custos aplicados na data (`costPolicySnapshot`, `workerCostSnapshots`, `totalDayCostCents` e `lotCostSummaries`). Reajustes cadastrais posteriores no colaborador não afetam chamadas já fechadas.
5. **Transparência e Auditoria na Interface:** Exibição em tempo real do custo estimado do expediente durante o lançamento da chamada, detalhamento do valor apropriado em cada lote no formulário e no resumo da chamada, e badge com custo total na listagem histórica.

## Boundaries & Constraints

**Always:**
- Persistir todos os valores monetários estritamente como inteiros em centavos de Real (`int`), em consonância com a Story 3.7 e C3 (`effectiveCostCents`, `lotCostCents`, `totalDayCostCents`).
- Garantir a conservação matemática exata de centavos: para cada trabalhador, a soma dos `costCents` atribuídos a cada lote DEVE ser rigorosamente igual a `effectiveCostCents` (`sum(allocations.costCents) == effectiveCostCents`).
- Em caso de divisão não exata de centavos em rateios de múltiplos lotes, o resíduo (`remainder`) deve ser somado ao lote que detém a maior porcentagem alocada (ou ao primeiro, em caso de empate).
- Garantir que colaboradores ausentes (`PresencaStatus.falta`) tenham custo efetivo estritamente igual a 0 centavos (`costCents == 0`) e nenhuma alocação de custo em lotes.
- Gravar o snapshot da política contábil utilizada (`costPolicyVersion: 'v1'`, `monthlyDivisor`) e os dados salariais de referência no momento do salvamento da chamada.
- Garantir imutabilidade contábil: uma chamada salva no Firestore torna-se o registro oficial de custo daquele dia. Atualizações cadastrais futuras em `construtoras/{cId}/funcionarios/{fId}` não alteram chamadas já confirmadas.
- Caso uma chamada seja retificada pelo gestor, recalcular os snapshots com base nas presenças/lotes corrigidos, mantendo a marcação `status: 'retificada'` e data de atualização `updatedAt`.
- Exigir perfil de Administrador da Construtora (`admin(c)`), Administrador da Obra (`obraAdmin(c,o)`), Dev Global (`dev`) ou módulo `rh(c)` para criar, atualizar e consultar apropriações de custos.
- Bloquear exclusão física no Firestore (`allow delete: if false;`).

**Never:**
- Nunca utilizar ponto flutuante (`double`) para representar custos diários, encargos ou valores apropriados em lotes.
- Nunca permitir discrepância entre a soma dos custos de cada lote e o total consolidado da chamada (`sum(lotCostSummaries.totalCostCents) == totalDayCostCents`).
- Nunca gerar apropriação de custo maior que zero para trabalhadores com status `falta`.
- Nunca aplicar recálculo dinâmico retroativo que sobrescreva o snapshot gravado em chamadas fechadas.
- Nunca permitir que um usuário sem autorização no módulo `rh` ou privilégio administrativo visualize valores salariais ou totais de custos de mão de obra.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| **Colaborador Presente em Lote Único (100%)** | Colaborador CLT com diária base de R$ 120,00 (12.000 centavos). Marcado como `presente` com 100% no Lote 10. | `effectiveCostCents: 12000`. Apropriação Lote 10: `costCents: 12000` (R$ 120,00). Custo consolidado do colaborador: R$ 120,00. | N/A |
| **Colaborador em Meio-Período (50%)** | Diária base de R$ 150,00 (15.000 centavos). Marcado como `meio-periodo` com 50% no Lote 12. | `effectiveCostCents: 7500` (15000 ~/ 2 = R$ 75,00). Apropriação Lote 12: `costCents: 7500` (R$ 75,00). | N/A |
| **Colaborador com Falta (0%)** | Diária base de R$ 180,00. Marcado como `falta`. | `effectiveCostCents: 0`. Lotes: lista vazia. Custo apropriado: R$ 0,00. | Invariante validada preventivamente |
| **Rateio em Múltiplos Lotes com Centavos Exatos** | Diária R$ 100,00 (10.000 centavos). Presença em Lote A (40%) e Lote B (60%). | Lote A: 4.000 centavos (R$ 40,00); Lote B: 6.000 centavos (R$ 60,00). Soma = 10.000 centavos. | N/A |
| **Rateio em 3 Lotes com Resíduo (33% / 33% / 34%)** | Diária R$ 100,00 (10.000 centavos). Lote 1 (33%), Lote 2 (33%), Lote 3 (34%). | Lote 1: 3.300 centavos; Lote 2: 3.300 centavos; Lote 3: 3.400 centavos. Soma = 10.000 centavos exatos. | Algoritmo determinístico de centavos |
| **Rateio 50%/50% com Diária Ímpar em Centavos** | Diária R$ 125,01 (12.501 centavos). Rateio 50% Lote 1 e 50% Lote 2. | Divisão 12.501 * 50 ~/ 100 = 6.250 centavos cada. Resíduo de 1 centavo atribuído ao Lote 1. Lote 1: 6.251 centavos; Lote 2: 6.250 centavos. Soma = 12.501 centavos. | Resíduo compensado sem perda |
| **Reajuste Salarial Posterior no Cadastro** | Funcionário tem salário alterado de R$ 3.000 para R$ 4.500 no cadastro da construtora após 15 dias de chamada salva. | Ao abrir a chamada anterior de 15 dias atrás, os valores exibidos continuam sendo os do snapshot imutável (base R$ 3.000). | Proteção por snapshot estático |
| **Obra com Divisor Personalizado (22 dias úteis)** | Obra configurada com política `monthlyDivisor = 22`. Funcionário mensal de R$ 2.200 (220.000 centavos). | Diária calculada = 10.000 centavos (R$ 100,00/dia). Snapshot grava `monthlyDivisor: 22` e `dailyRateCents: 10000`. | Parâmetro respeitado no fechamento |
| **Visualização de Totais por Lote no Expediente** | Chamada com 4 trabalhadores presentes atuando nos Lotes 10 e 12, totalizando R$ 560,00. | Card de resumo exibe: Total Expediente: R$ 560,00. Lote 10: R$ 320,00 (2 operários). Lote 12: R$ 240,00 (2 operários). | Atualização reativa de interface |

</frozen-after-approval>

## Data Model & Schema

### 1. Entidade `CostPolicy`
Define os parâmetros de apuração contábil de mão de obra da obra:
```dart
class CostPolicy {
  final String version; // 'v1'
  final int monthlyDivisor; // Ex: 30 (padrão com DSR) ou 22 (dias úteis)
  final String description;

  const CostPolicy({
    this.version = 'v1',
    this.monthlyDivisor = 30,
    this.description = 'Divisor padrão mensal com DSR',
  });

  Map<String, dynamic> toMap() => {
    'version': version,
    'monthlyDivisor': monthlyDivisor,
    'description': description,
  };

  factory CostPolicy.fromMap(Map<String, dynamic> map) => CostPolicy(
    version: map['version'] as String? ?? 'v1',
    monthlyDivisor: (map['monthlyDivisor'] as num?)?.toInt() ?? 30,
    description: map['description'] as String? ?? '',
  );
}
```

### 2. Entidade `WorkerCostSnapshot`
Snapshot imutável dos custos do colaborador registrado no momento do fechamento da chamada:
```dart
class WorkerCostSnapshot {
  final String workerId;
  final String workerName;
  final String workerRole;
  final String salaryBasis; // 'mensal' | 'diaria'
  final int baseSalaryCents;
  final int additionalCostsCents;
  final int baseDailyRateCents; // Custo base da diária antes da presença
  final int effectiveCostCents; // Custo efetivo computado no dia (100%, 50% ou 0%)
  final String status; // 'presente', 'meio-periodo', 'falta'
  final List<LotCostAllocationSnapshot> lotAllocations;

  const WorkerCostSnapshot({
    required this.workerId,
    required this.workerName,
    required this.workerRole,
    required this.salaryBasis,
    required this.baseSalaryCents,
    required this.additionalCostsCents,
    required this.baseDailyRateCents,
    required this.effectiveCostCents,
    required this.status,
    this.lotAllocations = const [],
  });

  Map<String, dynamic> toMap() => {
    'workerId': workerId,
    'workerName': workerName,
    'workerRole': workerRole,
    'salaryBasis': salaryBasis,
    'baseSalaryCents': baseSalaryCents,
    'additionalCostsCents': additionalCostsCents,
    'baseDailyRateCents': baseDailyRateCents,
    'effectiveCostCents': effectiveCostCents,
    'status': status,
    'lotAllocations': lotAllocations.map((a) => a.toMap()).toList(),
  };

  factory WorkerCostSnapshot.fromMap(Map<String, dynamic> map) => WorkerCostSnapshot(
    workerId: map['workerId'] as String? ?? '',
    workerName: map['workerName'] as String? ?? '',
    workerRole: map['workerRole'] as String? ?? '',
    salaryBasis: map['salaryBasis'] as String? ?? 'mensal',
    baseSalaryCents: (map['baseSalaryCents'] as num?)?.toInt() ?? 0,
    additionalCostsCents: (map['additionalCostsCents'] as num?)?.toInt() ?? 0,
    baseDailyRateCents: (map['baseDailyRateCents'] as num?)?.toInt() ?? 0,
    effectiveCostCents: (map['effectiveCostCents'] as num?)?.toInt() ?? 0,
    status: map['status'] as String? ?? 'falta',
    lotAllocations: ((map['lotAllocations'] as List<dynamic>?) ?? [])
        .map((a) => LotCostAllocationSnapshot.fromMap(Map<String, dynamic>.from(a as Map)))
        .toList(),
  );
}
```

### 3. Entidade `LotCostAllocationSnapshot`
Rateio em centavos atribuído a um lote específico:
```dart
class LotCostAllocationSnapshot {
  final String lotId;
  final String lotName;
  final int percentage; // 0..100
  final int costCents; // Valor exato em centavos apropriado

  const LotCostAllocationSnapshot({
    required this.lotId,
    required this.lotName,
    required this.percentage,
    required this.costCents,
  });

  Map<String, dynamic> toMap() => {
    'lotId': lotId,
    'lotName': lotName,
    'percentage': percentage,
    'costCents': costCents,
  };

  factory LotCostAllocationSnapshot.fromMap(Map<String, dynamic> map) => LotCostAllocationSnapshot(
    lotId: map['lotId'] as String? ?? '',
    lotName: map['lotName'] as String? ?? '',
    percentage: (map['percentage'] as num?)?.toInt() ?? 0,
    costCents: (map['costCents'] as num?)?.toInt() ?? 0,
  );
}
```

### 4. Entidade `LotCostSummary`
Totalizador financeiro consolidado por lote na chamada:
```dart
class LotCostSummary {
  final String lotId;
  final String lotName;
  final int totalCostCents;
  final int workerCount;

  const LotCostSummary({
    required this.lotId,
    required this.lotName,
    required this.totalCostCents,
    required this.workerCount,
  });

  Map<String, dynamic> toMap() => {
    'lotId': lotId,
    'lotName': lotName,
    'totalCostCents': totalCostCents,
    'workerCount': workerCount,
  };

  factory LotCostSummary.fromMap(Map<String, dynamic> map) => LotCostSummary(
    lotId: map['lotId'] as String? ?? '',
    lotName: map['lotName'] as String? ?? '',
    totalCostCents: (map['totalCostCents'] as num?)?.toInt() ?? 0,
    workerCount: (map['workerCount'] as num?)?.toInt() ?? 0,
  );
}
```

### 5. Extensão de `ChamadaDiaria`
Adição dos campos de snapshot imutável ao cabeçalho da chamada:
```dart
class ChamadaDiaria {
  // ... campos existentes (id, construtoraId, obraId, date, teamId, workers, etc.)
  final int totalDayCostCents; // Soma de todos os custos efetivos do dia
  final String costPolicyVersion; // 'v1'
  final CostPolicy? costPolicy; // Snapshot da política aplicada
  final List<WorkerCostSnapshot> costSnapshots; // Snapshots nominais
  final List<LotCostSummary> lotCostSummaries; // Consolidado por lote
  // ...
}
```

## Algoritmo Determinístico de Apropriação em Centavos

O serviço `CustoMaoDeObraService` implementa a conservação exata de centavos:
```dart
class CustoMaoDeObraService {
  static WorkerCostSnapshot computeWorkerSnapshot({
    required Funcionario funcionario,
    required ApontamentoTrabalhador apontamento,
    required CostPolicy policy,
  }) {
    // 1. Taxa diária base em função da política da obra
    final baseDailyRateCents = Funcionario.calculateDailyRate(
      salaryBasis: funcionario.salaryBasis,
      baseSalaryCents: funcionario.baseSalaryCents,
      additionalCostsCents: funcionario.additionalCostsCents,
      monthlyDivisor: policy.monthlyDivisor,
    );

    // 2. Taxa diária efetiva conforme presença
    int effectiveCostCents;
    switch (apontamento.status) {
      case PresencaStatus.falta:
        effectiveCostCents = 0;
        break;
      case PresencaStatus.meioPeriodo:
        effectiveCostCents = baseDailyRateCents ~/ 2;
        break;
      case PresencaStatus.presente:
        effectiveCostCents = baseDailyRateCents;
        break;
    }

    if (effectiveCostCents == 0 || apontamento.allocations.isEmpty) {
      return WorkerCostSnapshot(
        workerId: funcionario.id,
        workerName: funcionario.name,
        workerRole: funcionario.role,
        salaryBasis: funcionario.salaryBasis,
        baseSalaryCents: funcionario.baseSalaryCents,
        additionalCostsCents: funcionario.additionalCostsCents,
        baseDailyRateCents: baseDailyRateCents,
        effectiveCostCents: 0,
        status: apontamento.status.value,
        lotAllocations: [],
      );
    }

    // 3. Distribuição percentual em centavos nos lotes
    final totalPercentage = apontamento.totalPercentage; // 100 para presente, 50 para meioPeriodo
    final allocations = <LotCostAllocationSnapshot>[];
    int distributedCents = 0;

    for (final alloc in apontamento.allocations) {
      // Proporção de centavos para cada lote:
      final cents = (effectiveCostCents * alloc.percentage) ~/ totalPercentage;
      allocations.add(LotCostAllocationSnapshot(
        lotId: alloc.lotId,
        lotName: alloc.lotName,
        percentage: alloc.percentage,
        costCents: cents,
      ));
      distributedCents += cents;
    }

    // 4. Ajuste de resíduo de arredondamento (Remainder adjustment)
    final remainder = effectiveCostCents - distributedCents;
    if (remainder != 0 && allocations.isNotEmpty) {
      // Encontra o lote com maior alocação percentual
      int maxIdx = 0;
      for (int i = 1; i < allocations.length; i++) {
        if (allocations[i].percentage > allocations[maxIdx].percentage) {
          maxIdx = i;
        }
      }
      final target = allocations[maxIdx];
      allocations[maxIdx] = LotCostAllocationSnapshot(
        lotId: target.lotId,
        lotName: target.lotName,
        percentage: target.percentage,
        costCents: target.costCents + remainder,
      );
    }

    return WorkerCostSnapshot(
      workerId: funcionario.id,
      workerName: funcionario.name,
      workerRole: funcionario.role,
      salaryBasis: funcionario.salaryBasis,
      baseSalaryCents: funcionario.baseSalaryCents,
      additionalCostsCents: funcionario.additionalCostsCents,
      baseDailyRateCents: baseDailyRateCents,
      effectiveCostCents: effectiveCostCents,
      status: apontamento.status.value,
      lotAllocations: allocations,
    );
  }
}
```

## Security Rules (`firestore.rules`)

As regras para a coleção `chamadas` já protegem autorização e bloqueiam deleção física. Adicionamos a validação de integridade financeira:
```javascript
match /chamadas/{ch} {
  allow read: if dev() || admin(c) || obraMember(c, o);
  allow create, update: if (dev() || admin(c) || obraAdmin(c, o) || rh(c))
    && request.resource.data.id == ch
    && request.resource.data.construtoraId == c
    && request.resource.data.obraId == o
    && request.resource.data.totalDayCostCents is int
    && request.resource.data.totalDayCostCents >= 0
    && request.resource.data.schemaVersion == 1;
  allow delete: if false;
}
```

## UI/UX: Visualização e Fechamento de Custos

### 1. Indicadores de Custo em Tempo Real no Formulário de Chamada
- **Card Resumo Financeiro:** Header informativo exibindo o total do expediente em Reais (`R$ 1.840,00`) e o total de operários presentes.
- **Card do Trabalhador (`ApontamentoWorkerCard`):**
  - Exibição sutil da diária base do colaborador (ex.: `R$ 140,00/dia`).
  - Badge dinâmica de custo efetivo conforme o status:
    - Verde: `R$ 140,00 (100%)` quando presente.
    - Laranja: `R$ 70,00 (50%)` quando meio-período.
    - Cinza: `R$ 0,00` quando falta.
- **Detalhamento no Rateio de Lotes (`RateioLotesSheet`):**
  - Cada fatia de lote exibe a porcentagem e o valor calculado em reais correspondente (ex: `Lote 10 — 60% (R$ 84,00)`).

### 2. Modal de Resumo de Custos por Lote (Fechamento)
- Botão "Resumo Financeiro por Lote" acessível na barra inferior.
- Exibe tabela consolidada:
  - Nome do Lote | Operários Alocados | Custo Total Apropriado (R$).
  - Linha de total geral validando a conciliação exata.

### 3. Listagem Histórica de Chamadas (`ChamadasListScreen`)
- Cada card de chamada no histórico exibe badge estilizado com o valor total consolidado: `Custo Mão de Obra: R$ 2.450,00`.
- Ao clicar no card, os detalhes da chamada exibem tanto a lista de chamada quanto os custos imutáveis gravados no snapshot.

## Code Map

- `app/lib/src/features/rh/domain/custo_mao_de_obra.dart` -- Entidades `CostPolicy`, `WorkerCostSnapshot`, `LotCostAllocationSnapshot` e `LotCostSummary` com serialização JSON e validações.
- `app/lib/src/features/rh/domain/chamada_diaria.dart` -- Atualização do modelo `ChamadaDiaria` para conter `totalDayCostCents`, `costPolicy`, `costSnapshots` e `lotCostSummaries`.
- `app/lib/src/features/rh/data/custo_mao_de_obra_service.dart` -- Serviço puro de cálculo determinístico de custos, apropriação em centavos, tratamento de resíduo e consolidação por lote.
- `app/lib/src/features/rh/presentation/widgets/apontamento_worker_card.dart` -- Evolução do card de operário para exibir taxa diária e custo efetivo em tempo real.
- `app/lib/src/features/rh/presentation/widgets/rateio_lotes_sheet.dart` -- Atualização para exibir valor monetário apropriado em cada lote proporcionalmente.
- `app/lib/src/features/rh/presentation/widgets/resumo_custos_chamada_dialog.dart` -- Diálogo modal consolidando o resumo de custos por lote e geral da chamada.
- `app/lib/src/features/rh/presentation/chamada_form_screen.dart` -- Integração com cálculo automático de snapshots no salvamento/retificação da chamada e exibição de resumo financeiro.
- `app/lib/src/features/rh/presentation/chamadas_list_screen.dart` -- Exibição do total financeiro consolidado em cada card histórico de chamada.
- `firestore.rules` -- Regras de integridade para `totalDayCostCents >= 0` na subcoleção `chamadas`.
- `app/test/rh_custos_apropriacao_test.dart` -- Testes unitários e de integração cobrindo divisores, cálculo de centavos, compensação de resíduo, imutabilidade de snapshots e validação visual.

## Tasks & Acceptance

**Execution:**
- [x] `app/lib/src/features/rh/domain/custo_mao_de_obra.dart` -- Criar modelos de política de custo, snapshots de trabalhadores, apropriações e consolidados de lote.
- [x] `app/lib/src/features/rh/domain/chamada_diaria.dart` -- Adicionar campos de custos e snapshots ao modelo `ChamadaDiaria`.
- [x] `app/lib/src/features/rh/data/custo_mao_de_obra_service.dart` -- Implementar serviço de cálculo com tratamento de centavos e compensação de resíduo.
- [x] `firestore.rules` -- Adicionar validação de `totalDayCostCents is int` e `>= 0` para `chamadas`.
- [x] `app/lib/src/features/rh/presentation/widgets/apontamento_worker_card.dart` -- Atualizar card de operário com preview de custos.
- [x] `app/lib/src/features/rh/presentation/widgets/rateio_lotes_sheet.dart` -- Exibir valores em reais nas fatias de rateio.
- [x] `app/lib/src/features/rh/presentation/widgets/resumo_custos_chamada_dialog.dart` -- Criar diálogo modal com tabela de apropriação por lote.
- [x] `app/lib/src/features/rh/presentation/chamada_form_screen.dart` -- Integrar cálculo de custos no salvamento e feedback de totais.
- [x] `app/lib/src/features/rh/presentation/chamadas_list_screen.dart` -- Exibir badge com custo total nas chamadas da lista.
- [x] `app/test/rh_custos_apropriacao_test.dart` -- Criar suíte completa de testes automatizados unitários e de widgets.

**Acceptance Criteria:**
- Given um colaborador CLT com diária base de R$ 120,00 (12.000 centavos), when marcado como `presente` em 100% no Lote 1, then seu `effectiveCostCents` é gravado como 12.000 centavos e o Lote 1 recebe apropriação de exatamente 12.000 centavos.
- Given um colaborador com diária de R$ 150,00 (15.000 centavos), when marcado como `meio-periodo`, then seu `effectiveCostCents` é 7.500 centavos (R$ 75,00) e a soma das apropriações nos lotes totaliza rigorosamente 7.500 centavos.
- Given um colaborador com status `falta`, when a chamada é salva, then seu `effectiveCostCents` é 0 e o valor apropriado para qualquer lote é R$ 0,00.
- Given uma divisão de rateio com resíduo de centavos (ex: diária de R$ 125,01 dividida 50%/50%), when o cálculo de apropriação é executado, then o resíduo de 1 centavo é somado ao lote principal, garantindo que `sum(costCents) == 12501`.
- Given uma chamada confirmada e gravada com snapshots no Firestore, when o salário do colaborador é reajustado posteriormente no cadastro, then a chamada histórica mantém inalterados os custos gravados no momento do fechamento.
- Given uma obra com `monthlyDivisor = 22`, when a diária de um mensalista é apurada, then o cálculo utiliza 22 como divisor e grava esse parâmetro no snapshot da chamada.
- Given qualquer tentativa de salvar chamada com `totalDayCostCents < 0`, then a validação rejeita a escrita no banco.

## Verification

**Commands:**
- `cd app && flutter test test/rh_custos_apropriacao_test.dart` -- expected: All tests passed!
- `cd app && flutter analyze` -- expected: No issues found!

## Spec Change Log

- 2026-09-17: Criação da especificação técnica completa para a Story 4.3 (RH - Custos de Mão de Obra e Apropriação).

## Review Triage Log

- 2026-09-17: Baseline e integridade de centavos verificados contra Story 3.7 e C3. Divisores configuráveis e resíduo determinístico de arredondamento formalizados.
