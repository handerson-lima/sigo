import '../../../core/contracts.dart';

import 'package:json_annotation/json_annotation.dart';

part 'construtora.g.dart';

@JsonSerializable()
class Construtora {
  final String id;
  final String name;
  final String? cnpj;
  final String? telefone;
  final String? logoUrl;
  final DateTime createdAt;
  final bool isActive;

  Construtora({
    required this.id,
    required this.name,
    this.cnpj,
    this.telefone,
    this.logoUrl,
    required this.createdAt,
    this.isActive = true,
  });

  factory Construtora.fromJson(Map<String, dynamic> json) {
    final copy = Map<String, dynamic>.from(json);
    copy['id'] = copy['id'] ?? '';
    copy['name'] =
        copy['name'] ??
        (copy['id'] != null && (copy['id'] as String).isNotEmpty
            ? copy['id']
            : 'Sem nome');
    copy['createdAt'] = copy['createdAt'] != null
        ? readDate(copy['createdAt']).toIso8601String()
        : DateTime.fromMillisecondsSinceEpoch(0).toIso8601String();
    return _$ConstrutoraFromJson(
      compatibleDates(copy, ['createdAt', 'updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => _$ConstrutoraToJson(this);
}
