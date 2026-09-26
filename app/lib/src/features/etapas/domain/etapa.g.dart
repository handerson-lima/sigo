// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'etapa.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Etapa _$EtapaFromJson(Map<String, dynamic> json) => Etapa(
  id: json['id'] as String,
  construtoraId: json['construtoraId'] as String,
  loteamentoId: json['loteamentoId'] as String,
  quadraId: json['quadraId'] as String,
  loteId: json['loteId'] as String,
  nome: json['nome'] as String,
  ordem: (json['ordem'] as num).toInt(),
  responsavelId: json['responsavelId'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$EtapaToJson(Etapa instance) => <String, dynamic>{
  'id': instance.id,
  'construtoraId': instance.construtoraId,
  'loteamentoId': instance.loteamentoId,
  'quadraId': instance.quadraId,
  'loteId': instance.loteId,
  'nome': instance.nome,
  'ordem': instance.ordem,
  'responsavelId': instance.responsavelId,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};
