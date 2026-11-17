// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'loteamento.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Loteamento _$LoteamentoFromJson(Map<String, dynamic> json) => Loteamento(
  id: json['id'] as String,
  construtoraId: json['construtoraId'] as String,
  name: json['name'] as String,
  bairro: json['bairro'] as String?,
  cidade: json['cidade'] as String?,
  uf: json['uf'] as String?,
  proprietarioNome: json['proprietarioNome'] as String?,
  proprietarioDocumento: json['proprietarioDocumento'] as String?,
  responsavelTecnicoNome: json['responsavelTecnicoNome'] as String?,
  responsavelTecnicoRegistro: json['responsavelTecnicoRegistro'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$LoteamentoToJson(Loteamento instance) =>
    <String, dynamic>{
      'id': instance.id,
      'construtoraId': instance.construtoraId,
      'name': instance.name,
      'bairro': instance.bairro,
      'cidade': instance.cidade,
      'uf': instance.uf,
      'proprietarioNome': instance.proprietarioNome,
      'proprietarioDocumento': instance.proprietarioDocumento,
      'responsavelTecnicoNome': instance.responsavelTecnicoNome,
      'responsavelTecnicoRegistro': instance.responsavelTecnicoRegistro,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
