class ItemCompraNf {
  final String id;
  final String materialId;
  final String materialNome;
  final String unidadeMedida;
  final double quantidade;
  final int valorUnitarioCents;
  double get valorUnitario => valorUnitarioCents / 100.0;
  final int valorTotalCents;
  double get valorTotal => valorTotalCents / 100.0;
  final double quantidadeRecebida;

  const ItemCompraNf({
    required this.id,
    required this.materialId,
    required this.materialNome,
    required this.unidadeMedida,
    required this.quantidade,
    required this.valorUnitarioCents,
    required this.valorTotalCents,
    this.quantidadeRecebida = 0.0,
  });

  bool get isTotalmenteRecebido => quantidadeRecebida >= quantidade;
  double get quantidadePendente =>
      (quantidade - quantidadeRecebida).clamp(0.0, double.infinity);

  ItemCompraNf copyWith({
    String? id,
    String? materialId,
    String? materialNome,
    String? unidadeMedida,
    double? quantidade,
    int? valorUnitarioCents,
    int? valorTotalCents,
    double? quantidadeRecebida,
  }) {
    return ItemCompraNf(
      id: id ?? this.id,
      materialId: materialId ?? this.materialId,
      materialNome: materialNome ?? this.materialNome,
      unidadeMedida: unidadeMedida ?? this.unidadeMedida,
      quantidade: quantidade ?? this.quantidade,
      valorUnitarioCents: valorUnitarioCents ?? this.valorUnitarioCents,
      valorTotalCents: valorTotalCents ?? this.valorTotalCents,
      quantidadeRecebida: quantidadeRecebida ?? this.quantidadeRecebida,
    );
  }

  factory ItemCompraNf.fromJson(Map<String, dynamic> json) {
    final q = (json['quantidade'] as num?)?.toDouble() ?? 0.0;
    final qRec = (json['quantidadeRecebida'] as num?)?.toDouble() ?? 0.0;
    final vUnitCents = json['valorUnitarioCents'] is int
        ? json['valorUnitarioCents'] as int
        : ((json['valorUnitario'] as num?) != null
            ? ((json['valorUnitario'] as num) * 100).round()
            : 0);

    final vTotalCents = json['valorTotalCents'] is int
        ? json['valorTotalCents'] as int
        : ((json['valorTotal'] as num?) != null
            ? ((json['valorTotal'] as num) * 100).round()
            : (q * vUnitCents).round());

    return ItemCompraNf(
      id: json['id'] as String? ?? '',
      materialId: json['materialId'] as String? ?? '',
      materialNome: json['materialNome'] as String? ?? '',
      unidadeMedida: json['unidadeMedida'] as String? ?? 'un',
      quantidade: q,
      valorUnitarioCents: vUnitCents,
      valorTotalCents: vTotalCents,
      quantidadeRecebida: qRec,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'materialId': materialId,
      'materialNome': materialNome,
      'unidadeMedida': unidadeMedida,
      'quantidade': quantidade,
      'valorUnitarioCents': valorUnitarioCents,
      'valorTotalCents': valorTotalCents,
      'quantidadeRecebida': quantidadeRecebida,
    };
  }
}
