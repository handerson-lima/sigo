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
  frenteM: (json['frenteM'] as num?)?.toDouble(),
  profundidadeM: (json['profundidadeM'] as num?)?.toDouble(),
  areaTerrenoM2: (json['areaTerrenoM2'] as num?)?.toDouble(),
  areaConstruidaM2: (json['areaConstruidaM2'] as num?)?.toDouble(),
  logradouro: json['logradouro'] as String?,
  taxaOcupacaoPercent: (json['taxaOcupacaoPercent'] as num?)?.toDouble(),
  coeficienteAproveitamento: (json['coeficienteAproveitamento'] as num?)
      ?.toDouble(),
  areaPermeavelM2: (json['areaPermeavelM2'] as num?)?.toDouble(),
  taxaPermeabilidadePercent: (json['taxaPermeabilidadePercent'] as num?)
      ?.toDouble(),
  areaImpermeavelM2: (json['areaImpermeavelM2'] as num?)?.toDouble(),
  recuoFrontalM: (json['recuoFrontalM'] as num?)?.toDouble(),
  recuoFundoM: (json['recuoFundoM'] as num?)?.toDouble(),
  recuoLateralEsquerdoM: (json['recuoLateralEsquerdoM'] as num?)?.toDouble(),
  recuoLateralDireitoM: (json['recuoLateralDireitoM'] as num?)?.toDouble(),
  proprietarioNome: json['proprietarioNome'] as String?,
  proprietarioDocumento: json['proprietarioDocumento'] as String?,
  responsavelTecnicoNome: json['responsavelTecnicoNome'] as String?,
  responsavelTecnicoRegistro: json['responsavelTecnicoRegistro'] as String?,
  dataProjeto: json['dataProjeto'] as String?,
  progressoPercentual: json['progressoPercentual'] == null
      ? 0
      : _progressoFromJson(json['progressoPercentual']),
  etapasConcluidasCount: json['etapasConcluidasCount'] == null
      ? 0
      : _etapasConcluidasFromJson(json['etapasConcluidasCount']),
  etapasTotalCount: json['etapasTotalCount'] == null
      ? 5
      : _etapasTotalFromJson(json['etapasTotalCount']),
  statusEtapasMap: json['statusEtapasMap'] == null
      ? defaultLoteStatusEtapasMap
      : _statusEtapasMapFromJson(json['statusEtapasMap']),
  equipesVinculadas: json['equipesVinculadas'] == null
      ? const []
      : _mapListFromJson(json['equipesVinculadas']),
  funcionariosVinculados: json['funcionariosVinculados'] == null
      ? const []
      : _mapListFromJson(json['funcionariosVinculados']),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$LoteToJson(Lote instance) => <String, dynamic>{
  'id': instance.id,
  'construtoraId': instance.construtoraId,
  'loteamentoId': instance.loteamentoId,
  'quadraId': instance.quadraId,
  'name': instance.name,
  'frenteM': instance.frenteM,
  'profundidadeM': instance.profundidadeM,
  'areaTerrenoM2': instance.areaTerrenoM2,
  'areaConstruidaM2': instance.areaConstruidaM2,
  'logradouro': instance.logradouro,
  'taxaOcupacaoPercent': instance.taxaOcupacaoPercent,
  'coeficienteAproveitamento': instance.coeficienteAproveitamento,
  'areaPermeavelM2': instance.areaPermeavelM2,
  'taxaPermeabilidadePercent': instance.taxaPermeabilidadePercent,
  'areaImpermeavelM2': instance.areaImpermeavelM2,
  'recuoFrontalM': instance.recuoFrontalM,
  'recuoFundoM': instance.recuoFundoM,
  'recuoLateralEsquerdoM': instance.recuoLateralEsquerdoM,
  'recuoLateralDireitoM': instance.recuoLateralDireitoM,
  'proprietarioNome': instance.proprietarioNome,
  'proprietarioDocumento': instance.proprietarioDocumento,
  'responsavelTecnicoNome': instance.responsavelTecnicoNome,
  'responsavelTecnicoRegistro': instance.responsavelTecnicoRegistro,
  'dataProjeto': instance.dataProjeto,
  'progressoPercentual': instance.progressoPercentual,
  'etapasConcluidasCount': instance.etapasConcluidasCount,
  'etapasTotalCount': instance.etapasTotalCount,
  'statusEtapasMap': instance.statusEtapasMap,
  'equipesVinculadas': instance.equipesVinculadas,
  'funcionariosVinculados': instance.funcionariosVinculados,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};
