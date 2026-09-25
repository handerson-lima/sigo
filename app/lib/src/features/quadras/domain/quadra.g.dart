// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quadra.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Quadra _$QuadraFromJson(Map<String, dynamic> json) => Quadra(
  id: json['id'] as String,
  construtoraId: json['construtoraId'] as String,
  loteamentoId: json['loteamentoId'] as String,
  name: json['name'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$QuadraToJson(Quadra instance) => <String, dynamic>{
  'id': instance.id,
  'construtoraId': instance.construtoraId,
  'loteamentoId': instance.loteamentoId,
  'name': instance.name,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};
