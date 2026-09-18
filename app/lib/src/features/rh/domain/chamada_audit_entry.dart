import 'package:cloud_firestore/cloud_firestore.dart';

class ChamadaAuditEntry {
  final String id;
  final String userId;
  final String userName;
  final DateTime timestamp;
  final String motivo;
  final int totalCostCentsAnterior;
  final int totalCostCentsNovo;
  final int versaoAnterior;
  final Map<String, dynamic>? snapshotAnterior;

  const ChamadaAuditEntry({
    required this.id,
    required this.userId,
    required this.userName,
    required this.timestamp,
    required this.motivo,
    required this.totalCostCentsAnterior,
    required this.totalCostCentsNovo,
    required this.versaoAnterior,
    this.snapshotAnterior,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'timestamp': timestamp.toIso8601String(),
        'motivo': motivo,
        'totalCostCentsAnterior': totalCostCentsAnterior,
        'totalCostCentsNovo': totalCostCentsNovo,
        'versaoAnterior': versaoAnterior,
        if (snapshotAnterior != null) 'snapshotAnterior': snapshotAnterior,
      };

  factory ChamadaAuditEntry.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return ChamadaAuditEntry(
      id: map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      userName: map['userName'] as String? ?? '',
      timestamp: parseDate(map['timestamp']),
      motivo: map['motivo'] as String? ?? '',
      totalCostCentsAnterior:
          (map['totalCostCentsAnterior'] as num?)?.toInt() ?? 0,
      totalCostCentsNovo: (map['totalCostCentsNovo'] as num?)?.toInt() ?? 0,
      versaoAnterior: (map['versaoAnterior'] as num?)?.toInt() ?? 1,
      snapshotAnterior: map['snapshotAnterior'] != null
          ? Map<String, dynamic>.from(map['snapshotAnterior'] as Map)
          : null,
    );
  }

  ChamadaAuditEntry copyWith({
    String? id,
    String? userId,
    String? userName,
    DateTime? timestamp,
    String? motivo,
    int? totalCostCentsAnterior,
    int? totalCostCentsNovo,
    int? versaoAnterior,
    Map<String, dynamic>? snapshotAnterior,
  }) {
    return ChamadaAuditEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      timestamp: timestamp ?? this.timestamp,
      motivo: motivo ?? this.motivo,
      totalCostCentsAnterior:
          totalCostCentsAnterior ?? this.totalCostCentsAnterior,
      totalCostCentsNovo: totalCostCentsNovo ?? this.totalCostCentsNovo,
      versaoAnterior: versaoAnterior ?? this.versaoAnterior,
      snapshotAnterior: snapshotAnterior ?? this.snapshotAnterior,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChamadaAuditEntry &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          motivo == other.motivo &&
          versaoAnterior == other.versaoAnterior;

  @override
  int get hashCode =>
      id.hashCode ^ userId.hashCode ^ motivo.hashCode ^ versaoAnterior.hashCode;
}
