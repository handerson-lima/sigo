import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

class TermoEpi {
  final String id;
  final String construtoraId;
  final String obraId;
  final String funcionarioId;
  final String funcionarioNome;
  final String funcionarioCpf;
  final List<Map<String, dynamic>>
  itens; // [{epiNome, caNumero, quantidade, dataEntrega}]
  final String textoLegal;
  final String
  tipoConfirmacao; // assinatura_canvas, pin_seguranca, foto_comprovante
  final String? assinaturaStoragePath;
  final String hashSha256;
  final DateTime dataAssinatura;
  final String responsavelUid;
  final int schemaVersion;
  final DateTime? createdAt;

  TermoEpi({
    required this.id,
    required this.construtoraId,
    required this.obraId,
    required this.funcionarioId,
    required this.funcionarioNome,
    required this.funcionarioCpf,
    required this.itens,
    String? textoLegal,
    this.tipoConfirmacao = 'assinatura_canvas',
    this.assinaturaStoragePath,
    String? hashSha256,
    required this.dataAssinatura,
    required this.responsavelUid,
    this.schemaVersion = 1,
    this.createdAt,
  }) : textoLegal = textoLegal ?? termoPadraoNr6,
       hashSha256 =
           hashSha256 ??
           gerarHash(
             funcionarioCpf: funcionarioCpf,
             dataAssinatura: dataAssinatura,
             itens: itens,
             texto: textoLegal ?? termoPadraoNr6,
           );

  static const String termoPadraoNr6 =
      'Declaro para os devidos fins que recebi da empresa os Equipamentos de Proteção Individual (EPIs) '
      'abaixo discriminados, novos e em perfeito estado de conservação, com os devidos Certificados de Aprovação (C.A.). '
      'Comprometo-me a utilizá-los estritamente para os fins a que se destinam durante toda a minha jornada de trabalho, '
      'zelar por sua guarda e conservação, e comunicar imediatamente ao encarregado ou setor de segurança qualquer alteração '
      'ou dano que os torne impróprios para uso, nos termos da Norma Regulamentadora NR-6 e art. 158 da CLT.';

  static String gerarHash({
    required String funcionarioCpf,
    required DateTime dataAssinatura,
    required List<Map<String, dynamic>> itens,
    required String texto,
  }) {
    final payload = jsonEncode({
      'cpf': funcionarioCpf,
      'data': dataAssinatura.toIso8601String(),
      'itens': itens,
      'texto': texto,
    });
    return sha256.convert(utf8.encode(payload)).toString();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'construtoraId': construtoraId,
      'obraId': obraId,
      'funcionarioId': funcionarioId,
      'funcionarioNome': funcionarioNome,
      'funcionarioCpf': funcionarioCpf,
      'itens': itens,
      'textoLegal': textoLegal,
      'tipoConfirmacao': tipoConfirmacao,
      if (assinaturaStoragePath != null)
        'assinaturaStoragePath': assinaturaStoragePath,
      'hashSha256': hashSha256,
      'dataAssinatura': dataAssinatura.toIso8601String(),
      'responsavelUid': responsavelUid,
      'schemaVersion': schemaVersion,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  factory TermoEpi.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String && val.isNotEmpty)
        return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String && val.isNotEmpty) return DateTime.tryParse(val);
      return null;
    }

    final rawItens = map['itens'];
    final List<Map<String, dynamic>> parsedItens = [];
    if (rawItens is List) {
      for (final item in rawItens) {
        if (item is Map) {
          parsedItens.add(Map<String, dynamic>.from(item));
        }
      }
    }

    return TermoEpi(
      id: docId,
      construtoraId: map['construtoraId'] as String? ?? '',
      obraId: map['obraId'] as String? ?? '',
      funcionarioId: map['funcionarioId'] as String? ?? '',
      funcionarioNome: map['funcionarioNome'] as String? ?? '',
      funcionarioCpf: map['funcionarioCpf'] as String? ?? '',
      itens: parsedItens,
      textoLegal: map['textoLegal'] as String? ?? termoPadraoNr6,
      tipoConfirmacao: map['tipoConfirmacao'] as String? ?? 'assinatura_canvas',
      assinaturaStoragePath: map['assinaturaStoragePath'] as String?,
      hashSha256: map['hashSha256'] as String? ?? '',
      dataAssinatura: parseDate(map['dataAssinatura']),
      responsavelUid: map['responsavelUid'] as String? ?? '',
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
      createdAt: parseNullableDate(map['createdAt']),
    );
  }
}
