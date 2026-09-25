import 'package:json_annotation/json_annotation.dart';

part 'etapa.g.dart';

enum EtapaTipo {
  muro,
  cinza1,
  cinza2,
  cinza3,
  branca,
}

extension EtapaTipoLabel on EtapaTipo {
  String get label => switch (this) {
    EtapaTipo.muro => 'Muro',
    EtapaTipo.cinza1 => 'Cinza/1ª',
    EtapaTipo.cinza2 => 'Cinza/2ª',
    EtapaTipo.cinza3 => 'Cinza/3ª',
    EtapaTipo.branca => 'Branca/Acabamento',
  };

  int get ordem => switch (this) {
    EtapaTipo.muro => 1,
    EtapaTipo.cinza1 => 2,
    EtapaTipo.cinza2 => 3,
    EtapaTipo.cinza3 => 4,
    EtapaTipo.branca => 5,
  };
}

@JsonSerializable()
class Etapa {
  final String id;
  final String construtoraId;
  final String loteamentoId;
  final String quadraId;
  final String loteId;
  final String nome;
  final int ordem;
  final DateTime createdAt;
  final DateTime updatedAt;

  Etapa({
    required this.id,
    required this.construtoraId,
    required this.loteamentoId,
    required this.quadraId,
    required this.loteId,
    required this.nome,
    required this.ordem,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Etapa.fromJson(Map<String, dynamic> json) => _$EtapaFromJson(json);
  Map<String, dynamic> toJson() => _$EtapaToJson(this);
}