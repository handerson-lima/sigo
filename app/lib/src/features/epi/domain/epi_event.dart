import 'package:cloud_firestore/cloud_firestore.dart';

class EpiEvent {
  final String id;
  final String construtoraId;
  final String obraId;
  final String funcionarioId;
  final String funcionarioNome;
  final String epiId;
  final String epiNome;
  final String caNumero;
  final String tipoEvento; // entrega, substituicao, devolucao, baixa_descarte
  final int quantidade;
  final String? motivo;
  final DateTime dataEvento;
  final String responsavelUid;
  final String responsavelNome;
  final String? termoId;
  final String status; // ativo, substituido, devolvido, baixado
  final DateTime? dataTrocaPrevista;
  final String? observacoes;
  final int schemaVersion;
  final DateTime? createdAt;

  EpiEvent({
    required this.id,
    required this.construtoraId,
    required this.obraId,
    required this.funcionarioId,
    required this.funcionarioNome,
    required this.epiId,
    required this.epiNome,
    required this.caNumero,
    required this.tipoEvento,
    this.quantidade = 1,
    this.motivo,
    required this.dataEvento,
    required this.responsavelUid,
    required this.responsavelNome,
    this.termoId,
    this.status = 'ativo',
    this.dataTrocaPrevista,
    this.observacoes,
    this.schemaVersion = 1,
    this.createdAt,
  });

  bool get isEntrega => tipoEvento == 'entrega' || tipoEvento == 'substituicao';
  bool get isDevolvidoOuBaixado => tipoEvento == 'devolucao' || tipoEvento == 'baixa_descarte';
  bool get isTrocaVencida {
    if (dataTrocaPrevista == null || status != 'ativo') return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return dataTrocaPrevista!.isBefore(today);
  }

  String get tipoEventoFormatado {
    switch (tipoEvento) {
      case 'entrega':
        return 'Entrega Inicial';
      case 'substituicao':
        return 'Substituição';
      case 'devolucao':
        return 'Devolução';
      case 'baixa_descarte':
        return 'Baixa / Descarte';
      default:
        return tipoEvento;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'construtoraId': construtoraId,
      'obraId': obraId,
      'funcionarioId': funcionarioId,
      'funcionarioNome': funcionarioNome,
      'epiId': epiId,
      'epiNome': epiNome,
      'caNumero': caNumero,
      'tipoEvento': tipoEvento,
      'quantidade': quantidade,
      if (motivo != null) 'motivo': motivo,
      'dataEvento': dataEvento.toIso8601String().split('T').first,
      'responsavelUid': responsavelUid,
      'responsavelNome': responsavelNome,
      if (termoId != null) 'termoId': termoId,
      'status': status,
      if (dataTrocaPrevista != null) 'dataTrocaPrevista': dataTrocaPrevista!.toIso8601String().split('T').first,
      if (observacoes != null) 'observacoes': observacoes,
      'schemaVersion': schemaVersion,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory EpiEvent.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val, [DateTime? fallback]) {
      if (val is Timestamp) return val.toDate();
      if (val is String && val.isNotEmpty) return DateTime.tryParse(val) ?? (fallback ?? DateTime.now());
      return fallback ?? DateTime.now();
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String && val.isNotEmpty) return DateTime.tryParse(val);
      return null;
    }

    return EpiEvent(
      id: docId,
      construtoraId: map['construtoraId'] as String? ?? '',
      obraId: map['obraId'] as String? ?? '',
      funcionarioId: map['funcionarioId'] as String? ?? '',
      funcionarioNome: map['funcionarioNome'] as String? ?? '',
      epiId: map['epiId'] as String? ?? '',
      epiNome: map['epiNome'] as String? ?? '',
      caNumero: map['caNumero'] as String? ?? '',
      tipoEvento: map['tipoEvento'] as String? ?? 'entrega',
      quantidade: (map['quantidade'] as num?)?.toInt() ?? 1,
      motivo: map['motivo'] as String?,
      dataEvento: parseDate(map['dataEvento']),
      responsavelUid: map['responsavelUid'] as String? ?? '',
      responsavelNome: map['responsavelNome'] as String? ?? '',
      termoId: map['termoId'] as String?,
      status: map['status'] as String? ?? 'ativo',
      dataTrocaPrevista: parseNullableDate(map['dataTrocaPrevista']),
      observacoes: map['observacoes'] as String?,
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
      createdAt: parseNullableDate(map['createdAt']),
    );
  }

  EpiEvent copyWith({
    String? id,
    String? construtoraId,
    String? obraId,
    String? funcionarioId,
    String? funcionarioNome,
    String? epiId,
    String? epiNome,
    String? caNumero,
    String? tipoEvento,
    int? quantidade,
    String? motivo,
    DateTime? dataEvento,
    String? responsavelUid,
    String? responsavelNome,
    String? termoId,
    String? status,
    DateTime? dataTrocaPrevista,
    String? observacoes,
    int? schemaVersion,
    DateTime? createdAt,
  }) {
    return EpiEvent(
      id: id ?? this.id,
      construtoraId: construtoraId ?? this.construtoraId,
      obraId: obraId ?? this.obraId,
      funcionarioId: funcionarioId ?? this.funcionarioId,
      funcionarioNome: funcionarioNome ?? this.funcionarioNome,
      epiId: epiId ?? this.epiId,
      epiNome: epiNome ?? this.epiNome,
      caNumero: caNumero ?? this.caNumero,
      tipoEvento: tipoEvento ?? this.tipoEvento,
      quantidade: quantidade ?? this.quantidade,
      motivo: motivo ?? this.motivo,
      dataEvento: dataEvento ?? this.dataEvento,
      responsavelUid: responsavelUid ?? this.responsavelUid,
      responsavelNome: responsavelNome ?? this.responsavelNome,
      termoId: termoId ?? this.termoId,
      status: status ?? this.status,
      dataTrocaPrevista: dataTrocaPrevista ?? this.dataTrocaPrevista,
      observacoes: observacoes ?? this.observacoes,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
