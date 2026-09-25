import '../../../core/contracts.dart';

import 'package:json_annotation/json_annotation.dart';

part 'construtora_member.g.dart';

@JsonSerializable()
class ConstrutoraMember {
  final String userId;
  final bool isOwner; // Dono/Sócio da construtora
  final bool isAdmin; // Admin geral (Rh, TI, etc)
  final DateTime joinedAt;
  final bool isActive;
  final List<String> modules;

  ConstrutoraMember({
    required this.userId,
    this.isOwner = false,
    this.isAdmin = false,
    required this.joinedAt,
    this.isActive = false,
    this.modules = const [],
  });

  factory ConstrutoraMember.fromJson(Map<String, dynamic> json) {
    final compat = Map<String, dynamic>.from(
      compatibleDates(json, ['joinedAt']),
    );
    if ((compat['role'] == 'admin' || compat['role'] == 'owner') &&
        compat['isAdmin'] != true) {
      compat['isAdmin'] = true;
    }
    if (compat['role'] == 'owner' && compat['isOwner'] != true) {
      compat['isOwner'] = true;
    }
    return _$ConstrutoraMemberFromJson(compat);
  }

  Map<String, dynamic> toJson() => _$ConstrutoraMemberToJson(this);
}
