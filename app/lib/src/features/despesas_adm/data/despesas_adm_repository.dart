import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../sync/read_cache.dart';
import '../domain/despesa_adm.dart';
import '../domain/parcelamento_math.dart';

final despesasAdmRepositoryProvider = Provider<DespesasAdmRepository>((ref) {
  return DespesasAdmRepository(
    FirebaseFirestore.instance,
    FirebaseStorage.instance,
  );
});

final despesasObraStreamProvider = StreamProvider.family<
    List<DespesaAdm>,
    ({String construtoraId, String obraId})>((ref, arg) {
  return ref
      .watch(despesasAdmRepositoryProvider)
      .watchDespesasObra(arg.construtoraId, arg.obraId);
});

final despesaDetailsFutureProvider = FutureProvider.family<
    DespesaAdm?,
    ({
      String construtoraId,
      String obraId,
      String despesaId,
    })>((ref, arg) {
  return ref.watch(despesasAdmRepositoryProvider).getDespesa(
        arg.construtoraId,
        arg.obraId,
        arg.despesaId,
      );
});

class DespesasAdmRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  DespesasAdmRepository(
    this._firestore, [
    FirebaseStorage? storage,
  ])  : _storage = storage ?? FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> _despesasRef(
    String construtoraId,
    String obraId,
  ) {
    return _firestore
        .collection('construtoras')
        .doc(construtoraId)
        .collection('obras')
        .doc(obraId)
        .collection('despesas_adm');
  }

  /// Observa todas as despesas da obra com cache offline
  Stream<List<DespesaAdm>> watchDespesasObra(
    String construtoraId,
    String obraId,
  ) {
    final query = _despesasRef(construtoraId, obraId)
        .orderBy('dataVencimento', descending: false);

    return cachedList<DespesaAdm>(
      'despesas_adm/$construtoraId/$obraId',
      query
          .snapshots(includeMetadataChanges: true)
          .where((s) => !s.metadata.isFromCache)
          .map((snapshot) => snapshot.docs
              .map((doc) => DespesaAdm.fromJson(doc.data()))
              .toList()),
      (d) => d.toJson(),
      (item) => DespesaAdm.fromJson(Map<String, dynamic>.from(item)),
    );
  }

  /// Busca uma despesa específica
  Future<DespesaAdm?> getDespesa(
    String construtoraId,
    String obraId,
    String despesaId,
  ) async {
    final doc =
        await _despesasRef(construtoraId, obraId).doc(despesaId).get();
    if (!doc.exists || doc.data() == null) return null;
    return DespesaAdm.fromJson(doc.data()!);
  }

  /// Cadastra uma nova despesa garantindo as invariantes
  Future<void> createDespesa(DespesaAdm despesa) async {
    if (despesa.isParcelado && despesa.parcelas.isNotEmpty) {
      final isValid = ParcelamentoMath.validarInvarianteParcelas(
        totalCents: despesa.valorTotalCents,
        parcelas: despesa.parcelas,
      );
      if (!isValid) {
        final soma = ParcelamentoMath.calcularSomaParcelas(despesa.parcelas);
        throw StateError(
          'Invariante de parcelamento violada: soma das parcelas ($soma) != total ($despesa.valorTotalCents)',
        );
      }
    }

    await _despesasRef(despesa.construtoraId, despesa.obraId)
        .doc(despesa.id)
        .set(despesa.toJson());
  }

  /// Atualiza os dados de uma despesa em aberto
  Future<void> updateDespesa(DespesaAdm despesa) async {
    final docRef = _despesasRef(despesa.construtoraId, despesa.obraId)
        .doc(despesa.id);

    final snapshot = await docRef.get();
    if (snapshot.exists) {
      final current = DespesaAdm.fromJson(snapshot.data()!);
      if (current.status == StatusDespesaAdm.pago) {
        throw StateError(
          'Não é permitido alterar uma despesa que já foi liquidada.',
        );
      }
    }

    if (despesa.isParcelado && despesa.parcelas.isNotEmpty) {
      final isValid = ParcelamentoMath.validarInvarianteParcelas(
        totalCents: despesa.valorTotalCents,
        parcelas: despesa.parcelas,
      );
      if (!isValid) {
        throw StateError('A soma das parcelas difere do valor total.');
      }
    }

    await docRef.update(despesa.toJson());
  }

  /// Quitação/Liquidação idempotente de uma despesa
  Future<void> liquidarDespesa({
    required String construtoraId,
    required String obraId,
    required String despesaId,
    required String pagoPorUid,
    required MetodoPagamento metodoPagamento,
    DateTime? dataPagamento,
    String? comprovanteUrl,
    String? comprovantePath,
    String? operationId,
  }) async {
    final opId = operationId ??
        'pay-adm-$despesaId-${DateTime.now().millisecondsSinceEpoch}';

    final docRef = _despesasRef(construtoraId, obraId).doc(despesaId);
    final snapshot = await docRef.get();
    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError('Despesa não encontrada.');
    }

    final despesa = DespesaAdm.fromJson(snapshot.data()!);
    if (despesa.status == StatusDespesaAdm.pago) {
      // Já liquidada — idempotência atingida
      return;
    }
    if (despesa.status == StatusDespesaAdm.cancelado) {
      throw StateError('Não é possível liquidar uma despesa cancelada.');
    }

    final dtPgto = dataPagamento ?? DateTime.now();

    // Se a despesa for parcelada, marca todas as parcelas pendentes como pagas
    final parcelasAtualizadas = despesa.parcelas.map((p) {
      if (p.status == StatusDespesaAdm.pago) return p;
      return p.copyWith(
        status: StatusDespesaAdm.pago,
        dataPagamento: dtPgto,
        pagoPorUid: pagoPorUid,
        metodoPagamento: metodoPagamento,
        comprovanteUrl: comprovanteUrl ?? p.comprovanteUrl,
        comprovantePath: comprovantePath ?? p.comprovantePath,
        idempotencyKey: opId,
      );
    }).toList();

    final atualizada = despesa.copyWith(
      status: StatusDespesaAdm.pago,
      dataPagamento: dtPgto,
      pagoPorUid: pagoPorUid,
      metodoPagamento: metodoPagamento,
      comprovanteUrl: comprovanteUrl ?? despesa.comprovanteUrl,
      comprovantePath: comprovantePath ?? despesa.comprovantePath,
      parcelas: parcelasAtualizadas,
      updatedAt: DateTime.now(),
    );

    await docRef.update(atualizada.toJson());
  }

  /// Liquidação idempotente de uma parcela específica
  Future<void> liquidarParcela({
    required String construtoraId,
    required String obraId,
    required String despesaId,
    required int numeroParcela,
    required String pagoPorUid,
    required MetodoPagamento metodoPagamento,
    DateTime? dataPagamento,
    String? comprovanteUrl,
    String? comprovantePath,
    String? operationId,
  }) async {
    final docRef = _despesasRef(construtoraId, obraId).doc(despesaId);
    final snapshot = await docRef.get();
    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError('Despesa não encontrada.');
    }

    final despesa = DespesaAdm.fromJson(snapshot.data()!);
    if (despesa.status == StatusDespesaAdm.cancelado) {
      throw StateError('Não é possível liquidar parcela de despesa cancelada.');
    }

    final dtPgto = dataPagamento ?? DateTime.now();
    final opId = operationId ??
        'pay-parcela-$despesaId-$numeroParcela-${DateTime.now().millisecondsSinceEpoch}';

    final parcelasAtualizadas = despesa.parcelas.map((p) {
      if (p.numero == numeroParcela) {
        return p.copyWith(
          status: StatusDespesaAdm.pago,
          dataPagamento: dtPgto,
          pagoPorUid: pagoPorUid,
          metodoPagamento: metodoPagamento,
          comprovanteUrl: comprovanteUrl ?? p.comprovanteUrl,
          comprovantePath: comprovantePath ?? p.comprovantePath,
          idempotencyKey: opId,
        );
      }
      return p;
    }).toList();

    // Se todas as parcelas estiverem pagas, o título todo passa a ser 'pago'
    final todasPagas = parcelasAtualizadas
        .every((p) => p.status == StatusDespesaAdm.pago);

    final atualizada = despesa.copyWith(
      status: todasPagas ? StatusDespesaAdm.pago : StatusDespesaAdm.pendente,
      dataPagamento: todasPagas ? dtPgto : despesa.dataPagamento,
      pagoPorUid: todasPagas ? pagoPorUid : despesa.pagoPorUid,
      metodoPagamento: todasPagas ? metodoPagamento : despesa.metodoPagamento,
      comprovanteUrl: todasPagas
          ? (comprovanteUrl ?? despesa.comprovanteUrl)
          : despesa.comprovanteUrl,
      parcelas: parcelasAtualizadas,
      updatedAt: DateTime.now(),
    );

    await docRef.update(atualizada.toJson());
  }

  /// Cancela uma despesa com justificativa formal obrigatória
  Future<void> cancelarDespesa({
    required String construtoraId,
    required String obraId,
    required String despesaId,
    required String motivo,
    required String canceladoPorUid,
  }) async {
    if (motivo.trim().length < 10) {
      throw ArgumentError(
        'A justificativa de cancelamento deve ter pelo menos 10 caracteres.',
      );
    }

    final docRef = _despesasRef(construtoraId, obraId).doc(despesaId);
    final snapshot = await docRef.get();
    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError('Despesa não encontrada.');
    }

    final despesa = DespesaAdm.fromJson(snapshot.data()!);
    if (despesa.status == StatusDespesaAdm.pago) {
      throw StateError('Não é permitido cancelar uma despesa já liquidada.');
    }

    final parcelasCanceladas = despesa.parcelas.map((p) {
      if (p.status == StatusDespesaAdm.pago) return p;
      return p.copyWith(status: StatusDespesaAdm.cancelado);
    }).toList();

    final cancelada = despesa.copyWith(
      status: StatusDespesaAdm.cancelado,
      motivoCancelamento: motivo.trim(),
      canceladoPorUid: canceladoPorUid,
      dataCancelamento: DateTime.now(),
      parcelas: parcelasCanceladas,
      updatedAt: DateTime.now(),
    );

    await docRef.update(cancelada.toJson());
  }

  /// Upload de comprovante fiscal/bancário em PDF ou Imagem para o Storage
  Future<({String url, String path, String nome})> uploadComprovante({
    required String construtoraId,
    required String obraId,
    required String despesaId,
    required String nomeArquivo,
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (bytes.isEmpty) {
      throw ArgumentError('Arquivo vazio.');
    }
    if (bytes.lengthInBytes > 10 * 1024 * 1024) {
      throw ArgumentError('O arquivo excede o limite máximo permitido de 10 MB.');
    }

    final allowedTypes = [
      'application/pdf',
      'image/jpeg',
      'image/png',
      'image/webp',
    ];
    if (!allowedTypes.contains(contentType.toLowerCase())) {
      throw ArgumentError('Formato de arquivo não permitido: $contentType');
    }

    final cleanFileName =
        nomeArquivo.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath =
        'construtoras/$construtoraId/obras/$obraId/despesas_adm/$despesaId/${timestamp}_$cleanFileName';

    final ref = _storage.ref().child(storagePath);
    final uploadTask = await ref.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'despesaId': despesaId,
          'obraId': obraId,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      ),
    );

    final downloadUrl = await uploadTask.ref.getDownloadURL();

    return (
      url: downloadUrl,
      path: storagePath,
      nome: cleanFileName,
    );
  }
}
