import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/contracts.dart';

enum StatusDespesaAdm {
  pendente,
  pago,
  atrasado,
  cancelado;

  String get label => switch (this) {
    StatusDespesaAdm.pendente => 'Pendente',
    StatusDespesaAdm.pago => 'Pago',
    StatusDespesaAdm.atrasado => 'Atrasado',
    StatusDespesaAdm.cancelado => 'Cancelado',
  };
}

enum MetodoPagamento {
  pix,
  boleto,
  transferencia,
  dinheiro,
  cartao,
  outro;

  String get label => switch (this) {
    MetodoPagamento.pix => 'Pix',
    MetodoPagamento.boleto => 'Boleto Bancário',
    MetodoPagamento.transferencia => 'TED / DOC / Transferência',
    MetodoPagamento.dinheiro => 'Dinheiro em Espécie',
    MetodoPagamento.cartao => 'Cartão de Débito / Crédito',
    MetodoPagamento.outro => 'Outro',
  };
}

enum CategoriaDespesa {
  utilidades,
  locacao,
  servicosTerceiros,
  alimentacao,
  combustivel,
  taxasLicencas,
  outros;

  String get label => switch (this) {
    CategoriaDespesa.utilidades => 'Utilidades (Água / Luz / Internet)',
    CategoriaDespesa.locacao => 'Locação de Equipamentos',
    CategoriaDespesa.servicosTerceiros => 'Serviços de Terceiros',
    CategoriaDespesa.alimentacao => 'Alimentação de Equipe',
    CategoriaDespesa.combustivel => 'Combustível / Gerador',
    CategoriaDespesa.taxasLicencas => 'Taxas, Alvarás e Licenças',
    CategoriaDespesa.outros => 'Outras Despesas Gerais',
  };
}

class ParcelaDespesa {
  final int numero;
  final int valorCents;
  double get valor => valorCents / 100.0;
  final DateTime dataVencimento;
  final StatusDespesaAdm status;
  final DateTime? dataPagamento;
  final String? pagoPorUid;
  final MetodoPagamento? metodoPagamento;
  final String? comprovanteUrl;
  final String? comprovantePath;
  final String? idempotencyKey;

  const ParcelaDespesa({
    required this.numero,
    required this.valorCents,
    required this.dataVencimento,
    this.status = StatusDespesaAdm.pendente,
    this.dataPagamento,
    this.pagoPorUid,
    this.metodoPagamento,
    this.comprovanteUrl,
    this.comprovantePath,
    this.idempotencyKey,
  });

  ParcelaDespesa copyWith({
    int? numero,
    int? valorCents,
    DateTime? dataVencimento,
    StatusDespesaAdm? status,
    DateTime? dataPagamento,
    String? pagoPorUid,
    MetodoPagamento? metodoPagamento,
    String? comprovanteUrl,
    String? comprovantePath,
    String? idempotencyKey,
  }) {
    return ParcelaDespesa(
      numero: numero ?? this.numero,
      valorCents: valorCents ?? this.valorCents,
      dataVencimento: dataVencimento ?? this.dataVencimento,
      status: status ?? this.status,
      dataPagamento: dataPagamento ?? this.dataPagamento,
      pagoPorUid: pagoPorUid ?? this.pagoPorUid,
      metodoPagamento: metodoPagamento ?? this.metodoPagamento,
      comprovanteUrl: comprovanteUrl ?? this.comprovanteUrl,
      comprovantePath: comprovantePath ?? this.comprovantePath,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    );
  }

