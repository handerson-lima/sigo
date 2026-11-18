import 'package:json_annotation/json_annotation.dart';

import '../../../core/contracts.dart';

part 'quadra.g.dart';

@JsonSerializable()
class Quadra {
  final String id;
  final String construtoraId;
  final String loteamentoId;
  final String name;
  final String? logradouroPadrao;
  final DateTime createdAt;
  final DateTime updatedAt;

  Quadra({
    required this.id,
    required this.construtoraId,
    required this.loteamentoId,
    required this.name,
    this.logradouroPadrao,
    required this.createdAt,
    required this.updatedAt,
  });

  Quadra copyWith({
    String? id,
    String? construtoraId,
    String? loteamentoId,
    String? name,
    String? logradouroPadrao,
    bool clearLogradouroPadrao = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Quadra(
      id: id ?? this.id,
      construtoraId: construtoraId ?? this.construtoraId,
      loteamentoId: loteamentoId ?? this.loteamentoId,
      name: name ?? this.name,
      logradouroPadrao: clearLogradouroPadrao
          ? null
          : (logradouroPadrao ?? this.logradouroPadrao),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Quadra.fromJson(Map<String, dynamic> json) =>
      _$QuadraFromJson(compatibleDates(json, ['createdAt', 'updatedAt']));

  Map<String, dynamic> toJson() => _$QuadraToJson(this);
}
