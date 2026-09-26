import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

part 'equipe.g.dart';

DateTime _dateTimeFromTimestamp(dynamic timestamp) {
  if (timestamp is Timestamp) {
    return timestamp.toDate();
  }
  if (timestamp is String) {
    return DateTime.tryParse(timestamp) ?? DateTime.now();
  }
  if (timestamp is int) {
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }
  return DateTime.now();
}

dynamic _dateTimeToTimestamp(DateTime date) => Timestamp.fromDate(date);

@JsonSerializable()
class EquipeLote {
  final String id;
  final String construtoraId;
  final String loteamentoId;
  final String quadraId;
  final String loteId;
  final String etapaId;
  final String name;
  final String? responsavelId;
  @JsonKey(fromJson: _dateTimeFromTimestamp, toJson: _dateTimeToTimestamp)
  final DateTime createdAt;
  @JsonKey(fromJson: _dateTimeFromTimestamp, toJson: _dateTimeToTimestamp)
  final DateTime updatedAt;

  EquipeLote({
    required this.id,
    required this.construtoraId,
    required this.loteamentoId,
    required this.quadraId,
    required this.loteId,
    required this.etapaId,
    required this.name,
    this.responsavelId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EquipeLote.fromJson(Map<String, dynamic> json) =>
      _$EquipeLoteFromJson(json);
  Map<String, dynamic> toJson() => _$EquipeLoteToJson(this);
}
