// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diario.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EfetivoEntry _$EfetivoEntryFromJson(Map<String, dynamic> json) => EfetivoEntry(
  role: json['role'] as String,
  count: (json['count'] as num).toInt(),
);

Map<String, dynamic> _$EfetivoEntryToJson(EfetivoEntry instance) =>
    <String, dynamic>{'role': instance.role, 'count': instance.count};

DiarioObra _$DiarioObraFromJson(Map<String, dynamic> json) => DiarioObra(
  id: json['id'] as String,
  construtoraId: json['construtoraId'] as String,
  obraId: json['obraId'] as String,
  date: DateTime.parse(json['date'] as String),
  weather: $enumDecode(_$WeatherConditionEnumMap, json['weather']),
  efetivo:
      (json['efetivo'] as List<dynamic>?)
          ?.map((e) => EfetivoEntry.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  observacoes: json['observacoes'] as String? ?? '',
  photoUrls:
      (json['photoUrls'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  localPhotoPaths:
      (json['localPhotoPaths'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  isPendingSync: json['isPendingSync'] as bool? ?? false,
  responsavelId: json['responsavelId'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$DiarioObraToJson(DiarioObra instance) =>
    <String, dynamic>{
      'id': instance.id,
      'construtoraId': instance.construtoraId,
      'obraId': instance.obraId,
      'date': instance.date.toIso8601String(),
      'weather': _$WeatherConditionEnumMap[instance.weather]!,
      'efetivo': instance.efetivo,
      'observacoes': instance.observacoes,
      'photoUrls': instance.photoUrls,
      'localPhotoPaths': instance.localPhotoPaths,
      'isPendingSync': instance.isPendingSync,
      'responsavelId': instance.responsavelId,
      'createdAt': instance.createdAt.toIso8601String(),
    };

const _$WeatherConditionEnumMap = {
  WeatherCondition.sol: 'sol',
  WeatherCondition.nublado: 'nublado',
  WeatherCondition.chuvaLeve: 'chuvaLeve',
  WeatherCondition.chuvaIntensa: 'chuvaIntensa',
};
