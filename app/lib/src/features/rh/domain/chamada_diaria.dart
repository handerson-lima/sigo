import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/contracts.dart';
import 'chamada_audit_entry.dart';
import 'chamada_status.dart';
import 'custo_mao_de_obra.dart';
import 'rh_invariante_validator.dart';

enum PresencaStatus {
  presente('presente', 'Presente', 'P'),
  meioPeriodo('meio-periodo', 'Meio-Período', '1/2'),
  falta('falta', 'Falta', 'F');

  final String value;
  final String label;
  final String shortCode;

  const PresencaStatus(this.value, this.label, this.shortCode);

  static PresencaStatus fromString(String? val) {
    switch (val) {
      case 'presente':
        return PresencaStatus.presente;
      case 'meio-periodo':
      case 'meioPeriodo':
        return PresencaStatus.meioPeriodo;
      case 'falta':
      default:
        return PresencaStatus.falta;
    }
  }
}

class AlocacaoLote {
  final String lotId;
  final String lotName;
  final int percentage;

  const AlocacaoLote({
    required this.lotId,
    required this.lotName,
    required this.percentage,
  });

  Map<String, dynamic> toMap() {
    return {
      'lotId': lotId,
      'lotName': lotName,
      'percentage': percentage,
    };
  }

  factory AlocacaoLote.fromMap(Map<String, dynamic> map) {
    return AlocacaoLote(
      lotId: map['lotId'] as String? ?? '',
      lotName: map['lotName'] as String? ?? '',
      percentage: (map['percentage'] as num?)?.toInt() ?? 0,
    );
  }

