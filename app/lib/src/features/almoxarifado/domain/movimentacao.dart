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
  });

  factory Movimentacao.fromJson(Map<String, dynamic> json) =>
      _$MovimentacaoFromJson(compatibleDates(json, ['date']));

  Map<String, dynamic> toJson() => _$MovimentacaoToJson(this);
}
