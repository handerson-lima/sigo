import 'package:json_annotation/json_annotation.dart';

part 'material.g.dart';

@JsonSerializable()
class Material {
  final String id;
  final String construtoraId;
  final String name;
  final String unit; // ex: Saco, Metro, Unidade
  final double currentQuantity;
  final int? quantityUnits;

  Material({
    required this.id,
    required this.construtoraId,
    required this.name,
    required this.unit,
    this.currentQuantity = 0.0,
    this.quantityUnits = 0,
  });

  factory Material.fromJson(Map<String, dynamic> json) {
    final legacy = _$MaterialFromJson(json);
    return Material(
      id: legacy.id,
      construtoraId: legacy.construtoraId,
      name: legacy.name,
      unit: legacy.unit,
      quantityUnits: json['quantityUnits'] as int?,
      currentQuantity: json['quantityUnits'] != null
          ? (json['quantityUnits'] as int) / (json['quantityScale'] as int)
          : legacy.currentQuantity,
    );
  }
  Map<String, dynamic> toJson() => {
    ..._$MaterialToJson(this),
    if (quantityUnits != null) ...{
      'quantityUnits': quantityUnits,
      'quantityScale': 1000,
      'schemaVersion': 2,
    },
  };
}
