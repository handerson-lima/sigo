import 'package:json_annotation/json_annotation.dart';

part 'lote.g.dart';

@JsonSerializable()
class Lote {
  final String id;
  final String construtoraId;
  final String loteamentoId;
  final String quadraId;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;

  Lote({
    required this.id,
    required this.construtoraId,
    required this.loteamentoId,
    required this.quadraId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Lote.fromJson(Map<String, dynamic> json) => _$LoteFromJson(json);
  Map<String, dynamic> toJson() => _$LoteToJson(this);
}
