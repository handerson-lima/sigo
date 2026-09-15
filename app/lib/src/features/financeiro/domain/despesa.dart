import '../../../core/contracts.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

part 'despesa.g.dart';

enum StatusDespesa { pendente, pago, atrasado }

@JsonSerializable()
class Despesa {
  final String id;
  final String construtoraId;
  final String? obraId; // Nullable se for um custo administrativo global
  final String descricao;
  final int valorEmCentavos;
  double get valor => valorEmCentavos / 100;
  final DateTime dataVencimento;
  final DateTime? dataPagamento;
  final StatusDespesa status;
  final String categoria; // String para permitir que admins editem no futuro
  final String responsavelId;
  final DateTime createdAt;

  Despesa({
    required this.id,
    required this.construtoraId,
    this.obraId,
    required this.descricao,
    required double valor,
    int? valorEmCentavos,
    required this.dataVencimento,
    this.dataPagamento,
    required this.status,
    required this.categoria,
    required this.responsavelId,
    required this.createdAt,
  }) : valorEmCentavos = valorEmCentavos ?? decimalUnits(valor, 2, round: true);

  factory Despesa.fromJson(Map<String, dynamic> json) {
    final data = compatibleDates(json, [
      'dataVencimento',
      'dataPagamento',
      'createdAt',
    ]);
    final cents =
        json['valorEmCentavos'] ?? decimalUnits(json['valor'], 2, round: true);
    if (cents is! int || cents <= 0 || cents > 9007199254740991) {
      throw const FormatException('Valor inválido');
    }
    data['valor'] = cents / 100;
    data['valorEmCentavos'] = cents;
    return _$DespesaFromJson(data);
  }
  Map<String, dynamic> toJson() => {
    ..._$DespesaToJson(this),
    'valor': valorEmCentavos / 100,
    'valorEmCentavos': valorEmCentavos,
    'schemaVersion': 2,
    'dataVencimento': civilDate(dataVencimento),
    'createdAt': Timestamp.fromDate(createdAt),
    'dataPagamento': dataPagamento == null
        ? null
        : Timestamp.fromDate(dataPagamento!),
  };
}
