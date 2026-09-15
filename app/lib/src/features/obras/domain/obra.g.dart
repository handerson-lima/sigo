// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'obra.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Obra _$ObraFromJson(Map<String, dynamic> json) => Obra(
  id: json['id'] as String,
  construtoraId: json['construtoraId'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  isActive: json['isActive'] as bool? ?? true,
);

Map<String, dynamic> _$ObraToJson(Obra instance) => <String, dynamic>{
  'id': instance.id,
  'construtoraId': instance.construtoraId,
  'name': instance.name,
  'description': instance.description,
  'createdAt': instance.createdAt.toIso8601String(),
  'isActive': instance.isActive,
};
