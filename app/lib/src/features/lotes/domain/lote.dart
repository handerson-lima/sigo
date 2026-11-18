import 'package:json_annotation/json_annotation.dart';

import '../../../core/contracts.dart';
import '../../etapas/domain/etapa.dart';

part 'lote.g.dart';

int _progressoFromJson(dynamic raw) {
  if (raw is num && raw.isFinite) return raw.round().clamp(0, 100);
  return 0;
}

int _etapasConcluidasFromJson(dynamic raw) {
  if (raw is num && raw.isFinite) return raw.round().clamp(0, 5);
  return 0;
}

int _etapasTotalFromJson(dynamic raw) {
  if (raw is num && raw.isFinite) {
    final total = raw.round();
    if (total > 0) return total;
  }
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
      final key = entry.key?.toString().trim();
      final value = entry.value?.toString().trim();
      if (key != null &&
          defaultLoteStatusEtapasMap.containsKey(key) &&
          value != null &&
          EtapaStatus.values.contains(value)) {
        result[key] = value;
      }
    }
  }
  return result;
}

List<Map<String, dynamic>> _mapListFromJson(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map(
        (item) => item.map<String, dynamic>(
          (k, v) => MapEntry<String, dynamic>(k.toString(), v),
        ),
      )
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
    final area = frenteM * profundidadeM;
    if (!area.isFinite || area <= 0) return null;
    final rounded = double.parse(area.toStringAsFixed(6));
    if (!rounded.isFinite || rounded <= 0) return null;
    return rounded;
  }

  Lote copyWith({
    String? id,
    String? construtoraId,
    String? loteamentoId,
    String? quadraId,
    String? name,
    double? frenteM,
    bool clearFrenteM = false,
    double? profundidadeM,
    bool clearProfundidadeM = false,
    double? areaTerrenoM2,
    bool clearAreaTerrenoM2 = false,
    double? areaConstruidaM2,
    bool clearAreaConstruidaM2 = false,
    String? logradouro,
    bool clearLogradouro = false,
    double? taxaOcupacaoPercent,
    bool clearTaxaOcupacaoPercent = false,
    double? coeficienteAproveitamento,
    bool clearCoeficienteAproveitamento = false,
    double? areaPermeavelM2,
    bool clearAreaPermeavelM2 = false,
    double? taxaPermeabilidadePercent,
    bool clearTaxaPermeabilidadePercent = false,
    double? areaImpermeavelM2,
    bool clearAreaImpermeavelM2 = false,
    double? recuoFrontalM,
    bool clearRecuoFrontalM = false,
    double? recuoFundoM,
    bool clearRecuoFundoM = false,
    double? recuoLateralEsquerdoM,
    bool clearRecuoLateralEsquerdoM = false,
    double? recuoLateralDireitoM,
    bool clearRecuoLateralDireitoM = false,
    String? proprietarioNome,
    bool clearProprietarioNome = false,
    String? proprietarioDocumento,
    bool clearProprietarioDocumento = false,
    String? responsavelTecnicoNome,
    bool clearResponsavelTecnicoNome = false,
    String? responsavelTecnicoRegistro,
    bool clearResponsavelTecnicoRegistro = false,
    String? dataProjeto,
    bool clearDataProjeto = false,
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
      frenteM: clearFrenteM ? null : (frenteM ?? this.frenteM),
      profundidadeM: clearProfundidadeM
          ? null
          : (profundidadeM ?? this.profundidadeM),
      areaTerrenoM2: clearAreaTerrenoM2
          ? null
          : (areaTerrenoM2 ?? this.areaTerrenoM2),
      areaConstruidaM2: clearAreaConstruidaM2
          ? null
          : (areaConstruidaM2 ?? this.areaConstruidaM2),
      logradouro: clearLogradouro ? null : (logradouro ?? this.logradouro),
      taxaOcupacaoPercent: clearTaxaOcupacaoPercent
          ? null
          : (taxaOcupacaoPercent ?? this.taxaOcupacaoPercent),
      coeficienteAproveitamento: clearCoeficienteAproveitamento
          ? null
          : (coeficienteAproveitamento ?? this.coeficienteAproveitamento),
      areaPermeavelM2: clearAreaPermeavelM2
          ? null
          : (areaPermeavelM2 ?? this.areaPermeavelM2),
      taxaPermeabilidadePercent: clearTaxaPermeabilidadePercent
          ? null
          : (taxaPermeabilidadePercent ?? this.taxaPermeabilidadePercent),
      areaImpermeavelM2: clearAreaImpermeavelM2
          ? null
          : (areaImpermeavelM2 ?? this.areaImpermeavelM2),
      recuoFrontalM: clearRecuoFrontalM
          ? null
          : (recuoFrontalM ?? this.recuoFrontalM),
      recuoFundoM: clearRecuoFundoM ? null : (recuoFundoM ?? this.recuoFundoM),
      recuoLateralEsquerdoM: clearRecuoLateralEsquerdoM
          ? null
          : (recuoLateralEsquerdoM ?? this.recuoLateralEsquerdoM),
      recuoLateralDireitoM: clearRecuoLateralDireitoM
          ? null
          : (recuoLateralDireitoM ?? this.recuoLateralDireitoM),
      proprietarioNome: clearProprietarioNome
          ? null
          : (proprietarioNome ?? this.proprietarioNome),
      proprietarioDocumento: clearProprietarioDocumento
          ? null
          : (proprietarioDocumento ?? this.proprietarioDocumento),
      responsavelTecnicoNome: clearResponsavelTecnicoNome
          ? null
          : (responsavelTecnicoNome ?? this.responsavelTecnicoNome),
      responsavelTecnicoRegistro: clearResponsavelTecnicoRegistro
          ? null
          : (responsavelTecnicoRegistro ?? this.responsavelTecnicoRegistro),
      dataProjeto: clearDataProjeto ? null : (dataProjeto ?? this.dataProjeto),
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
