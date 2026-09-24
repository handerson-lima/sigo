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
  phase: json['phase'] as String,
  status: $enumDecode(_$LoteStatusEnumMap, json['status']),
  responsavelId: json['responsavelId'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$LoteToJson(Lote instance) => <String, dynamic>{
  'id': instance.id,
  'construtoraId': instance.construtoraId,
  'loteamentoId': instance.loteamentoId,
  'quadraId': instance.quadraId,
  'name': instance.name,
  'phase': instance.phase,
  'status': _$LoteStatusEnumMap[instance.status]!,
  'responsavelId': instance.responsavelId,
  'createdAt': instance.createdAt.toIso8601String(),
};

const _$LoteStatusEnumMap = {
  LoteStatus.noPrazo: 'noPrazo',
  LoteStatus.atrasado: 'atrasado',
  LoteStatus.paralisado: 'paralisado',
  LoteStatus.concluido: 'concluido',
};
