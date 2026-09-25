import '../../../core/contracts.dart';

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
  final int? quantityScale;
  final int? schemaVersion;

  Material({
    required this.id,
    required this.construtoraId,
    required this.name,
    required this.unit,
    this.currentQuantity = 0.0,
    this.quantityUnits,
    this.quantityScale = 1000,
    this.schemaVersion = 2,
  });

  int get effectiveQuantityScale => quantityScale ?? 1000;

  double get displayQuantity => quantityUnits != null
      ? quantityUnits! / effectiveQuantityScale
      : currentQuantity;

  String get formattedBalance =>
      formatQuantityWithScale(displayQuantity, scale: effectiveQuantityScale);

  factory Material.fromJson(Map<String, dynamic> json) {
    final legacy = _$MaterialFromJson(json);
    final scale = (json['quantityScale'] as num?)?.toInt() ?? 1000;
    final units = (json['quantityUnits'] as num?)?.toInt();
    final schema = (json['schemaVersion'] as num?)?.toInt() ?? 2;
    return Material(
      id: legacy.id,
      construtoraId: legacy.construtoraId,
      name: legacy.name,
      unit: legacy.unit,
      quantityUnits: units,
      quantityScale: scale,
      schemaVersion: schema,
      currentQuantity: units != null ? units / scale : legacy.currentQuantity,
    );
  }
  Map<String, dynamic> toJson() => {
    ..._$MaterialToJson(this),
    if (quantityUnits != null) 'quantityUnits': quantityUnits,
    'quantityScale': effectiveQuantityScale,
    if (schemaVersion != null) 'schemaVersion': schemaVersion,
  };
}
