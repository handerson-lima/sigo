import 'package:json_annotation/json_annotation.dart';

part 'lote.g.dart';

enum LoteStatus {
  noPrazo,
  atrasado,
  paralisado,
  concluido,
}

const List<String> defaultLotePhases = [
  'Plantas',
  'Fundação',
  'Estrutura',
  'Alvenaria',
  'Acabamento',
  'Entregue'
];

@JsonSerializable()
class Lote {
  final String id;
  final String construtoraId;
  final String loteamentoId;
  final String quadraId;
  final String name;
  final String phase;
  final LoteStatus status;
  final String? responsavelId;
  final DateTime createdAt;

  Lote({
    required this.id,
    required this.construtoraId,
    required this.loteamentoId,
    required this.quadraId,
    required this.name,
    required this.phase,
    required this.status,
    this.responsavelId,
    required this.createdAt,
  });

  factory Lote.fromJson(Map<String, dynamic> json) => _$LoteFromJson(json);
  Map<String, dynamic> toJson() => _$LoteToJson(this);
}
