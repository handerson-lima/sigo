import 'package:cloud_firestore/cloud_firestore.dart';
import 'item_compra.dart';
import 'parcela_compra.dart';

enum StatusCompra {
  aberto,
  parcial,
  pago,
  cancelado;

  String get label => switch (this) {
        StatusCompra.aberto => 'Aberto',
        StatusCompra.parcial => 'Parcialmente Pago',
        StatusCompra.pago => 'Pago',
        StatusCompra.cancelado => 'Cancelado',
      };
}

enum StatusRecebimentoCompra {
  pendente,
  parcial,
  recebido;

  String get label => switch (this) {
        StatusRecebimentoCompra.pendente => 'Recebimento Pendente',
        StatusRecebimentoCompra.parcial => 'Recebido Parcial',
        StatusRecebimentoCompra.recebido => 'Totalmente Recebido',
      };
}

class CompraNf {
  final String id;
  final String construtoraId;
  final String obraId;
  final String fornecedorId;
  final String fornecedorNome;
  final String? fornecedorDocumento;
  final String numeroNf;
  final String? serieNf;
  final String? chaveAcessoNf;
  final DateTime dataEmissao;
  final DateTime? dataRecebimento;
  final String? descricao;
  final StatusCompra status;
  final StatusRecebimentoCompra statusRecebimento;

  // Valores monetários em centavos
  final int valorItensCents;
  final int freteCents;
  final int despesasAcessoriasCents;
  final int descontoCents;
  final int totalCompraCents;

  double get valorItens => valorItensCents / 100.0;
  double get frete => freteCents / 100.0;
  double get despesasAcessorias => despesasAcessoriasCents / 100.0;
  double get desconto => descontoCents / 100.0;
  double get totalCompra => totalCompraCents / 100.0;

  final List<ItemCompraNf> itens;
  final List<ParcelaCompra> parcelas;

  final String? anexoNfUrl;
  final String? anexoNfPath;

  final String criadoPorUid;
  final String? atualizadoPorUid;
  final DateTime createdAt;
  final DateTime updatedAt;

  final String? motivoCancelamento;
  final String? canceladoPorUid;
  final DateTime? dataCancelamento;

  const CompraNf({
    required this.id,
    required this.construtoraId,
    required this.obraId,
    required this.fornecedorId,
    required this.fornecedorNome,
    this.fornecedorDocumento,
    required this.numeroNf,
    this.serieNf,
    this.chaveAcessoNf,
    required this.dataEmissao,
    this.dataRecebimento,
    this.descricao,
    this.status = StatusCompra.aberto,
    this.statusRecebimento = StatusRecebimentoCompra.pendente,
    required this.valorItensCents,
    this.freteCents = 0,
    this.despesasAcessoriasCents = 0,
    this.descontoCents = 0,
    required this.totalCompraCents,
    this.itens = const [],
    this.parcelas = const [],
    this.anexoNfUrl,
    this.anexoNfPath,
    required this.criadoPorUid,
    this.atualizadoPorUid,
    required this.createdAt,
    required this.updatedAt,
    this.motivoCancelamento,
    this.canceladoPorUid,
    this.dataCancelamento,
  });

  /// Soma dos centavos já pagos das parcelas
  int get totalPagoCents {
    return parcelas
        .where((p) => p.status == StatusParcelaCompra.pago)
        .fold<int>(0, (acc, p) => acc + p.valorCents);
  }

  double get totalPago => totalPagoCents / 100.0;

  /// Saldo que ainda resta ser pago
  int get saldoDevedorCents {
    final saldo = totalCompraCents - totalPagoCents;
    return saldo < 0 ? 0 : saldo;
  }

  double get saldoDevedor => saldoDevedorCents / 100.0;

  bool get isQuitada => saldoDevedorCents == 0 && parcelas.isNotEmpty;

  bool get isAtrasada {
    if (status == StatusCompra.pago || status == StatusCompra.cancelado) {
      return false;
    }
    final hoje = DateTime.now();
    final inicioHoje = DateTime(hoje.year, hoje.month, hoje.day);
    return parcelas.any((p) =>
        p.status == StatusParcelaCompra.pendente &&
        DateTime(p.dataVencimento.year, p.dataVencimento.month,
                p.dataVencimento.day)
            .isBefore(inicioHoje));
  }

