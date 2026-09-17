import '../domain/chamada_diaria.dart';
import '../domain/custo_mao_de_obra.dart';
import '../domain/funcionario.dart';

class ChamadaCostsResult {
  final int totalDayCostCents;
  final List<WorkerCostSnapshot> costSnapshots;
  final List<LotCostSummary> lotCostSummaries;

  const ChamadaCostsResult({
    required this.totalDayCostCents,
    required this.costSnapshots,
    required this.lotCostSummaries,
  });
}

class CustoMaoDeObraService {
  const CustoMaoDeObraService();

  static WorkerCostSnapshot computeWorkerSnapshot({
    required Funcionario funcionario,
    required ApontamentoTrabalhador apontamento,
    CostPolicy policy = const CostPolicy(),
  }) {
    final baseDailyRateCents = Funcionario.calculateDailyRate(
      salaryBasis: funcionario.salaryBasis,
      baseSalaryCents: funcionario.baseSalaryCents,
      additionalCostsCents: funcionario.additionalCostsCents,
      monthlyDivisor: policy.monthlyDivisor,
    );

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
        lotAllocations: const [],
      );
    }

    final totalPercentage = apontamento.totalPercentage;
    final divisor = totalPercentage > 0 ? totalPercentage : 100;

    final allocations = <LotCostAllocationSnapshot>[];
    int distributedCents = 0;

    for (final alloc in apontamento.allocations) {
      final cents = (effectiveCostCents * alloc.percentage) ~/ divisor;
      allocations.add(
        LotCostAllocationSnapshot(
          lotId: alloc.lotId,
          lotName: alloc.lotName,
          percentage: alloc.percentage,
          costCents: cents,
        ),
      );
      distributedCents += cents;
    }

    // Compensação exata de resíduo de arredondamento no lote de maior alocação
    final remainder = effectiveCostCents - distributedCents;
    if (remainder != 0 && allocations.isNotEmpty) {
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

  static ChamadaCostsResult computeChamadaCosts({
    required List<Funcionario> funcionarios,
    required List<ApontamentoTrabalhador> apontamentos,
    CostPolicy policy = const CostPolicy(),
  }) {
    final funcMap = {for (final f in funcionarios) f.id: f};
    final snapshots = <WorkerCostSnapshot>[];

    for (final apontamento in apontamentos) {
      final funcionario = funcMap[apontamento.workerId] ??
          Funcionario(
            id: apontamento.workerId,
            construtoraId: '',
            name: apontamento.workerName,
            cpf: '',
            role: apontamento.workerRole,
            employmentType: 'clt',
            salaryBasis: 'diaria',
            baseSalaryCents: 0,
          );

      snapshots.add(
        computeWorkerSnapshot(
          funcionario: funcionario,
          apontamento: apontamento,
          policy: policy,
        ),
      );
    }

    final totalDayCostCents =
        snapshots.fold<int>(0, (sum, s) => sum + s.effectiveCostCents);

    final lotDataMap = <String, _LotAccumulator>{};
    for (final snapshot in snapshots) {
      for (final alloc in snapshot.lotAllocations) {
        final acc = lotDataMap.putIfAbsent(
          alloc.lotId,
          () => _LotAccumulator(lotId: alloc.lotId, lotName: alloc.lotName),
        );
        acc.totalCostCents += alloc.costCents;
        acc.workerIds.add(snapshot.workerId);
      }
    }

    final lotCostSummaries = lotDataMap.values
        .map(
          (acc) => LotCostSummary(
            lotId: acc.lotId,
            lotName: acc.lotName,
            totalCostCents: acc.totalCostCents,
            workerCount: acc.workerIds.length,
          ),
        )
        .toList()
      ..sort((a, b) => a.lotName.compareTo(b.lotName));

    return ChamadaCostsResult(
      totalDayCostCents: totalDayCostCents,
      costSnapshots: snapshots,
      lotCostSummaries: lotCostSummaries,
    );
  }
}

class _LotAccumulator {
  final String lotId;
  final String lotName;
  int totalCostCents = 0;
  final Set<String> workerIds = {};

  _LotAccumulator({
    required this.lotId,
    required this.lotName,
  });
}
