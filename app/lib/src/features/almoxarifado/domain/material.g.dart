// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'material.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Material _$MaterialFromJson(Map<String, dynamic> json) => Material(
  id: json['id'] as String,
  construtoraId: json['construtoraId'] as String,
  name: json['name'] as String,
  unit: json['unit'] as String,
  currentQuantity: (json['currentQuantity'] as num?)?.toDouble() ?? 0.0,
  quantityUnits: (json['quantityUnits'] as num?)?.toInt(),
  quantityScale: (json['quantityScale'] as num?)?.toInt() ?? 1000,
  schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 2,
);

Map<String, dynamic> _$MaterialToJson(Material instance) => <String, dynamic>{
  'id': instance.id,
  'construtoraId': instance.construtoraId,
  'name': instance.name,
  'unit': instance.unit,
  'currentQuantity': instance.currentQuantity,
  'quantityUnits': instance.quantityUnits,
  'quantityScale': instance.quantityScale,
  'schemaVersion': instance.schemaVersion,
};
