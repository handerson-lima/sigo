import 'package:json_annotation/json_annotation.dart';

part 'quadra.g.dart';

@JsonSerializable()
class Quadra {
  final String id;
  final String construtoraId;
  final String loteamentoId;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;

  Quadra({
    required this.id,
    required this.construtoraId,
    required this.loteamentoId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Quadra.fromJson(Map<String, dynamic> json) => _$QuadraFromJson(json);
  Map<String, dynamic> toJson() => _$QuadraToJson(this);
}
