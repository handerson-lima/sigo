import 'package:cloud_firestore/cloud_firestore.dart';

class EpiItem {
  final String id;
  final String construtoraId;
  final String nome;
  final String fabricante;
  final String categoria; // cabeca, ocular, auditiva, respiratoria, maos_bracos, pes_pernas, altura, outros
  final String caNumero;
  final DateTime caValidade;
  final int vidaUtilDias;
  final String unidade; // un, par, kit
  final String? descricao;
  final bool isActive;
  final int schemaVersion;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  EpiItem({
    required this.id,
    required this.construtoraId,
    required this.nome,
    required this.fabricante,
    required this.categoria,
    required this.caNumero,
    required this.caValidade,
    this.vidaUtilDias = 180,
    this.unidade = 'un',
    this.descricao,
    this.isActive = true,
    this.schemaVersion = 1,
    this.createdAt,
    this.updatedAt,
  });

  bool get isCaVencido {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final val = DateTime(caValidade.year, caValidade.month, caValidade.day);
    return val.isBefore(today);
  }

  bool isCaProximoVencimento([int dias = 30]) {
    if (isCaVencido) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final limite = today.add(Duration(days: dias));
    final val = DateTime(caValidade.year, caValidade.month, caValidade.day);
    return !val.isAfter(limite);
  }

  int get diasParaVencer {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final val = DateTime(caValidade.year, caValidade.month, caValidade.day);
    return val.difference(today).inDays;
  }

  String get categoriaFormatada {
    switch (categoria) {
      case 'cabeca':
        return 'Proteção da Cabeça';
      case 'ocular':
        return 'Proteção dos Olhos/Face';
      case 'auditiva':
        return 'Proteção Auditiva';
      case 'respiratoria':
        return 'Proteção Respiratória';
      case 'maos_bracos':
        return 'Proteção dos Membros Superiores';
      case 'pes_pernas':
        return 'Proteção dos Membros Inferiores';
      case 'altura':
        return 'Proteção contra Quedas';
      default:
        return 'Outros Equipamentos';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'construtoraId': construtoraId,
      'nome': nome,
      'fabricante': fabricante,
      'categoria': categoria,
      'caNumero': caNumero,
      'caValidade': caValidade.toIso8601String().split('T').first,
      'vidaUtilDias': vidaUtilDias,
      'unidade': unidade,
      if (descricao != null) 'descricao': descricao,
      'isActive': isActive,
      'schemaVersion': schemaVersion,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory EpiItem.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parsedValidade = DateTime.now().add(const Duration(days: 365));
    final rawVal = map['caValidade'];
    if (rawVal is Timestamp) {
      parsedValidade = rawVal.toDate();
    } else if (rawVal is String && rawVal.isNotEmpty) {
      parsedValidade = DateTime.tryParse(rawVal) ?? parsedValidade;
    }

    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
      return null;
    }

    return EpiItem(
      id: docId,
      construtoraId: map['construtoraId'] as String? ?? '',
      nome: map['nome'] as String? ?? '',
      fabricante: map['fabricante'] as String? ?? '',
      categoria: map['categoria'] as String? ?? 'outros',
      caNumero: map['caNumero'] as String? ?? '',
      caValidade: parsedValidade,
      vidaUtilDias: (map['vidaUtilDias'] as num?)?.toInt() ?? 180,
      unidade: map['unidade'] as String? ?? 'un',
      descricao: map['descricao'] as String?,
      isActive: map['isActive'] as bool? ?? true,
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  EpiItem copyWith({
    String? id,
    String? construtoraId,
    String? nome,
    String? fabricante,
    String? categoria,
    String? caNumero,
    DateTime? caValidade,
    int? vidaUtilDias,
    String? unidade,
    String? descricao,
    bool? isActive,
    int? schemaVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EpiItem(
      id: id ?? this.id,
      construtoraId: construtoraId ?? this.construtoraId,
      nome: nome ?? this.nome,
      fabricante: fabricante ?? this.fabricante,
      categoria: categoria ?? this.categoria,
      caNumero: caNumero ?? this.caNumero,
      caValidade: caValidade ?? this.caValidade,
      vidaUtilDias: vidaUtilDias ?? this.vidaUtilDias,
      unidade: unidade ?? this.unidade,
      descricao: descricao ?? this.descricao,
      isActive: isActive ?? this.isActive,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
