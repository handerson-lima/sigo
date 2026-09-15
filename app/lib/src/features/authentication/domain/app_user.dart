import '../../../core/contracts.dart';

import 'package:json_annotation/json_annotation.dart';

part 'app_user.g.dart';

@JsonSerializable()
class AppUser {
  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String? globalRole;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.globalRole,
    this.createdAt,
    this.updatedAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) =>
      _$AppUserFromJson(compatibleDates(json, ['createdAt', 'updatedAt']));

  Map<String, dynamic> toJson() => _$AppUserToJson(this);
}
