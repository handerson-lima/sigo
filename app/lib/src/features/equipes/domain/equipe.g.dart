// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'equipe.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EquipeLote _$EquipeLoteFromJson(Map<String, dynamic> json) => EquipeLote(
  id: json['id'] as String,
  construtoraId: json['construtoraId'] as String,
  loteamentoId: json['loteamentoId'] as String,
  quadraId: json['quadraId'] as String,
  loteId: json['loteId'] as String,
  etapaId: json['etapaId'] as String,
  name: json['name'] as String,
  responsavelId: json['responsavelId'] as String?,
  createdAt: _dateTimeFromTimestamp(json['createdAt']),
  updatedAt: _dateTimeFromTimestamp(json['updatedAt']),
);

Map<String, dynamic> _$EquipeLoteToJson(EquipeLote instance) => <String, dynamic>{
  'id': instance.id,
  'construtoraId': instance.construtoraId,
  'loteamentoId': instance.loteamentoId,
  'quadraId': instance.quadraId,
  'loteId': instance.loteId,
  'etapaId': instance.etapaId,
  'name': instance.name,
  'responsavelId': instance.responsavelId,
  'createdAt': _dateTimeToTimestamp(instance.createdAt),
  'updatedAt': _dateTimeToTimestamp(instance.updatedAt),
};
