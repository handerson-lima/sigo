import '../../../core/contracts.dart';

import 'package:json_annotation/json_annotation.dart';

part 'obra_member.g.dart';

@JsonSerializable()
class ObraMember {
  final String userId;
  final bool isAdmin;
  final List<String> modules;
  final DateTime joinedAt;
  final bool isActive;

  ObraMember({
    required this.userId,
    this.isAdmin = false,
    this.modules = const [],
    required this.joinedAt,
    this.isActive = false,
  });

  factory ObraMember.fromJson(Map<String, dynamic> json) =>
      _$ObraMemberFromJson(compatibleDates(json, ['joinedAt']));

  Map<String, dynamic> toJson() => _$ObraMemberToJson(this);
}
