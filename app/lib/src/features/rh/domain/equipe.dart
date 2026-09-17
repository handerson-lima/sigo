import 'package:cloud_firestore/cloud_firestore.dart';

class Equipe {
  final String id;
  final String construtoraId;
  final String name;
  final String? leaderId;
  final String? leaderName;
  final bool isActive;
  final int schemaVersion;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Equipe({
    required this.id,
    required this.construtoraId,
    required this.name,
    this.leaderId,
    this.leaderName,
    this.isActive = true,
    this.schemaVersion = 1,
    this.createdAt,
    this.updatedAt,
  });

  Equipe copyWith({
    String? id,
    String? construtoraId,
    String? name,
    String? leaderId,
    String? leaderName,
    bool clearLeader = false,
    bool? isActive,
    int? schemaVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Equipe(
      id: id ?? this.id,
      construtoraId: construtoraId ?? this.construtoraId,
      name: name ?? this.name,
      leaderId: clearLeader ? null : (leaderId ?? this.leaderId),
      leaderName: clearLeader ? null : (leaderName ?? this.leaderName),
      isActive: isActive ?? this.isActive,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Equipe.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String && val.isNotEmpty) return DateTime.tryParse(val);
      return null;
    }

    return Equipe(
      id: json['id'] as String? ?? '',
      construtoraId: json['construtoraId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      leaderId: json['leaderId'] as String?,
      leaderName: json['leaderName'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'construtoraId': construtoraId,
      'name': name,
      'leaderId': leaderId,
      'leaderName': leaderName,
      'isActive': isActive,
      'schemaVersion': schemaVersion,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}
