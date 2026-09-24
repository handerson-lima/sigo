import 'package:json_annotation/json_annotation.dart';

part 'equipe.g.dart';

@JsonSerializable()
class Equipe {
  final String id;
  final String construtoraId;
  final String loteamentoId;
  final String quadraId;
  final String loteId;
  final String setorId;
  final String name;
  final DateTime createdAt;

  Equipe({
    required this.id,
    required this.construtoraId,
    required this.loteamentoId,
    required this.quadraId,
    required this.loteId,
    required this.setorId,
    required this.name,
    required this.createdAt,
  });

  factory Equipe.fromJson(Map<String, dynamic> json) => _$EquipeFromJson(json);
  Map<String, dynamic> toJson() => _$EquipeToJson(this);
}
