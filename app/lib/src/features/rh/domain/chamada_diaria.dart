import 'package:cloud_firestore/cloud_firestore.dart';

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
  final String status; // 'confirmada' | 'retificada' | 'cancelada'
  final String? observacoes;
  final List<ApontamentoTrabalhador> workers;
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
    this.status = 'confirmada',
    this.observacoes,
    this.workers = const [],
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = 1,
  });

  int get totalWorkers => workers.length;
  int get presentCount =>
      workers.where((w) => w.status == PresencaStatus.presente).length;
  int get meioPeriodoCount =>
      workers.where((w) => w.status == PresencaStatus.meioPeriodo).length;
  int get faltaCount =>
      workers.where((w) => w.status == PresencaStatus.falta).length;

  bool get isValid =>
      workers.isNotEmpty && workers.every((w) => w.isValidAllocation);

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

    final rawWorkers = map['workers'] as List<dynamic>? ?? [];

    return ChamadaDiaria(
      id: id ?? map['id'] as String? ?? '',
      construtoraId: map['construtoraId'] as String? ?? '',
      obraId: map['obraId'] as String? ?? '',
      date: map['date'] as String? ?? '',
      teamId: map['teamId'] as String?,
      teamName: map['teamName'] as String?,
      createdByUid: map['createdByUid'] as String? ?? '',
      defaultLotId: map['defaultLotId'] as String?,
      status: map['status'] as String? ?? 'confirmada',
      observacoes: map['observacoes'] as String?,
      workers: rawWorkers
          .map((w) =>
              ApontamentoTrabalhador.fromMap(Map<String, dynamic>.from(w as Map)))
          .toList(),
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }
}