  AlocacaoLote copyWith({
    String? lotId,
    String? lotName,
    int? percentage,
  }) {
    return AlocacaoLote(
      lotId: lotId ?? this.lotId,
      lotName: lotName ?? this.lotName,
      percentage: percentage ?? this.percentage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlocacaoLote &&
          runtimeType == other.runtimeType &&
          lotId == other.lotId &&
          percentage == other.percentage;

  @override
  int get hashCode => lotId.hashCode ^ percentage.hashCode;
}

class ApontamentoTrabalhador {
  final String workerId;
  final String workerName;
  final String workerRole;
  final PresencaStatus status;
  final List<AlocacaoLote> allocations;

  const ApontamentoTrabalhador({
    required this.workerId,
    required this.workerName,
    required this.workerRole,
    required this.status,
    this.allocations = const [],
  });

  int get totalPercentage =>
      allocations.fold(0, (total, a) => total + a.percentage);

  bool get isValidAllocation {
    switch (status) {
      case PresencaStatus.falta:
        return totalPercentage == 0;
      case PresencaStatus.meioPeriodo:
        return totalPercentage == 50;
      case PresencaStatus.presente:
        return totalPercentage == 100;
    }
  }

  String? get validationError {
    if (isValidAllocation) return null;
    switch (status) {
      case PresencaStatus.falta:
        return 'Colaborador ausente não deve ter lotes alocados';
      case PresencaStatus.meioPeriodo:
        return 'Meio-período deve totalizar 50% (atual: $totalPercentage%)';
      case PresencaStatus.presente:
        return 'Presença integral deve totalizar 100% (atual: $totalPercentage%)';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'workerId': workerId,
      'workerName': workerName,
      'workerRole': workerRole,
      'status': status.value,
      'allocations': allocations.map((a) => a.toMap()).toList(),
    };
  }

  factory ApontamentoTrabalhador.fromMap(Map<String, dynamic> map) {
    final rawStatus = map['status'] as String?;
    final rawAllocations = map['allocations'] as List<dynamic>? ?? [];
    return ApontamentoTrabalhador(
      workerId: map['workerId'] as String? ?? '',
      workerName: map['workerName'] as String? ?? '',
      workerRole: map['workerRole'] as String? ?? '',
      status: PresencaStatus.fromString(rawStatus),
      allocations: rawAllocations
          .map((a) => AlocacaoLote.fromMap(Map<String, dynamic>.from(a as Map)))
          .toList(),
    );
  }

  ApontamentoTrabalhador copyWith({
    String? workerId,
    String? workerName,
    String? workerRole,
    PresencaStatus? status,
    List<AlocacaoLote>? allocations,
  }) {
    return ApontamentoTrabalhador(
      workerId: workerId ?? this.workerId,
      workerName: workerName ?? this.workerName,
      workerRole: workerRole ?? this.workerRole,
      status: status ?? this.status,
      allocations: allocations ?? this.allocations,
    );
  }
}

class ChamadaDiaria {
  final String id;
  final String construtoraId;
  final String obraId;
  final String date; // YYYY-MM-DD
  final String? teamId;
  final String? teamName;
  final String createdByUid;
  final String? defaultLotId;
  final String status; // 'confirmada' | 'fechada' | 'retificada' | 'cancelada'
  final String? observacoes;
  final List<ApontamentoTrabalhador> workers;
  final int totalDayCostCents;
  final String costPolicyVersion;
  final CostPolicy? costPolicy;
  final List<WorkerCostSnapshot> costSnapshots;
  final List<LotCostSummary> lotCostSummaries;
  final int versaoAuditoria;
  final List<ChamadaAuditEntry> auditTrail;
  final String? retificadoPor;
  final DateTime? retificadoEm;
  final String? motivoRetificacao;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;

  const ChamadaDiaria({
    required this.id,
    required this.construtoraId,
    required this.obraId,
    required this.date,
    this.teamId,
    this.teamName,
    required this.createdByUid,
    this.defaultLotId,
    this.status = 'fechada',
    this.observacoes,
    this.workers = const [],
    this.totalDayCostCents = 0,
    this.costPolicyVersion = 'v1',
    this.costPolicy,
    this.costSnapshots = const [],
    this.lotCostSummaries = const [],
    this.versaoAuditoria = 1,
    this.auditTrail = const [],
    this.retificadoPor,
    this.retificadoEm,
    this.motivoRetificacao,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = 1,
  });

  ChamadaStatus get chamadaStatus => ChamadaStatus.fromValue(status);
  bool get isRetificada => chamadaStatus == ChamadaStatus.retificada;

  int get totalWorkers => workers.length;
  int get presentCount =>
      workers.where((w) => w.status == PresencaStatus.presente).length;
  int get meioPeriodoCount =>
      workers.where((w) => w.status == PresencaStatus.meioPeriodo).length;
  int get faltaCount =>
      workers.where((w) => w.status == PresencaStatus.falta).length;

  bool get isValid =>
      workers.isNotEmpty &&
      RhInvarianteValidator.validarChamada(apontamentos: workers).isEmpty;

  String get formattedTotalCost => formatCents(totalDayCostCents);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'construtoraId': construtoraId,
      'obraId': obraId,
      'date': date,
      'teamId': teamId,
      'teamName': teamName,
      'createdByUid': createdByUid,
      'defaultLotId': defaultLotId,
      'status': status,
      'observacoes': observacoes,
      'workers': workers.map((w) => w.toMap()).toList(),
      'totalDayCostCents': totalDayCostCents,
      'costPolicyVersion': costPolicyVersion,
      if (costPolicy != null) 'costPolicy': costPolicy!.toMap(),
      'costSnapshots': costSnapshots.map((s) => s.toMap()).toList(),
      'lotCostSummaries': lotCostSummaries.map((s) => s.toMap()).toList(),
      'versaoAuditoria': versaoAuditoria,
      'auditTrail': auditTrail.map((a) => a.toMap()).toList(),
      if (retificadoPor != null) 'retificadoPor': retificadoPor,
      if (retificadoEm != null)
        'retificadoEm': Timestamp.fromDate(retificadoEm!),
      if (motivoRetificacao != null) 'motivoRetificacao': motivoRetificacao,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'schemaVersion': schemaVersion,
    };
  }

  factory ChamadaDiaria.fromMap(Map<String, dynamic> map, {String? id}) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime? parseNullableDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    final rawWorkers = map['workers'] as List<dynamic>? ?? [];
    final rawCostSnapshots = map['costSnapshots'] as List<dynamic>? ?? [];
    final rawLotCostSummaries = map['lotCostSummaries'] as List<dynamic>? ?? [];
    final rawAuditTrail = map['auditTrail'] as List<dynamic>? ?? [];

