// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'construtora.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Construtora _$ConstrutoraFromJson(Map<String, dynamic> json) => Construtora(
  id: json['id'] as String,
  name: json['name'] as String,
  cnpj: json['cnpj'] as String?,
  telefone: json['telefone'] as String?,
  logoUrl: json['logoUrl'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  isActive: json['isActive'] as bool? ?? true,
);

Map<String, dynamic> _$ConstrutoraToJson(Construtora instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'cnpj': instance.cnpj,
      'telefone': instance.telefone,
      'logoUrl': instance.logoUrl,
      'createdAt': instance.createdAt.toIso8601String(),
      'isActive': instance.isActive,
    };
