import 'package:json_annotation/json_annotation.dart';

part 'loteamento.g.dart';

@JsonSerializable()
class Loteamento {
  final String id;
  final String construtoraId;
  final String name;
  final DateTime createdAt;

  Loteamento({
    required this.id,
    required this.construtoraId,
    required this.name,
    required this.createdAt,
  });

  factory Loteamento.fromJson(Map<String, dynamic> json) => _$LoteamentoFromJson(json);
  Map<String, dynamic> toJson() => _$LoteamentoToJson(this);
}
