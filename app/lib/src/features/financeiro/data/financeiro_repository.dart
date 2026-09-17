import '../../../sync/operation_queue.dart';
import '../../../sync/read_cache.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/despesa.dart';

final financeiroRepositoryProvider = Provider<FinanceiroRepository>((ref) {
  return FinanceiroRepository(FirebaseFirestore.instance);
});

class FinanceiroRepository {
  final FirebaseFirestore _firestore;
  final OperationQueue _queue;

  FinanceiroRepository(this._firestore, {OperationQueue? queue})
      : _queue = queue ?? OperationQueue.instance;

  CollectionReference<Despesa> _despesasRef(String construtoraId) => _firestore
      .collection('construtoras')
      .doc(construtoraId)
      .collection('despesas')
      .withConverter<Despesa>(
        fromFirestore: (snapshot, _) => Despesa.fromJson(snapshot.data()!),
        toFirestore: (despesa, _) => despesa.toJson(),
      );

  Stream<List<Despesa>> watchDespesas(String construtoraId) {
    return cachedList(
      'despesas/$construtoraId',
      _despesasRef(construtoraId)
          .orderBy('dataVencimento', descending: false)
          .snapshots(includeMetadataChanges: true)
          .where((snapshot) => !snapshot.metadata.isFromCache)
          .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList()),
      (value) => value.toJson(),
      (value) => Despesa.fromJson(Map<String, dynamic>.from(value)),
    );
  }

  Future<void> createDespesa(Despesa despesa) async {
    await _despesasRef(despesa.construtoraId).doc(despesa.id).set(despesa);
  }

  Future<void> marcarComoPago(
    String construtoraId,
    String despesaId, {
    String? operationId,
  }) async {
    await _queue.enqueue('payExpense', {
      'operationId': operationId ?? 'pay-$despesaId',
      'construtoraId': construtoraId,
      'despesaId': despesaId,
    });
  }
}
