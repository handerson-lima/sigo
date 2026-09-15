import '../../../core/contracts.dart';

import 'package:json_annotation/json_annotation.dart';

part 'diario.g.dart';

enum WeatherCondition { sol, nublado, chuvaLeve, chuvaIntensa }

@JsonSerializable()
class EfetivoEntry {
  final String role; // e.g., 'Pedreiro', 'Servente'
  final int count;

  EfetivoEntry({required this.role, required this.count});

  factory EfetivoEntry.fromJson(Map<String, dynamic> json) =>
      _$EfetivoEntryFromJson(compatibleDates(json, ['date', 'createdAt']));
  Map<String, dynamic> toJson() => _$EfetivoEntryToJson(this);
}

@JsonSerializable()
class DiarioObra {
  final String id;
  final String construtoraId;
  final String obraId;
  final DateTime date;
  final WeatherCondition weather;
  final List<EfetivoEntry> efetivo;
  final String observacoes;
  final List<String> photoUrls;
  final List<String> localPhotoPaths;
  final bool isPendingSync;
  final String responsavelId;
  final DateTime createdAt;

  DiarioObra({
    required this.id,
    required this.construtoraId,
    required this.obraId,
    required this.date,
    required this.weather,
    this.efetivo = const [],
    this.observacoes = '',
    this.photoUrls = const [],
    this.localPhotoPaths = const [],
    this.isPendingSync = false,
    required this.responsavelId,
    required this.createdAt,
  });

  factory DiarioObra.fromJson(Map<String, dynamic> json) =>
      _$DiarioObraFromJson(compatibleDates(json, ['date', 'createdAt']));
  Map<String, dynamic> toJson() => _$DiarioObraToJson(this);
}
