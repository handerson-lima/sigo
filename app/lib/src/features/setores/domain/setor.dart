import 'package:json_annotation/json_annotation.dart';

part 'setor.g.dart';

@JsonSerializable()
class Setor {
  final String id;
  final String construtoraId;
  final String loteamentoId;
  final String quadraId;
  final String loteId;
  final String name;
  final DateTime createdAt;

  Setor({
    required this.id,
    required this.construtoraId,
    required this.loteamentoId,
    required this.quadraId,
    required this.loteId,
    required this.name,
    required this.createdAt,
  });

  factory Setor.fromJson(Map<String, dynamic> json) => _$SetorFromJson(json);
  Map<String, dynamic> toJson() => _$SetorToJson(this);
}
