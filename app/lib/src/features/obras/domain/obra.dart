import '../../../core/contracts.dart';

import 'package:json_annotation/json_annotation.dart';

part 'obra.g.dart';

@JsonSerializable()
class Obra {
  final String id;
  final String construtoraId;
  final String name;
  final String? description;
  final DateTime createdAt;
  final bool isActive;

  Obra({
    required this.id,
    required this.construtoraId,
    required this.name,
    this.description,
    required this.createdAt,
    this.isActive = true,
  });

  factory Obra.fromJson(Map<String, dynamic> json) =>
      _$ObraFromJson(compatibleDates(json, ['createdAt', 'updatedAt']));

  Map<String, dynamic> toJson() => _$ObraToJson(this);
}
