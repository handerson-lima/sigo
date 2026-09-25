// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lote.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Lote _$LoteFromJson(Map<String, dynamic> json) => Lote(
  id: json['id'] as String,
  construtoraId: json['construtoraId'] as String,
  loteamentoId: json['loteamentoId'] as String,
  quadraId: json['quadraId'] as String,
  name: json['name'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$LoteToJson(Lote instance) => <String, dynamic>{
  'id': instance.id,
  'construtoraId': instance.construtoraId,
  'loteamentoId': instance.loteamentoId,
  'quadraId': instance.quadraId,
  'name': instance.name,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};
