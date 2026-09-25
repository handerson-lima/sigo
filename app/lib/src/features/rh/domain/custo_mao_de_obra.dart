class CostPolicy {
  final String version;
  final int monthlyDivisor;
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

  CostPolicy copyWith({
    String? version,
    int? monthlyDivisor,
    String? description,
  }) {
    return CostPolicy(
      version: version ?? this.version,
      monthlyDivisor: monthlyDivisor ?? this.monthlyDivisor,
      description: description ?? this.description,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CostPolicy &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          monthlyDivisor == other.monthlyDivisor;

  @override
  int get hashCode => version.hashCode ^ monthlyDivisor.hashCode;
}

class LotCostAllocationSnapshot {
  final String lotId;
  final String lotName;
  final int percentage;
  final int costCents;

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

  factory LotCostAllocationSnapshot.fromMap(Map<String, dynamic> map) =>
      LotCostAllocationSnapshot(
        lotId: map['lotId'] as String? ?? '',
        lotName: map['lotName'] as String? ?? '',
        percentage: (map['percentage'] as num?)?.toInt() ?? 0,
        costCents: (map['costCents'] as num?)?.toInt() ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LotCostAllocationSnapshot &&
          runtimeType == other.runtimeType &&
          lotId == other.lotId &&
          percentage == other.percentage &&
          costCents == other.costCents;

  @override
  int get hashCode => lotId.hashCode ^ percentage.hashCode ^ costCents.hashCode;
}

class WorkerCostSnapshot {
  final String workerId;
  final String workerName;
  final String workerRole;
  final String salaryBasis; // 'mensal' | 'diaria'
  final int baseSalaryCents;
  final int additionalCostsCents;
  final int baseDailyRateCents;
  final int effectiveCostCents;
  final String status;
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

  factory WorkerCostSnapshot.fromMap(Map<String, dynamic> map) =>
      WorkerCostSnapshot(
        workerId: map['workerId'] as String? ?? '',
        workerName: map['workerName'] as String? ?? '',
        workerRole: map['workerRole'] as String? ?? '',
        salaryBasis: map['salaryBasis'] as String? ?? 'mensal',
        baseSalaryCents: (map['baseSalaryCents'] as num?)?.toInt() ?? 0,
        additionalCostsCents:
            (map['additionalCostsCents'] as num?)?.toInt() ?? 0,
        baseDailyRateCents: (map['baseDailyRateCents'] as num?)?.toInt() ?? 0,
        effectiveCostCents: (map['effectiveCostCents'] as num?)?.toInt() ?? 0,
        status: map['status'] as String? ?? 'falta',
        lotAllocations: ((map['lotAllocations'] as List<dynamic>?) ?? [])
            .map(
              (a) => LotCostAllocationSnapshot.fromMap(
                Map<String, dynamic>.from(a as Map),
              ),
            )
            .toList(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkerCostSnapshot &&
          runtimeType == other.runtimeType &&
          workerId == other.workerId &&
          effectiveCostCents == other.effectiveCostCents &&
          status == other.status;

  @override
  int get hashCode =>
      workerId.hashCode ^ effectiveCostCents.hashCode ^ status.hashCode;
}

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LotCostSummary &&
          runtimeType == other.runtimeType &&
          lotId == other.lotId &&
          totalCostCents == other.totalCostCents &&
          workerCount == other.workerCount;

  @override
  int get hashCode =>
      lotId.hashCode ^ totalCostCents.hashCode ^ workerCount.hashCode;
}
