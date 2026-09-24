// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'setor.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Setor _$SetorFromJson(Map<String, dynamic> json) => Setor(
  id: json['id'] as String,
  construtoraId: json['construtoraId'] as String,
  loteamentoId: json['loteamentoId'] as String,
  quadraId: json['quadraId'] as String,
  loteId: json['loteId'] as String,
  name: json['name'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$SetorToJson(Setor instance) => <String, dynamic>{
  'id': instance.id,
  'construtoraId': instance.construtoraId,
  'loteamentoId': instance.loteamentoId,
  'quadraId': instance.quadraId,
  'loteId': instance.loteId,
  'name': instance.name,
  'createdAt': instance.createdAt.toIso8601String(),
};
