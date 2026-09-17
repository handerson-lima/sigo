import '../../../core/contracts.dart';

import 'package:json_annotation/json_annotation.dart';

part 'movimentacao.g.dart';

enum MovimentacaoType { entrada, saida }

@JsonSerializable()
class Movimentacao {
  final String id;
  final String materialId;
  final MovimentacaoType type;
  final double quantity;
  final DateTime date;
  final String responsavelId;
  final String? obraId; // Para qual obra foi encaminhado (nas saídas)
  final String? loteId; // Para qual lote foi encaminhado (opcional)
  final String? observacao;
  final String? evidence; // Caminho/URL da foto ou anexo da NF
  final String? nfNumber; // Número da Nota Fiscal
  final String? fornecedor; // Razão social ou nome do fornecedor

  Movimentacao({
    required this.id,
    required this.materialId,
    required this.type,
    required this.quantity,
    required this.date,
    required this.responsavelId,
    this.obraId,
    this.loteId,
    this.observacao,
    this.evidence,
    this.nfNumber,
    this.fornecedor,
  });

  factory Movimentacao.fromJson(Map<String, dynamic> json) =>
      _$MovimentacaoFromJson(compatibleDates(json, ['date']));

  Map<String, dynamic> toJson() => _$MovimentacaoToJson(this);
}
