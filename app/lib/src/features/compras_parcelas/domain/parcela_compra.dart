import 'package:cloud_firestore/cloud_firestore.dart';

enum StatusParcelaCompra {
  pendente,
  pago,
  atrasado,
  cancelado;

  String get label => switch (this) {
        StatusParcelaCompra.pendente => 'Pendente',
        StatusParcelaCompra.pago => 'Pago',
        StatusParcelaCompra.atrasado => 'Atrasado',
        StatusParcelaCompra.cancelado => 'Cancelado',
      };
}

enum MetodoPagamentoCompra {
  pix,
  boleto,
  transferencia,
  cartao,
  dinheiro,
  outro;

  String get label => switch (this) {
        MetodoPagamentoCompra.pix => 'Pix',
        MetodoPagamentoCompra.boleto => 'Boleto Bancário',
        MetodoPagamentoCompra.transferencia => 'TED / Transferência',
        MetodoPagamentoCompra.cartao => 'Cartão de Débito / Crédito',
        MetodoPagamentoCompra.dinheiro => 'Dinheiro em Espécie',
        MetodoPagamentoCompra.outro => 'Outro',
      };
}

class ParcelaCompra {
  final int numero;
  final int valorCents;
  double get valor => valorCents / 100.0;
  final DateTime dataVencimento;
  final StatusParcelaCompra status;
  final DateTime? dataPagamento;
  final String? pagoPorUid;
  final MetodoPagamentoCompra? metodoPagamento;
  final String? comprovanteUrl;
  final String? comprovantePath;
  final String? idempotencyKey;
  final String? observacaoPagamento;

  const ParcelaCompra({
    required this.numero,
    required this.valorCents,
    required this.dataVencimento,
    this.status = StatusParcelaCompra.pendente,
    this.dataPagamento,
    this.pagoPorUid,
    this.metodoPagamento,
    this.comprovanteUrl,
    this.comprovantePath,
    this.idempotencyKey,
    this.observacaoPagamento,
  });

  ParcelaCompra copyWith({
    int? numero,
    int? valorCents,
    DateTime? dataVencimento,
    StatusParcelaCompra? status,
    DateTime? dataPagamento,
    String? pagoPorUid,
    MetodoPagamentoCompra? metodoPagamento,
    String? comprovanteUrl,
    String? comprovantePath,
    String? idempotencyKey,
    String? observacaoPagamento,
  }) {
    return ParcelaCompra(
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
      observacaoPagamento: observacaoPagamento ?? this.observacaoPagamento,
    );
  }

  factory ParcelaCompra.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return null;
    }

    final numVal = json['numero'] is int
        ? json['numero'] as int
        : (json['numero'] as num?)?.toInt() ?? 1;

    final vCents = json['valorCents'] is int
        ? json['valorCents'] as int
        : (json['valorCents'] as num?)?.toInt() ??
            ((json['valor'] as num?) != null
                ? ((json['valor'] as num) * 100).round()
                : 0);

    final statusStr = json['status'] as String? ?? 'pendente';
    final status = StatusParcelaCompra.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => StatusParcelaCompra.pendente,
    );

    MetodoPagamentoCompra? metodo;
    final metodoStr = json['metodoPagamento'] as String?;
    if (metodoStr != null) {
      metodo = MetodoPagamentoCompra.values.firstWhere(
        (e) => e.name == metodoStr,
        orElse: () => MetodoPagamentoCompra.outro,
      );
    }

    return ParcelaCompra(
      numero: numVal,
      valorCents: vCents,
      dataVencimento: parseDate(json['dataVencimento']) ?? DateTime.now(),
      status: status,
      dataPagamento: parseDate(json['dataPagamento']),
      pagoPorUid: json['pagoPorUid'] as String?,
      metodoPagamento: metodo,
      comprovanteUrl: json['comprovanteUrl'] as String?,
      comprovantePath: json['comprovantePath'] as String?,
      idempotencyKey: json['idempotencyKey'] as String?,
      observacaoPagamento: json['observacaoPagamento'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'numero': numero,
      'valorCents': valorCents,
      'dataVencimento': dataVencimento.toIso8601String(),
      'status': status.name,
      'dataPagamento': dataPagamento?.toIso8601String(),
      'pagoPorUid': pagoPorUid,
      'metodoPagamento': metodoPagamento?.name,
      'comprovanteUrl': comprovanteUrl,
      'comprovantePath': comprovantePath,
      'idempotencyKey': idempotencyKey,
      'observacaoPagamento': observacaoPagamento,
    };
  }
}
