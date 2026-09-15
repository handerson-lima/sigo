// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'obra_member.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ObraMember _$ObraMemberFromJson(Map<String, dynamic> json) => ObraMember(
  userId: json['userId'] as String,
  isAdmin: json['isAdmin'] as bool? ?? false,
  modules:
      (json['modules'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  joinedAt: DateTime.parse(json['joinedAt'] as String),
  isActive: json['isActive'] as bool? ?? false,
);

Map<String, dynamic> _$ObraMemberToJson(ObraMember instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'isAdmin': instance.isAdmin,
      'modules': instance.modules,
      'joinedAt': instance.joinedAt.toIso8601String(),
      'isActive': instance.isActive,
    };
