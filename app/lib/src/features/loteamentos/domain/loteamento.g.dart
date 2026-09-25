// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'loteamento.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Loteamento _$LoteamentoFromJson(Map<String, dynamic> json) => Loteamento(
  id: json['id'] as String,
  construtoraId: json['construtoraId'] as String,
  name: json['name'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$LoteamentoToJson(Loteamento instance) =>
    <String, dynamic>{
      'id': instance.id,
      'construtoraId': instance.construtoraId,
      'name': instance.name,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
