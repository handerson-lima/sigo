import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../sync/read_cache.dart';
import '../../almoxarifado/data/almoxarifado_repository.dart';
import '../../almoxarifado/domain/movimentacao.dart';
import '../domain/compra_nf.dart';
import '../domain/item_compra.dart';
import '../domain/parcela_compra.dart';
import '../domain/parcelamento_compras_math.dart';

final comprasRepositoryProvider = Provider<ComprasRepository>((ref) {
  final almoxarifadoRepo = ref.watch(almoxarifadoRepositoryProvider);
  return ComprasRepository(
    FirebaseFirestore.instance,
    FirebaseStorage.instance,
    almoxarifadoRepo,
  );
});

final comprasObraStreamProvider =
    StreamProvider.family<
      List<CompraNf>,
      ({String construtoraId, String obraId})
    >((ref, arg) {
      return ref
          .watch(comprasRepositoryProvider)
          .watchComprasObra(arg.construtoraId, arg.obraId);
    });

final compraDetailsFutureProvider =
    FutureProvider.family<
      CompraNf?,
      ({String construtoraId, String obraId, String compraId})
    >((ref, arg) {
      return ref
          .watch(comprasRepositoryProvider)
          .getCompra(arg.construtoraId, arg.obraId, arg.compraId);
    });

class ComprasRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final AlmoxarifadoRepository? _almoxarifadoRepository;

  ComprasRepository(
    this._firestore, [
    FirebaseStorage? storage,
    this._almoxarifadoRepository,
  ]) : _storage = storage ?? FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> _comprasRef(
    String construtoraId,
    String obraId,
  ) {
    return _firestore
        .collection('construtoras')
        .doc(construtoraId)
        .collection('obras')
        .doc(obraId)
        .collection('compras');
  }

  /// Observa todas as compras da obra com cache offline
  Stream<List<CompraNf>> watchComprasObra(String construtoraId, String obraId) {
    final query = _comprasRef(
      construtoraId,
      obraId,
    ).orderBy('dataEmissao', descending: true);

    return cachedList<CompraNf>(
      'compras/$construtoraId/$obraId',
      query
          .snapshots(includeMetadataChanges: true)
          .where((s) => !s.metadata.isFromCache)
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => CompraNf.fromJson(doc.data()))
                .toList(),
          ),
      (c) => c.toJson(),
      (item) => CompraNf.fromJson(Map<String, dynamic>.from(item)),
    );
  }

  /// Busca uma compra pontual
  Future<CompraNf?> getCompra(
    String construtoraId,
    String obraId,
    String compraId,
  ) async {
    final doc = await _comprasRef(construtoraId, obraId).doc(compraId).get();
    if (!doc.exists || doc.data() == null) return null;
    return CompraNf.fromJson(doc.data()!);
  }

  /// Salva uma nova compra no banco garantindo a invariante matemática
  Future<void> createCompra(CompraNf compra) async {
    if (compra.totalCompraCents <= 0) {
      throw StateError(
        'O valor total da compra deve ser estritamente positivo.',
      );
    }

    if (compra.parcelas.isEmpty) {
      throw StateError('A compra deve conter ao menos uma parcela.');
    }

    final isValid = ParcelamentoComprasMath.validarInvarianteParcelas(
      totalCompraCents: compra.totalCompraCents,
      parcelas: compra.parcelas,
    );
    if (!isValid) {
      final soma = ParcelamentoComprasMath.calcularSomaParcelas(
        compra.parcelas,
      );
      throw StateError(
        'Invariante algébrica violada: soma das parcelas ($soma) != total ($compra.totalCompraCents)',
      );
    }

    await _comprasRef(
      compra.construtoraId,
      compra.obraId,
    ).doc(compra.id).set(compra.toJson());
  }

  /// Atualiza uma compra existente
  Future<void> updateCompra(CompraNf compra) async {
    final docRef = _comprasRef(
      compra.construtoraId,
      compra.obraId,
    ).doc(compra.id);
    final snapshot = await docRef.get();
    if (snapshot.exists) {
      final current = CompraNf.fromJson(snapshot.data()!);
      if (current.status == StatusCompra.pago) {
        throw StateError(
          'Não é permitido alterar uma compra que já foi totalmente liquidada.',
        );
      }
      if (current.status == StatusCompra.cancelado) {
        throw StateError('Não é permitido alterar uma compra cancelada.');
      }
    }

    if (compra.parcelas.isNotEmpty) {
      final isValid = ParcelamentoComprasMath.validarInvarianteParcelas(
        totalCompraCents: compra.totalCompraCents,
        parcelas: compra.parcelas,
      );
      if (!isValid) {
        throw StateError('A soma das parcelas difere do total da compra.');
      }
    }

    await docRef.update(compra.toJson());
  }

  /// Liquidação idempotente de uma parcela específica
  Future<void> liquidarParcela({
    required String construtoraId,
    required String obraId,
    required String compraId,
    required int numeroParcela,
    required String pagoPorUid,
    required MetodoPagamentoCompra metodoPagamento,
    DateTime? dataPagamento,
    String? comprovanteUrl,
    String? comprovantePath,
    String? observacaoPagamento,
    String? operationId,
  }) async {
    final docRef = _comprasRef(construtoraId, obraId).doc(compraId);
    final snapshot = await docRef.get();
    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError('Compra não encontrada.');
    }

    final compra = CompraNf.fromJson(snapshot.data()!);
    if (compra.status == StatusCompra.cancelado) {
      throw StateError('Não é possível liquidar parcela de compra cancelada.');
    }

    final dtPgto = dataPagamento ?? DateTime.now();
    final opId =
        operationId ??
        'pay-compra-$compraId-$numeroParcela-${DateTime.now().millisecondsSinceEpoch}';

    final parcelasAtualizadas = compra.parcelas.map((p) {
      if (p.numero == numeroParcela) {
        return p.copyWith(
          status: StatusParcelaCompra.pago,
          dataPagamento: dtPgto,
          pagoPorUid: pagoPorUid,
          metodoPagamento: metodoPagamento,
          comprovanteUrl: comprovanteUrl ?? p.comprovanteUrl,
          comprovantePath: comprovantePath ?? p.comprovantePath,
          observacaoPagamento: observacaoPagamento ?? p.observacaoPagamento,
          idempotencyKey: opId,
        );
      }
      return p;
    }).toList();

    // Determina o novo status da compra
    final todasPagas = parcelasAtualizadas.every(
      (p) => p.status == StatusParcelaCompra.pago,
    );
    final algumaPaga = parcelasAtualizadas.any(
      (p) => p.status == StatusParcelaCompra.pago,
    );

    final novoStatus = todasPagas
        ? StatusCompra.pago
        : (algumaPaga ? StatusCompra.parcial : StatusCompra.aberto);

    final atualizada = compra.copyWith(
      status: novoStatus,
      parcelas: parcelasAtualizadas,
      atualizadoPorUid: pagoPorUid,
      updatedAt: DateTime.now(),
    );

    await docRef.update(atualizada.toJson());
  }

  /// Recebimento físico de materiais gerando movimentação no Almoxarifado
  Future<void> receberItensNoEstoque({
    required String construtoraId,
    required String obraId,
    required String compraId,
    required Map<String, double> quantidadesRecebidasPorItem,
    required String responsavelId,
  }) async {
    final docRef = _comprasRef(construtoraId, obraId).doc(compraId);
    final snapshot = await docRef.get();
    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError('Compra não encontrada.');
    }

    final compra = CompraNf.fromJson(snapshot.data()!);
    if (compra.status == StatusCompra.cancelado) {
      throw StateError('Não é possível receber materiais de compra cancelada.');
    }

    final itensAtualizados = <ItemCompraNf>[];

    for (final item in compra.itens) {
      final qtdRecebidaAgora = quantidadesRecebidasPorItem[item.id] ?? 0.0;
      if (qtdRecebidaAgora > 0) {
        // Registra movimentação de entrada no Almoxarifado
        if (_almoxarifadoRepository != null) {
          final movId =
              'mov-compra-$compraId-${item.id}-${DateTime.now().millisecondsSinceEpoch}';
          final mov = Movimentacao(
            id: movId,
            materialId: item.materialId,
            type: MovimentacaoType.entrada,
            quantity: qtdRecebidaAgora,
            date: DateTime.now(),
            responsavelId: responsavelId,
            obraId: obraId,
            observacao:
                'Entrada por compra NF ${compra.numeroNf} - ${compra.fornecedorNome}',
            evidence: compra.anexoNfUrl,
            nfNumber: compra.numeroNf,
            fornecedor: compra.fornecedorNome,
            valorItensCentavos: (qtdRecebidaAgora * item.valorUnitarioCents)
                .round(),
            custoUnitarioCentavos: item.valorUnitarioCents,
            custoTotalCentavos: (qtdRecebidaAgora * item.valorUnitarioCents)
                .round(),
          );
          await _almoxarifadoRepository.registrarMovimentacao(
            construtoraId,
            mov,
          );
        }

        final novaQtdRecebida = item.quantidadeRecebida + qtdRecebidaAgora;
        itensAtualizados.add(
          item.copyWith(quantidadeRecebida: novaQtdRecebida),
        );
      } else {
        itensAtualizados.add(item);
      }
    }

    // Calcula status de recebimento
    final tudoRecebido = itensAtualizados.every((i) => i.isTotalmenteRecebido);
    final algoRecebido = itensAtualizados.any((i) => i.quantidadeRecebida > 0);

    final statusRec = tudoRecebido
        ? StatusRecebimentoCompra.recebido
        : (algoRecebido
              ? StatusRecebimentoCompra.parcial
              : StatusRecebimentoCompra.pendente);

    final atualizada = compra.copyWith(
      itens: itensAtualizados,
      statusRecebimento: statusRec,
      dataRecebimento: tudoRecebido ? DateTime.now() : compra.dataRecebimento,
      atualizadoPorUid: responsavelId,
      updatedAt: DateTime.now(),
    );

    await docRef.update(atualizada.toJson());
  }

  /// Cancelamento auditado de compra
  Future<void> cancelarCompra({
    required String construtoraId,
    required String obraId,
    required String compraId,
    required String canceladoPorUid,
    required String motivoCancelamento,
  }) async {
    if (motivoCancelamento.trim().length < 10) {
      throw ArgumentError(
        'O motivo do cancelamento deve conter no mínimo 10 caracteres.',
      );
    }

    final docRef = _comprasRef(construtoraId, obraId).doc(compraId);
    final snapshot = await docRef.get();
    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError('Compra não encontrada.');
    }

    final compra = CompraNf.fromJson(snapshot.data()!);

    // Regra de Integridade: Não pode cancelar se houver parcelas pagas
    final possuiParcelaPaga = compra.parcelas.any(
      (p) => p.status == StatusParcelaCompra.pago,
    );
    if (possuiParcelaPaga) {
      throw StateError(
        'Não é possível cancelar uma compra com parcelas já pagas. Estorne os pagamentos primeiro.',
      );
    }

    final parcelasCanceladas = compra.parcelas.map((p) {
      return p.copyWith(status: StatusParcelaCompra.cancelado);
    }).toList();

    final atualizada = compra.copyWith(
      status: StatusCompra.cancelado,
      parcelas: parcelasCanceladas,
      motivoCancelamento: motivoCancelamento.trim(),
      canceladoPorUid: canceladoPorUid,
      dataCancelamento: DateTime.now(),
      atualizadoPorUid: canceladoPorUid,
      updatedAt: DateTime.now(),
    );

    await docRef.update(atualizada.toJson());
  }

  /// Upload de comprovante de pagamento para o Storage
  Future<({String url, String path})> uploadComprovante({
    required String construtoraId,
    required String obraId,
    required String compraId,
    required int numeroParcela,
    required Uint8List fileBytes,
    required String extension,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path =
        'construtoras/$construtoraId/obras/$obraId/compras/$compraId/p${numeroParcela}_$timestamp.$extension';
    final ref = _storage.ref(path);

    final contentType = extension.toLowerCase() == 'pdf'
        ? 'application/pdf'
        : 'image/${extension.toLowerCase()}';

    await ref.putData(fileBytes, SettableMetadata(contentType: contentType));
    final url = await ref.getDownloadURL();
    return (url: url, path: path);
  }

  /// Upload do DANFE / Nota Fiscal
  Future<({String url, String path})> uploadAnexoNf({
    required String construtoraId,
    required String obraId,
    required String compraId,
    required Uint8List fileBytes,
    required String extension,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path =
        'construtoras/$construtoraId/obras/$obraId/compras/$compraId/danfe_$timestamp.$extension';
    final ref = _storage.ref(path);

    final contentType = extension.toLowerCase() == 'pdf'
        ? 'application/pdf'
        : 'image/${extension.toLowerCase()}';

    await ref.putData(fileBytes, SettableMetadata(contentType: contentType));
    final url = await ref.getDownloadURL();
    return (url: url, path: path);
  }
}