  int get quantidadeItens => itens.length;

  bool get isTotalmenteRecebido {
    if (itens.isEmpty) return false;
    return itens.every((i) => i.isTotalmenteRecebido);
  }

  CompraNf copyWith({
    String? id,
    String? construtoraId,
    String? obraId,
    String? fornecedorId,
    String? fornecedorNome,
    String? fornecedorDocumento,
    String? numeroNf,
    String? serieNf,
    String? chaveAcessoNf,
    DateTime? dataEmissao,
    DateTime? dataRecebimento,
    String? descricao,
    StatusCompra? status,
    StatusRecebimentoCompra? statusRecebimento,
    int? valorItensCents,
    int? freteCents,
    int? despesasAcessoriasCents,
    int? descontoCents,
    int? totalCompraCents,
    List<ItemCompraNf>? itens,
    List<ParcelaCompra>? parcelas,
    String? anexoNfUrl,
    String? anexoNfPath,
    String? criadoPorUid,
    String? atualizadoPorUid,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? motivoCancelamento,
    String? canceladoPorUid,
    DateTime? dataCancelamento,
  }) {
    return CompraNf(
      id: id ?? this.id,
      construtoraId: construtoraId ?? this.construtoraId,
      obraId: obraId ?? this.obraId,
      fornecedorId: fornecedorId ?? this.fornecedorId,
      fornecedorNome: fornecedorNome ?? this.fornecedorNome,
      fornecedorDocumento: fornecedorDocumento ?? this.fornecedorDocumento,
      numeroNf: numeroNf ?? this.numeroNf,
      serieNf: serieNf ?? this.serieNf,
      chaveAcessoNf: chaveAcessoNf ?? this.chaveAcessoNf,
      dataEmissao: dataEmissao ?? this.dataEmissao,
      dataRecebimento: dataRecebimento ?? this.dataRecebimento,
      descricao: descricao ?? this.descricao,
      status: status ?? this.status,
      statusRecebimento: statusRecebimento ?? this.statusRecebimento,
      valorItensCents: valorItensCents ?? this.valorItensCents,
      freteCents: freteCents ?? this.freteCents,
      despesasAcessoriasCents:
          despesasAcessoriasCents ?? this.despesasAcessoriasCents,
      descontoCents: descontoCents ?? this.descontoCents,
      totalCompraCents: totalCompraCents ?? this.totalCompraCents,
      itens: itens ?? this.itens,
      parcelas: parcelas ?? this.parcelas,
      anexoNfUrl: anexoNfUrl ?? this.anexoNfUrl,
      anexoNfPath: anexoNfPath ?? this.anexoNfPath,
      criadoPorUid: criadoPorUid ?? this.criadoPorUid,
      atualizadoPorUid: atualizadoPorUid ?? this.atualizadoPorUid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      motivoCancelamento: motivoCancelamento ?? this.motivoCancelamento,
      canceladoPorUid: canceladoPorUid ?? this.canceladoPorUid,
      dataCancelamento: dataCancelamento ?? this.dataCancelamento,
    );
  }

