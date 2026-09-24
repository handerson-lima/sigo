import 'dart:io';

void main() async {
  // Fix Setor Domain
  final setorFile = File('app/lib/src/features/setores/domain/setor.dart');
  await setorFile.writeAsString('''import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

part 'setor.g.dart';

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
class Setor {
  final String id;
  final String construtoraId;
  final String loteamentoId;
  final String quadraId;
  final String loteId;
  final String name;
  final String? responsavelId;
  @JsonKey(fromJson: _dateTimeFromTimestamp, toJson: _dateTimeToTimestamp)
  final DateTime createdAt;

  Setor({
    required this.id,
    required this.construtoraId,
    required this.loteamentoId,
    required this.quadraId,
    required this.loteId,
    required this.name,
    this.responsavelId,
    required this.createdAt,
  });

  factory Setor.fromJson(Map<String, dynamic> json) => _\$SetorFromJson(json);
  Map<String, dynamic> toJson() => _\$SetorToJson(this);
}
''');

  // Fix Equipe Domain
  final equipeFile = File('app/lib/src/features/equipes/domain/equipe.dart');
  await equipeFile.writeAsString('''import 'package:cloud_firestore/cloud_firestore.dart';
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
class Equipe {
  final String id;
  final String construtoraId;
  final String loteamentoId;
  final String quadraId;
  final String loteId;
  final String setorId;
  final String name;
  final String? responsavelId;
  @JsonKey(fromJson: _dateTimeFromTimestamp, toJson: _dateTimeToTimestamp)
  final DateTime createdAt;

  Equipe({
    required this.id,
    required this.construtoraId,
    required this.loteamentoId,
    required this.quadraId,
    required this.loteId,
    required this.setorId,
    required this.name,
    this.responsavelId,
    required this.createdAt,
  });

  factory Equipe.fromJson(Map<String, dynamic> json) => _\$EquipeFromJson(json);
  Map<String, dynamic> toJson() => _\$EquipeToJson(this);
}
''');

  // Fix Setor Repository
  final setorRepoFile = File('app/lib/src/features/setores/data/setor_repository.dart');
  var srContent = await setorRepoFile.readAsString();
  srContent = srContent.replaceAll('snapshot.data()!', 'snapshot.data() ?? {}');
  srContent = srContent.replaceAll('.snapshots()', '.orderBy(\'name\').snapshots()');
  await setorRepoFile.writeAsString(srContent);

  // Fix Equipe Repository
  final equipeRepoFile = File('app/lib/src/features/equipes/data/equipe_repository.dart');
  var erContent = await equipeRepoFile.readAsString();
  erContent = erContent.replaceAll('snapshot.data()!', 'snapshot.data() ?? {}');
  erContent = erContent.replaceAll('.snapshots()', '.orderBy(\'name\').snapshots()');
  await equipeRepoFile.writeAsString(erContent);
}
