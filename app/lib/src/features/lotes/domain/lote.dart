import 'package:json_annotation/json_annotation.dart';

import '../../../core/contracts.dart';

part 'lote.g.dart';

int _progressoFromJson(dynamic raw) {
  if (raw is num) return raw.toInt().clamp(0, 100);
  return 0;
}

int _etapasConcluidasFromJson(dynamic raw) {
  if (raw is num) return raw.toInt().clamp(0, 5);
  return 0;
}

int _etapasTotalFromJson(dynamic raw) {
  if (raw is num && raw.toInt() > 0) return raw.toInt();
  return 5;
}

const Map<String, String> defaultLoteStatusEtapasMap = {
  'muro': 'pendente',
  'cinza1': 'pendente',
  'cinza2': 'pendente',
  'cinza3': 'pendente',
  'branca': 'pendente',
};

Map<String, String> _statusEtapasMapFromJson(dynamic raw) {
  final result = Map<String, String>.from(defaultLoteStatusEtapasMap);
  if (raw is Map) {
    for (final entry in raw.entries) {
      final key = entry.key?.toString();
      final value = entry.value?.toString();
      if (key != null && value != null && value.trim().isNotEmpty) {
        result[key] = value.trim();
      }
    }
  }
  return result;
}

List<Map<String, dynamic>> _mapListFromJson(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

@JsonSerializable()
class Lote {
  static const Map<String, String> defaultStatusEtapasMap =
      defaultLoteStatusEtapasMap;

  final String id;
  final String construtoraId;
  final String loteamentoId;
  final String quadraId;
  final String name;
  final double? frenteM;
  final double? profundidadeM;
  final double? areaTerrenoM2;
  final double? areaConstruidaM2;
  final String? logradouro;
  final double? taxaOcupacaoPercent;
  final double? coeficienteAproveitamento;
  final double? areaPermeavelM2;
  final double? taxaPermeabilidadePercent;
  final double? areaImpermeavelM2;
  final double? recuoFrontalM;
  final double? recuoFundoM;
  final double? recuoLateralEsquerdoM;
  final double? recuoLateralDireitoM;
  final String? proprietarioNome;
  final String? proprietarioDocumento;
  final String? responsavelTecnicoNome;
  final String? responsavelTecnicoRegistro;
  final String? dataProjeto;
  @JsonKey(fromJson: _progressoFromJson)
  final int progressoPercentual;
  @JsonKey(fromJson: _etapasConcluidasFromJson)
  final int etapasConcluidasCount;
  @JsonKey(fromJson: _etapasTotalFromJson)
  final int etapasTotalCount;
  @JsonKey(fromJson: _statusEtapasMapFromJson)
  final Map<String, String> statusEtapasMap;
  @JsonKey(fromJson: _mapListFromJson)
  final List<Map<String, dynamic>> equipesVinculadas;
  @JsonKey(fromJson: _mapListFromJson)
  final List<Map<String, dynamic>> funcionariosVinculados;
  final DateTime createdAt;
  final DateTime updatedAt;

  Lote({
    required this.id,
    required this.construtoraId,
    required this.loteamentoId,
    required this.quadraId,
    required this.name,
    this.frenteM,
    this.profundidadeM,
    this.areaTerrenoM2,
    this.areaConstruidaM2,
    this.logradouro,
    this.taxaOcupacaoPercent,
    this.coeficienteAproveitamento,
    this.areaPermeavelM2,
    this.taxaPermeabilidadePercent,
    this.areaImpermeavelM2,
    this.recuoFrontalM,
    this.recuoFundoM,
    this.recuoLateralEsquerdoM,
    this.recuoLateralDireitoM,
    this.proprietarioNome,
    this.proprietarioDocumento,
    this.responsavelTecnicoNome,
    this.responsavelTecnicoRegistro,
    this.dataProjeto,
    this.progressoPercentual = 0,
    this.etapasConcluidasCount = 0,
    this.etapasTotalCount = 5,
    this.statusEtapasMap = defaultLoteStatusEtapasMap,
    this.equipesVinculadas = const [],
    this.funcionariosVinculados = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  static double? calcularAreaTerreno(double? frenteM, double? profundidadeM) {
    if (frenteM == null || profundidadeM == null) return null;
    if (!frenteM.isFinite || !profundidadeM.isFinite) return null;
    if (frenteM <= 0 || profundidadeM <= 0) return null;
    return double.parse((frenteM * profundidadeM).toStringAsFixed(6));
  }

  Lote copyWith({
    String? id,
    String? construtoraId,
    String? loteamentoId,
    String? quadraId,
    String? name,
    double? frenteM,
    double? profundidadeM,
    double? areaTerrenoM2,
    double? areaConstruidaM2,
    String? logradouro,
    double? taxaOcupacaoPercent,
    double? coeficienteAproveitamento,
    double? areaPermeavelM2,
    double? taxaPermeabilidadePercent,
    double? areaImpermeavelM2,
    double? recuoFrontalM,
    double? recuoFundoM,
    double? recuoLateralEsquerdoM,
    double? recuoLateralDireitoM,
    String? proprietarioNome,
    String? proprietarioDocumento,
    String? responsavelTecnicoNome,
    String? responsavelTecnicoRegistro,
    String? dataProjeto,
    int? progressoPercentual,
    int? etapasConcluidasCount,
    int? etapasTotalCount,
    Map<String, String>? statusEtapasMap,
    List<Map<String, dynamic>>? equipesVinculadas,
    List<Map<String, dynamic>>? funcionariosVinculados,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Lote(
      id: id ?? this.id,
      construtoraId: construtoraId ?? this.construtoraId,
      loteamentoId: loteamentoId ?? this.loteamentoId,
      quadraId: quadraId ?? this.quadraId,
      name: name ?? this.name,
      frenteM: frenteM ?? this.frenteM,
      profundidadeM: profundidadeM ?? this.profundidadeM,
      areaTerrenoM2: areaTerrenoM2 ?? this.areaTerrenoM2,
      areaConstruidaM2: areaConstruidaM2 ?? this.areaConstruidaM2,
      logradouro: logradouro ?? this.logradouro,
      taxaOcupacaoPercent: taxaOcupacaoPercent ?? this.taxaOcupacaoPercent,
      coeficienteAproveitamento:
          coeficienteAproveitamento ?? this.coeficienteAproveitamento,
      areaPermeavelM2: areaPermeavelM2 ?? this.areaPermeavelM2,
      taxaPermeabilidadePercent:
          taxaPermeabilidadePercent ?? this.taxaPermeabilidadePercent,
      areaImpermeavelM2: areaImpermeavelM2 ?? this.areaImpermeavelM2,
      recuoFrontalM: recuoFrontalM ?? this.recuoFrontalM,
      recuoFundoM: recuoFundoM ?? this.recuoFundoM,
      recuoLateralEsquerdoM:
          recuoLateralEsquerdoM ?? this.recuoLateralEsquerdoM,
      recuoLateralDireitoM: recuoLateralDireitoM ?? this.recuoLateralDireitoM,
      proprietarioNome: proprietarioNome ?? this.proprietarioNome,
      proprietarioDocumento:
          proprietarioDocumento ?? this.proprietarioDocumento,
      responsavelTecnicoNome:
          responsavelTecnicoNome ?? this.responsavelTecnicoNome,
      responsavelTecnicoRegistro:
          responsavelTecnicoRegistro ?? this.responsavelTecnicoRegistro,
      dataProjeto: dataProjeto ?? this.dataProjeto,
      progressoPercentual: progressoPercentual ?? this.progressoPercentual,
      etapasConcluidasCount:
          etapasConcluidasCount ?? this.etapasConcluidasCount,
      etapasTotalCount: etapasTotalCount ?? this.etapasTotalCount,
      statusEtapasMap: statusEtapasMap ?? this.statusEtapasMap,
      equipesVinculadas: equipesVinculadas ?? this.equipesVinculadas,
      funcionariosVinculados:
          funcionariosVinculados ?? this.funcionariosVinculados,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Lote.fromJson(Map<String, dynamic> json) =>
      _$LoteFromJson(compatibleDates(json, ['createdAt', 'updatedAt']));

  Map<String, dynamic> toJson() => _$LoteToJson(this);
}
