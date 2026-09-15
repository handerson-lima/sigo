// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'construtora_member.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConstrutoraMember _$ConstrutoraMemberFromJson(Map<String, dynamic> json) =>
    ConstrutoraMember(
      userId: json['userId'] as String,
      modules:
          (json['modules'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      isOwner: json['isOwner'] as bool? ?? false,
      isAdmin: json['isAdmin'] as bool? ?? false,
      joinedAt: DateTime.parse(json['joinedAt'] as String),
      isActive: json['isActive'] as bool? ?? false,
    );

Map<String, dynamic> _$ConstrutoraMemberToJson(ConstrutoraMember instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'modules': instance.modules,
      'isOwner': instance.isOwner,
      'isAdmin': instance.isAdmin,
      'joinedAt': instance.joinedAt.toIso8601String(),
      'isActive': instance.isActive,
    };
