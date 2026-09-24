// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'equipe.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Equipe _$EquipeFromJson(Map<String, dynamic> json) => Equipe(
  id: json['id'] as String,
  construtoraId: json['construtoraId'] as String,
  loteamentoId: json['loteamentoId'] as String,
  quadraId: json['quadraId'] as String,
  loteId: json['loteId'] as String,
  setorId: json['setorId'] as String,
  name: json['name'] as String,
  responsavelId: json['responsavelId'] as String?,
  createdAt: _dateTimeFromTimestamp(json['createdAt']),
);

Map<String, dynamic> _$EquipeToJson(Equipe instance) => <String, dynamic>{
  'id': instance.id,
  'construtoraId': instance.construtoraId,
  'loteamentoId': instance.loteamentoId,
  'quadraId': instance.quadraId,
  'loteId': instance.loteId,
  'setorId': instance.setorId,
  'name': instance.name,
  'responsavelId': instance.responsavelId,
  'createdAt': _dateTimeToTimestamp(instance.createdAt),
};