  factory CompraNf.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return null;
    }

    final vItensCents = json['valorItensCents'] is int
        ? json['valorItensCents'] as int
        : ((json['valorItens'] as num?) != null
            ? ((json['valorItens'] as num) * 100).round()
            : 0);

    final freteC = json['freteCents'] is int
        ? json['freteCents'] as int
        : ((json['frete'] as num?) != null
            ? ((json['frete'] as num) * 100).round()
            : 0);

    final despAcessC = json['despesasAcessoriasCents'] is int
        ? json['despesasAcessoriasCents'] as int
        : ((json['despesasAcessorias'] as num?) != null
            ? ((json['despesasAcessorias'] as num) * 100).round()
            : 0);

    final descC = json['descontoCents'] is int
        ? json['descontoCents'] as int
        : ((json['desconto'] as num?) != null
            ? ((json['desconto'] as num) * 100).round()
            : 0);

    final totCents = json['totalCompraCents'] is int
        ? json['totalCompraCents'] as int
        : ((json['totalCompra'] as num?) != null
            ? ((json['totalCompra'] as num) * 100).round()
            : (vItensCents + freteC + despAcessC - descC));

    final statusStr = json['status'] as String? ?? 'aberto';
    final status = StatusCompra.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => StatusCompra.aberto,
    );

    final statusRecStr = json['statusRecebimento'] as String? ?? 'pendente';
    final statusRecebimento = StatusRecebimentoCompra.values.firstWhere(
      (e) => e.name == statusRecStr,
      orElse: () => StatusRecebimentoCompra.pendente,
    );

    final rawItens = json['itens'] as List<dynamic>? ?? [];
    final itensList = rawItens
        .map((e) => ItemCompraNf.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final rawParcelas = json['parcelas'] as List<dynamic>? ?? [];
    final parcelasList = rawParcelas
        .map((e) => ParcelaCompra.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return CompraNf(
      id: json['id'] as String? ?? '',
      construtoraId: json['construtoraId'] as String? ?? '',
      obraId: json['obraId'] as String? ?? '',
      fornecedorId: json['fornecedorId'] as String? ?? '',
      fornecedorNome: json['fornecedorNome'] as String? ?? '',
      fornecedorDocumento: json['fornecedorDocumento'] as String?,
      numeroNf: json['numeroNf'] as String? ?? '',
      serieNf: json['serieNf'] as String?,
      chaveAcessoNf: json['chaveAcessoNf'] as String?,
      dataEmissao: parseDate(json['dataEmissao']) ?? DateTime.now(),
      dataRecebimento: parseDate(json['dataRecebimento']),
      descricao: json['descricao'] as String?,
      status: status,
      statusRecebimento: statusRecebimento,
      valorItensCents: vItensCents,
      freteCents: freteC,
      despesasAcessoriasCents: despAcessC,
      descontoCents: descC,
      totalCompraCents: totCents,
      itens: itensList,
      parcelas: parcelasList,
      anexoNfUrl: json['anexoNfUrl'] as String?,
      anexoNfPath: json['anexoNfPath'] as String?,
      criadoPorUid: json['criadoPorUid'] as String? ?? '',
      atualizadoPorUid: json['atualizadoPorUid'] as String?,
      createdAt: parseDate(json['createdAt']) ?? DateTime.now(),
      updatedAt: parseDate(json['updatedAt']) ?? DateTime.now(),
      motivoCancelamento: json['motivoCancelamento'] as String?,
      canceladoPorUid: json['canceladoPorUid'] as String?,
      dataCancelamento: parseDate(json['dataCancelamento']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'construtoraId': construtoraId,
      'obraId': obraId,
      'fornecedorId': fornecedorId,
      'fornecedorNome': fornecedorNome,
      'fornecedorDocumento': fornecedorDocumento,
      'numeroNf': numeroNf,
      'serieNf': serieNf,
      'chaveAcessoNf': chaveAcessoNf,
      'dataEmissao': dataEmissao.toIso8601String(),
      'dataRecebimento': dataRecebimento?.toIso8601String(),
      'descricao': descricao,
      'status': status.name,
      'statusRecebimento': statusRecebimento.name,
      'valorItensCents': valorItensCents,
      'freteCents': freteCents,
      'despesasAcessoriasCents': despesasAcessoriasCents,
      'descontoCents': descontoCents,
      'totalCompraCents': totalCompraCents,
      'itens': itens.map((i) => i.toJson()).toList(),
      'parcelas': parcelas.map((p) => p.toJson()).toList(),
      'anexoNfUrl': anexoNfUrl,
      'anexoNfPath': anexoNfPath,
      'criadoPorUid': criadoPorUid,
      'atualizadoPorUid': atualizadoPorUid,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'motivoCancelamento': motivoCancelamento,
      'canceladoPorUid': canceladoPorUid,
      'dataCancelamento': dataCancelamento?.toIso8601String(),
    };
  }
}