  factory ParcelaDespesa.fromJson(Map<String, dynamic> json) {
    final numero = json['numero'] is int ? json['numero'] as int : 1;
    final valorCents = json['valorCents'] is int
        ? json['valorCents'] as int
        : (json['amountCents'] is int
              ? json['amountCents'] as int
              : decimalUnits(
                  (json['valor'] as num?)?.toDouble() ?? 0.0,
                  2,
                  round: true,
                ));

    final vencimentoRaw = json['dataVencimento'];
    final vencimento = vencimentoRaw != null
        ? readDate(vencimentoRaw)
        : DateTime.now();

    final statusStr = json['status'] as String?;
    final status = StatusDespesaAdm.values.firstWhere(
      (s) => s.name == statusStr,
      orElse: () => StatusDespesaAdm.pendente,
    );

    final pgtoRaw = json['dataPagamento'];
    final dataPagamento = pgtoRaw != null ? readDate(pgtoRaw) : null;

    final metodoStr = json['metodoPagamento'] as String?;
    final metodoPagamento = metodoStr != null
        ? MetodoPagamento.values.firstWhere(
            (m) => m.name == metodoStr,
            orElse: () => MetodoPagamento.outro,
          )
        : null;

    return ParcelaDespesa(
      numero: numero,
      valorCents: valorCents,
      dataVencimento: vencimento,
      status: status,
      dataPagamento: dataPagamento,
      pagoPorUid: json['pagoPorUid'] as String?,
      metodoPagamento: metodoPagamento,
      comprovanteUrl: json['comprovanteUrl'] as String?,
      comprovantePath: json['comprovantePath'] as String?,
      idempotencyKey: json['idempotencyKey'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'numero': numero,
    'valorCents': valorCents,
    'valor': valorCents / 100.0,
    'dataVencimento': civilDate(dataVencimento),
    'status': status.name,
    'dataPagamento': dataPagamento == null
        ? null
        : Timestamp.fromDate(dataPagamento!),
    'pagoPorUid': pagoPorUid,
    'metodoPagamento': metodoPagamento?.name,
    'comprovanteUrl': comprovanteUrl,
    'comprovantePath': comprovantePath,
    'idempotencyKey': idempotencyKey,
  };
}

class DespesaAdm {
  final String id;
  final String construtoraId;
  final String obraId;
  final String descricao;
  final CategoriaDespesa categoria;
  final String? fornecedorNome;
  final String? fornecedorId;
  final String? loteId;
  final int valorTotalCents;
  double get valorTotal => valorTotalCents / 100.0;
  final StatusDespesaAdm status;
  final DateTime dataEmissao;
  final DateTime dataVencimento;
  final DateTime? dataPagamento;
  final String? pagoPorUid;
  final MetodoPagamento? metodoPagamento;
  final String? comprovanteUrl;
  final String? comprovantePath;
  final String? comprovanteNome;
  final bool isParcelado;
  final List<ParcelaDespesa> parcelas;
  final String? motivoCancelamento;
  final String? canceladoPorUid;
  final DateTime? dataCancelamento;
  final String responsavelId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;

  const DespesaAdm({
    required this.id,
    required this.construtoraId,
    required this.obraId,
    required this.descricao,
    required this.categoria,
    this.fornecedorNome,
    this.fornecedorId,
    this.loteId,
    required this.valorTotalCents,
    this.status = StatusDespesaAdm.pendente,
    required this.dataEmissao,
    required this.dataVencimento,
    this.dataPagamento,
    this.pagoPorUid,
    this.metodoPagamento,
    this.comprovanteUrl,
    this.comprovantePath,
    this.comprovanteNome,
    this.isParcelado = false,
    this.parcelas = const [],
    this.motivoCancelamento,
    this.canceladoPorUid,
    this.dataCancelamento,
    required this.responsavelId,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = 1,
  });

  bool get isVencida {
    if (status == StatusDespesaAdm.pago ||
        status == StatusDespesaAdm.cancelado) {
      return false;
    }
    final today = DateTime.now();
    final endOfDueDay = DateTime(
      dataVencimento.year,
      dataVencimento.month,
      dataVencimento.day,
      23,
      59,
      59,
    );
    return today.isAfter(endOfDueDay);
  }

  int get saldoDevedorCents {
    if (status == StatusDespesaAdm.pago ||
        status == StatusDespesaAdm.cancelado) {
      return 0;
    }
    if (!isParcelado || parcelas.isEmpty) {
      return valorTotalCents;
    }
    return parcelas
        .where((p) => p.status != StatusDespesaAdm.pago)
        .fold<int>(0, (acc, p) => acc + p.valorCents);
  }

  int get valorPagoCents {
    if (status == StatusDespesaAdm.cancelado) return 0;
    if (status == StatusDespesaAdm.pago) return valorTotalCents;
    if (!isParcelado || parcelas.isEmpty) return 0;
    return parcelas
        .where((p) => p.status == StatusDespesaAdm.pago)
        .fold<int>(0, (acc, p) => acc + p.valorCents);
  }

  DespesaAdm copyWith({
    String? id,
    String? construtoraId,
    String? obraId,
    String? descricao,
    CategoriaDespesa? categoria,
    String? fornecedorNome,
    String? fornecedorId,
    String? loteId,
    int? valorTotalCents,
    StatusDespesaAdm? status,
    DateTime? dataEmissao,
    DateTime? dataVencimento,
    DateTime? dataPagamento,
    String? pagoPorUid,
    MetodoPagamento? metodoPagamento,
    String? comprovanteUrl,
    String? comprovantePath,
    String? comprovanteNome,
    bool? isParcelado,
    List<ParcelaDespesa>? parcelas,
    String? motivoCancelamento,
    String? canceladoPorUid,
    DateTime? dataCancelamento,
    String? responsavelId,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? schemaVersion,
  }) {
    return DespesaAdm(
      id: id ?? this.id,
      construtoraId: construtoraId ?? this.construtoraId,
      obraId: obraId ?? this.obraId,
      descricao: descricao ?? this.descricao,
      categoria: categoria ?? this.categoria,
      fornecedorNome: fornecedorNome ?? this.fornecedorNome,
      fornecedorId: fornecedorId ?? this.fornecedorId,
      loteId: loteId ?? this.loteId,
      valorTotalCents: valorTotalCents ?? this.valorTotalCents,
      status: status ?? this.status,
      dataEmissao: dataEmissao ?? this.dataEmissao,
      dataVencimento: dataVencimento ?? this.dataVencimento,
      dataPagamento: dataPagamento ?? this.dataPagamento,
      pagoPorUid: pagoPorUid ?? this.pagoPorUid,
      metodoPagamento: metodoPagamento ?? this.metodoPagamento,
      comprovanteUrl: comprovanteUrl ?? this.comprovanteUrl,
      comprovantePath: comprovantePath ?? this.comprovantePath,
      comprovanteNome: comprovanteNome ?? this.comprovanteNome,
      isParcelado: isParcelado ?? this.isParcelado,
      parcelas: parcelas ?? this.parcelas,
      motivoCancelamento: motivoCancelamento ?? this.motivoCancelamento,
      canceladoPorUid: canceladoPorUid ?? this.canceladoPorUid,
      dataCancelamento: dataCancelamento ?? this.dataCancelamento,
      responsavelId: responsavelId ?? this.responsavelId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }

  factory DespesaAdm.fromJson(Map<String, dynamic> json) {
    final valorCents = json['valorTotalCents'] is int
        ? json['valorTotalCents'] as int
        : (json['amountCents'] is int
              ? json['amountCents'] as int
              : (json['valorEmCentavos'] is int
                    ? json['valorEmCentavos'] as int
                    : decimalUnits(
                        (json['valor'] as num?)?.toDouble() ?? 0.0,
                        2,
                        round: true,
                      )));

    final catStr = json['categoria'] as String?;
    final categoria = CategoriaDespesa.values.firstWhere(
      (c) => c.name == catStr,
      orElse: () => CategoriaDespesa.outros,
    );

    final statusStr = json['status'] as String?;
    final status = StatusDespesaAdm.values.firstWhere(
      (s) => s.name == statusStr,
      orElse: () => StatusDespesaAdm.pendente,
    );

    final emissaoRaw = json['dataEmissao'];
    final dataEmissao = emissaoRaw != null
        ? readDate(emissaoRaw)
        : (json['createdAt'] != null
              ? readDate(json['createdAt'])
              : DateTime.now());

    final vencimentoRaw = json['dataVencimento'];
    final dataVencimento = vencimentoRaw != null
        ? readDate(vencimentoRaw)
        : DateTime.now();

    final pgtoRaw = json['dataPagamento'];
    final dataPagamento = pgtoRaw != null ? readDate(pgtoRaw) : null;

    final metodoStr = json['metodoPagamento'] as String?;
    final metodoPagamento = metodoStr != null
        ? MetodoPagamento.values.firstWhere(
            (m) => m.name == metodoStr,
            orElse: () => MetodoPagamento.outro,
          )
        : null;

    final createdRaw = json['createdAt'];
    final createdAt = createdRaw != null
        ? readDate(createdRaw)
        : DateTime.now();

    final updatedRaw = json['updatedAt'];
    final updatedAt = updatedRaw != null ? readDate(updatedRaw) : createdAt;

    final cancelamentoRaw = json['dataCancelamento'];
    final dataCancelamento = cancelamentoRaw != null
        ? readDate(cancelamentoRaw)
        : null;

    final rawParcelas = json['parcelas'];
    final parcelas = (rawParcelas is List)
        ? rawParcelas
              .whereType<Map<String, dynamic>>()
              .map((p) => ParcelaDespesa.fromJson(p))
              .toList()
        : <ParcelaDespesa>[];

    return DespesaAdm(
      id: json['id'] as String? ?? '',
      construtoraId: json['construtoraId'] as String? ?? '',
      obraId: json['obraId'] as String? ?? '',
      descricao: json['descricao'] as String? ?? '',
      categoria: categoria,
      fornecedorNome: json['fornecedorNome'] as String?,
      fornecedorId: json['fornecedorId'] as String?,
      loteId: json['loteId'] as String?,
      valorTotalCents: valorCents,
      status: status,
      dataEmissao: dataEmissao,
      dataVencimento: dataVencimento,
      dataPagamento: dataPagamento,
      pagoPorUid: json['pagoPorUid'] as String?,
      metodoPagamento: metodoPagamento,
      comprovanteUrl: json['comprovanteUrl'] as String?,
      comprovantePath: json['comprovantePath'] as String?,
      comprovanteNome: json['comprovanteNome'] as String?,
      isParcelado: json['isParcelado'] as bool? ?? parcelas.isNotEmpty,
      parcelas: parcelas,
      motivoCancelamento: json['motivoCancelamento'] as String?,
      canceladoPorUid: json['canceladoPorUid'] as String?,
      dataCancelamento: dataCancelamento,
      responsavelId: json['responsavelId'] as String? ?? '',
      createdAt: createdAt,
      updatedAt: updatedAt,
      schemaVersion: json['schemaVersion'] is int
          ? json['schemaVersion'] as int
          : 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'construtoraId': construtoraId,
    'obraId': obraId,
    'descricao': descricao,
    'categoria': categoria.name,
    'fornecedorNome': fornecedorNome,
    'fornecedorId': fornecedorId,
    'loteId': loteId,
    'valorTotalCents': valorTotalCents,
    'valor': valorTotalCents / 100.0,
    'status': status.name,
    'dataEmissao': Timestamp.fromDate(dataEmissao),
    'dataVencimento': civilDate(dataVencimento),
    'dataPagamento': dataPagamento == null
        ? null
        : Timestamp.fromDate(dataPagamento!),
    'pagoPorUid': pagoPorUid,
    'metodoPagamento': metodoPagamento?.name,
    'comprovanteUrl': comprovanteUrl,
    'comprovantePath': comprovantePath,
    'comprovanteNome': comprovanteNome,
    'isParcelado': isParcelado,
    'parcelas': parcelas.map((p) => p.toJson()).toList(),
    'motivoCancelamento': motivoCancelamento,
    'canceladoPorUid': canceladoPorUid,
    'dataCancelamento': dataCancelamento == null
        ? null
        : Timestamp.fromDate(dataCancelamento!),
    'responsavelId': responsavelId,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
    'schemaVersion': schemaVersion,
  };
}