    return ChamadaDiaria(
      id: id ?? map['id'] as String? ?? '',
      construtoraId: map['construtoraId'] as String? ?? '',
      obraId: map['obraId'] as String? ?? '',
      date: map['date'] as String? ?? '',
      teamId: map['teamId'] as String?,
      teamName: map['teamName'] as String?,
      createdByUid: map['createdByUid'] as String? ?? '',
      defaultLotId: map['defaultLotId'] as String?,
      status: map['status'] as String? ?? 'fechada',
      observacoes: map['observacoes'] as String?,
      workers: rawWorkers
          .map((w) =>
              ApontamentoTrabalhador.fromMap(Map<String, dynamic>.from(w as Map)))
          .toList(),
      totalDayCostCents: (map['totalDayCostCents'] as num?)?.toInt() ?? 0,
      costPolicyVersion: map['costPolicyVersion'] as String? ?? 'v1',
      costPolicy: map['costPolicy'] != null
          ? CostPolicy.fromMap(Map<String, dynamic>.from(map['costPolicy'] as Map))
          : null,
      costSnapshots: rawCostSnapshots
          .map((s) =>
              WorkerCostSnapshot.fromMap(Map<String, dynamic>.from(s as Map)))
          .toList(),
      lotCostSummaries: rawLotCostSummaries
          .map((l) =>
              LotCostSummary.fromMap(Map<String, dynamic>.from(l as Map)))
          .toList(),
      versaoAuditoria: (map['versaoAuditoria'] as num?)?.toInt() ?? 1,
      auditTrail: rawAuditTrail
          .map((a) =>
              ChamadaAuditEntry.fromMap(Map<String, dynamic>.from(a as Map)))
          .toList(),
      retificadoPor: map['retificadoPor'] as String?,
      retificadoEm: parseNullableDate(map['retificadoEm']),
      motivoRetificacao: map['motivoRetificacao'] as String?,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }

  ChamadaDiaria copyWith({
    String? id,
    String? construtoraId,
    String? obraId,
    String? date,
    String? teamId,
    String? teamName,
    String? createdByUid,
    String? defaultLotId,
    String? status,
    String? observacoes,
    List<ApontamentoTrabalhador>? workers,
    int? totalDayCostCents,
    String? costPolicyVersion,
    CostPolicy? costPolicy,
    List<WorkerCostSnapshot>? costSnapshots,
    List<LotCostSummary>? lotCostSummaries,
    int? versaoAuditoria,
    List<ChamadaAuditEntry>? auditTrail,
    String? retificadoPor,
    DateTime? retificadoEm,
    String? motivoRetificacao,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? schemaVersion,
  }) {
    return ChamadaDiaria(
      id: id ?? this.id,
      construtoraId: construtoraId ?? this.construtoraId,
      obraId: obraId ?? this.obraId,
      date: date ?? this.date,
      teamId: teamId ?? this.teamId,
      teamName: teamName ?? this.teamName,
      createdByUid: createdByUid ?? this.createdByUid,
      defaultLotId: defaultLotId ?? this.defaultLotId,
      status: status ?? this.status,
      observacoes: observacoes ?? this.observacoes,
      workers: workers ?? this.workers,
      totalDayCostCents: totalDayCostCents ?? this.totalDayCostCents,
      costPolicyVersion: costPolicyVersion ?? this.costPolicyVersion,
      costPolicy: costPolicy ?? this.costPolicy,
      costSnapshots: costSnapshots ?? this.costSnapshots,
      lotCostSummaries: lotCostSummaries ?? this.lotCostSummaries,
      versaoAuditoria: versaoAuditoria ?? this.versaoAuditoria,
      auditTrail: auditTrail ?? this.auditTrail,
      retificadoPor: retificadoPor ?? this.retificadoPor,
      retificadoEm: retificadoEm ?? this.retificadoEm,
      motivoRetificacao: motivoRetificacao ?? this.motivoRetificacao,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }
}
