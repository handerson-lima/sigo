import '../../../core/contracts.dart';

enum CuboCusto {
  material,
  maoDeObra,
  despesaDireta,
  rateioIndireto;

  String get label => switch (this) {
    CuboCusto.material => 'Materiais',
    CuboCusto.maoDeObra => 'Mão de Obra',
    CuboCusto.despesaDireta => 'Despesas Diretas',
    CuboCusto.rateioIndireto => 'Rateio Indireto',
  };
}

class ExtratoItemCusto {
  final String id;
  final CuboCusto cubo;
  final String descricao;
  final DateTime data;
  final int valorCents;
  final String? documentoReferencia;
  final String? responsavelNome;

  const ExtratoItemCusto({
    required this.id,
    required this.cubo,
    required this.descricao,
    required this.data,
    required this.valorCents,
    this.documentoReferencia,
    this.responsavelNome,
  });

  double get valor => valorCents / 100.0;

  Map<String, dynamic> toMap() => {
    'id': id,
    'cubo': cubo.name,
    'descricao': descricao,
    'data': data.toIso8601String(),
    'valorCents': valorCents,
    'documentoReferencia': documentoReferencia,
    'responsavelNome': responsavelNome,
  };

  factory ExtratoItemCusto.fromMap(Map<String, dynamic> map) {
    final cuboName = map['cubo'] as String?;
    final cubo = CuboCusto.values.firstWhere(
      (c) => c.name == cuboName,
      orElse: () => CuboCusto.material,
    );

    final dataRaw = map['data'];
    final data = dataRaw != null ? readDate(dataRaw) : DateTime.now();

    return ExtratoItemCusto(
      id: map['id'] as String? ?? '',
      cubo: cubo,
      descricao: map['descricao'] as String? ?? '',
      data: data,
      valorCents: (map['valorCents'] as num?)?.toInt() ?? 0,
      documentoReferencia: map['documentoReferencia'] as String?,
      responsavelNome: map['responsavelNome'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExtratoItemCusto &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          cubo == other.cubo &&
          valorCents == other.valorCents;

  @override
  int get hashCode => id.hashCode ^ cubo.hashCode ^ valorCents.hashCode;
}

class CustoLoteConsolidado {
  final String loteId;
  final String loteNome;
  final int materiaisCents;
  final int maoDeObraCents;
  final int despesasDiretasCents;
  final int rateioIndiretoCents;
  final int totalCustoLoteCents;
  final int orcamentoPrevistoCents;
  final int varianciaCents;
  final double percentualConsumido;
  final DateTime ultimaAtualizacao;

  CustoLoteConsolidado({
    required this.loteId,
    required this.loteNome,
    required this.materiaisCents,
    required this.maoDeObraCents,
    required this.despesasDiretasCents,
    required this.rateioIndiretoCents,
    int? totalCustoLoteCents,
    this.orcamentoPrevistoCents = 0,
    int? varianciaCents,
    double? percentualConsumido,
    DateTime? ultimaAtualizacao,
  }) : totalCustoLoteCents =
           totalCustoLoteCents ??
           (materiaisCents +
               maoDeObraCents +
               despesasDiretasCents +
               rateioIndiretoCents),
       varianciaCents =
           varianciaCents ??
           ((totalCustoLoteCents ??
                   (materiaisCents +
                       maoDeObraCents +
                       despesasDiretasCents +
                       rateioIndiretoCents)) -
               orcamentoPrevistoCents),
       percentualConsumido =
           percentualConsumido ??
           (orcamentoPrevistoCents > 0
               ? (totalCustoLoteCents ??
                         (materiaisCents +
                             maoDeObraCents +
                             despesasDiretasCents +
                             rateioIndiretoCents)) /
                     orcamentoPrevistoCents.toDouble()
               : 0.0),
       ultimaAtualizacao = ultimaAtualizacao ?? DateTime.now();

  double get totalCustoLote => totalCustoLoteCents / 100.0;
  double get materiais => materiaisCents / 100.0;
  double get maoDeObra => maoDeObraCents / 100.0;
  double get despesasDiretas => despesasDiretasCents / 100.0;
  double get rateioIndireto => rateioIndiretoCents / 100.0;
  double get orcamentoPrevisto => orcamentoPrevistoCents / 100.0;
  double get variancia => varianciaCents / 100.0;

  bool get temDesvioPositivo => varianciaCents > 0;
  bool get estourado =>
      orcamentoPrevistoCents > 0 &&
      totalCustoLoteCents > orcamentoPrevistoCents;
  bool get emAlerta =>
      orcamentoPrevistoCents > 0 &&
      percentualConsumido >= 0.85 &&
      percentualConsumido <= 1.0;

  CustoLoteConsolidado copyWith({
    String? loteId,
    String? loteNome,
    int? materiaisCents,
    int? maoDeObraCents,
    int? despesasDiretasCents,
    int? rateioIndiretoCents,
    int? orcamentoPrevistoCents,
    DateTime? ultimaAtualizacao,
  }) {
    return CustoLoteConsolidado(
      loteId: loteId ?? this.loteId,
      loteNome: loteNome ?? this.loteNome,
      materiaisCents: materiaisCents ?? this.materiaisCents,
      maoDeObraCents: maoDeObraCents ?? this.maoDeObraCents,
      despesasDiretasCents: despesasDiretasCents ?? this.despesasDiretasCents,
      rateioIndiretoCents: rateioIndiretoCents ?? this.rateioIndiretoCents,
      orcamentoPrevistoCents:
          orcamentoPrevistoCents ?? this.orcamentoPrevistoCents,
      ultimaAtualizacao: ultimaAtualizacao ?? this.ultimaAtualizacao,
    );
  }

  Map<String, dynamic> toMap() => {
    'loteId': loteId,
    'loteNome': loteNome,
    'materiaisCents': materiaisCents,
    'maoDeObraCents': maoDeObraCents,
    'despesasDiretasCents': despesasDiretasCents,
    'rateioIndiretoCents': rateioIndiretoCents,
    'totalCustoLoteCents': totalCustoLoteCents,
    'orcamentoPrevistoCents': orcamentoPrevistoCents,
    'varianciaCents': varianciaCents,
    'percentualConsumido': percentualConsumido,
    'ultimaAtualizacao': ultimaAtualizacao.toIso8601String(),
  };

  factory CustoLoteConsolidado.fromMap(Map<String, dynamic> map) {
    final mat = (map['materiaisCents'] as num?)?.toInt() ?? 0;
    final mo = (map['maoDeObraCents'] as num?)?.toInt() ?? 0;
    final dd = (map['despesasDiretasCents'] as num?)?.toInt() ?? 0;
    final ri = (map['rateioIndiretoCents'] as num?)?.toInt() ?? 0;
    final total =
        (map['totalCustoLoteCents'] as num?)?.toInt() ?? (mat + mo + dd + ri);
    final orcamento = (map['orcamentoPrevistoCents'] as num?)?.toInt() ?? 0;

    final dataRaw = map['ultimaAtualizacao'];
    final data = dataRaw != null ? readDate(dataRaw) : DateTime.now();

    return CustoLoteConsolidado(
      loteId: map['loteId'] as String? ?? '',
      loteNome: map['loteNome'] as String? ?? '',
      materiaisCents: mat,
      maoDeObraCents: mo,
      despesasDiretasCents: dd,
      rateioIndiretoCents: ri,
      totalCustoLoteCents: total,
      orcamentoPrevistoCents: orcamento,
      varianciaCents:
          (map['varianciaCents'] as num?)?.toInt() ?? (total - orcamento),
      percentualConsumido:
          (map['percentualConsumido'] as num?)?.toDouble() ??
          (orcamento > 0 ? total / orcamento.toDouble() : 0.0),
      ultimaAtualizacao: data,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustoLoteConsolidado &&
          runtimeType == other.runtimeType &&
          loteId == other.loteId &&
          totalCustoLoteCents == other.totalCustoLoteCents &&
          orcamentoPrevistoCents == other.orcamentoPrevistoCents;

  @override
  int get hashCode =>
      loteId.hashCode ^
      totalCustoLoteCents.hashCode ^
      orcamentoPrevistoCents.hashCode;
}

class ResumoCustosObra {
  final String obraId;
  final int totalGeralCents;
  final int totalMateriaisCents;
  final int totalMaoDeObraCents;
  final int totalDespesasDiretasCents;
  final int totalDespesasIndiretasCents;
  final int orcamentoTotalPrevistoCents;
  final List<CustoLoteConsolidado> lotesCustos;
  final DateTime apuradoEm;

  ResumoCustosObra({
    required this.obraId,
    required this.totalGeralCents,
    required this.totalMateriaisCents,
    required this.totalMaoDeObraCents,
    required this.totalDespesasDiretasCents,
    required this.totalDespesasIndiretasCents,
    required this.orcamentoTotalPrevistoCents,
    this.lotesCustos = const [],
    DateTime? apuradoEm,
  }) : apuradoEm = apuradoEm ?? DateTime.now();

  double get totalGeral => totalGeralCents / 100.0;
  double get totalMateriais => totalMateriaisCents / 100.0;
  double get totalMaoDeObra => totalMaoDeObraCents / 100.0;
  double get totalDespesasDiretas => totalDespesasDiretasCents / 100.0;
  double get totalDespesasIndiretas => totalDespesasIndiretasCents / 100.0;
  double get orcamentoTotalPrevisto => orcamentoTotalPrevistoCents / 100.0;

  double get varianciaGeralCents =>
      (totalGeralCents - orcamentoTotalPrevistoCents).toDouble();
  double get percentualConsumidoGeral => orcamentoTotalPrevistoCents > 0
      ? totalGeralCents / orcamentoTotalPrevistoCents.toDouble()
      : 0.0;

  Map<String, dynamic> toMap() => {
    'obraId': obraId,
    'totalGeralCents': totalGeralCents,
    'totalMateriaisCents': totalMateriaisCents,
    'totalMaoDeObraCents': totalMaoDeObraCents,
    'totalDespesasDiretasCents': totalDespesasDiretasCents,
    'totalDespesasIndiretasCents': totalDespesasIndiretasCents,
    'orcamentoTotalPrevistoCents': orcamentoTotalPrevistoCents,
    'lotesCustos': lotesCustos.map((l) => l.toMap()).toList(),
    'apuradoEm': apuradoEm.toIso8601String(),
  };

  factory ResumoCustosObra.fromMap(Map<String, dynamic> map) {
    final lotesRaw = map['lotesCustos'] as List<dynamic>? ?? [];
    final lotesCustos = lotesRaw
        .map(
          (e) =>
              CustoLoteConsolidado.fromMap(Map<String, dynamic>.from(e as Map)),
        )
        .toList();

    final dataRaw = map['apuradoEm'];
    final data = dataRaw != null ? readDate(dataRaw) : DateTime.now();

    return ResumoCustosObra(
      obraId: map['obraId'] as String? ?? '',
      totalGeralCents: (map['totalGeralCents'] as num?)?.toInt() ?? 0,
      totalMateriaisCents: (map['totalMateriaisCents'] as num?)?.toInt() ?? 0,
      totalMaoDeObraCents: (map['totalMaoDeObraCents'] as num?)?.toInt() ?? 0,
      totalDespesasDiretasCents:
          (map['totalDespesasDiretasCents'] as num?)?.toInt() ?? 0,
      totalDespesasIndiretasCents:
          (map['totalDespesasIndiretasCents'] as num?)?.toInt() ?? 0,
      orcamentoTotalPrevistoCents:
          (map['orcamentoTotalPrevistoCents'] as num?)?.toInt() ?? 0,
      lotesCustos: lotesCustos,
      apuradoEm: data,
    );
  }
}
