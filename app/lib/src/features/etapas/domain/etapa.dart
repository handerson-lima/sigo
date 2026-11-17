import 'package:json_annotation/json_annotation.dart';

import '../../../core/contracts.dart';

part 'etapa.g.dart';

enum EtapaTipo { muro, cinza1, cinza2, cinza3, branca }

class EtapaStatus {
  static const String pendente = 'pendente';
  static const String emAndamento = 'em_andamento';
  static const String concluida = 'concluida';

  static const List<String> values = [pendente, emAndamento, concluida];
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

EtapaTipo? resolveEtapaTipo({String? id, int? ordem, String? nome}) {
  if (id != null && id.trim().isNotEmpty) {
    final trimmedId = id.trim();
    for (final tipo in EtapaTipo.values) {
      if (trimmedId == tipo.name || trimmedId.endsWith('_${tipo.name}')) {
        return tipo;
      }
    }
  }

  if (ordem != null) {
    for (final tipo in EtapaTipo.values) {
      if (tipo.ordem == ordem) {
        return tipo;
      }
    }
  }

  if (nome != null && nome.trim().isNotEmpty) {
    final normalized = nome.trim().toLowerCase();
    for (final tipo in EtapaTipo.values) {
      if (normalized == tipo.name.toLowerCase() ||
          normalized == tipo.label.toLowerCase()) {
        return tipo;
      }
    }
    return switch (normalized) {
      'cinza/1a' || 'cinza 1' || 'cinza 1ª' => EtapaTipo.cinza1,
      'cinza/2a' || 'cinza 2' || 'cinza 2ª' => EtapaTipo.cinza2,
      'cinza/3a' || 'cinza 3' || 'cinza 3ª' => EtapaTipo.cinza3,
      'branca' || 'acabamento' => EtapaTipo.branca,
      _ => null,
    };
  }

  return null;
}

String _etapaStatusFromJson(dynamic raw) {
  if (raw is String && raw.trim().isNotEmpty) {
    return raw.trim();
  }
  return EtapaStatus.pendente;
}

int _etapaPercentualFromJson(dynamic raw) {
  if (raw is num) return raw.toInt().clamp(0, 100);
  return 0;
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
  final String? responsavelId;
  @JsonKey(fromJson: _etapaStatusFromJson)
  final String status;
  @JsonKey(fromJson: _etapaPercentualFromJson)
  final int percentual;
  final String? equipeId;
  final String? equipeNome;
  final String? funcionarioId;
  final String? funcionarioNome;
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
    this.responsavelId,
    this.status = EtapaStatus.pendente,
    this.percentual = 0,
    this.equipeId,
    this.equipeNome,
    this.funcionarioId,
    this.funcionarioNome,
    required this.createdAt,
    required this.updatedAt,
  });

  EtapaTipo? get tipo => resolveEtapaTipo(id: id, ordem: ordem, nome: nome);

  Etapa copyWith({
    String? id,
    String? construtoraId,
    String? loteamentoId,
    String? quadraId,
    String? loteId,
    String? nome,
    int? ordem,
    String? responsavelId,
    bool clearResponsavelId = false,
    String? status,
    int? percentual,
    String? equipeId,
    String? equipeNome,
    bool clearEquipe = false,
    String? funcionarioId,
    String? funcionarioNome,
    bool clearFuncionario = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Etapa(
      id: id ?? this.id,
      construtoraId: construtoraId ?? this.construtoraId,
      loteamentoId: loteamentoId ?? this.loteamentoId,
      quadraId: quadraId ?? this.quadraId,
      loteId: loteId ?? this.loteId,
      nome: nome ?? this.nome,
      ordem: ordem ?? this.ordem,
      responsavelId: clearResponsavelId
          ? null
          : (responsavelId ?? this.responsavelId),
      status: status ?? this.status,
      percentual: percentual ?? this.percentual,
      equipeId: clearEquipe ? null : (equipeId ?? this.equipeId),
      equipeNome: clearEquipe ? null : (equipeNome ?? this.equipeNome),
      funcionarioId: clearFuncionario
          ? null
          : (funcionarioId ?? this.funcionarioId),
      funcionarioNome: clearFuncionario
          ? null
          : (funcionarioNome ?? this.funcionarioNome),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Etapa.fromJson(Map<String, dynamic> json) =>
      _$EtapaFromJson(compatibleDates(json, ['createdAt', 'updatedAt']));

  Map<String, dynamic> toJson() => _$EtapaToJson(this);
}
