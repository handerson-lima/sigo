import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contracts.dart';
import '../../lotes/data/lote_repository.dart';
import '../../lotes/domain/lote.dart';
import '../../quadras/data/quadra_repository.dart';
import '../../quadras/domain/quadra.dart';
import '../domain/loteamento.dart';

final loteamentoRepositoryProvider = Provider<LoteamentoRepository>((ref) {
  return LoteamentoRepository(FirebaseFirestore.instance);
});

class LoteamentoRepository {
  final FirebaseFirestore _firestore;

  LoteamentoRepository(this._firestore);

  CollectionReference<Loteamento> _loteamentosRef() => _firestore
      .collection('loteamentos')
      .withConverter<Loteamento>(
        fromFirestore: (snapshot, _) => Loteamento.fromJson(snapshot.data()!),
        toFirestore: (loteamento, _) => loteamento.toJson(),
      );

  Stream<List<Loteamento>> watchLoteamentos(String construtoraId) {
    return _loteamentosRef()
        .where('construtoraId', isEqualTo: construtoraId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<void> createLoteamento(Loteamento loteamento) async {
    final docRef = _loteamentosRef().doc(loteamento.id);
    await docRef.set(loteamento);
  }

  Future<void> updateLoteamento(Loteamento loteamento) async {
    final updated = loteamento.copyWith(updatedAt: DateTime.now());
    await _loteamentosRef().doc(updated.id).update(updated.toJson());
  }

  Future<void> createLoteamentoEmMassa({
    required Loteamento loteamento,
    required List<Quadra> quadras,
    required List<Lote> lotes,
  }) async {
    final quadrasRef = QuadraRepository.quadrasCollection(_firestore);
    final operations = <FirestoreBatchWrite>[
      (batch) => batch.set(_loteamentosRef().doc(loteamento.id), loteamento),
      for (final quadra in quadras)
        (batch) => batch.set(quadrasRef.doc(quadra.id), quadra),
    ];
    LoteRepository.appendLotesComEtapasWrites(
      firestore: _firestore,
      operations: operations,
      lotes: lotes,
    );
    await commitFirestoreBatches(_firestore, operations);
  }
}

typedef LoteamentoParams = ({String construtoraId});

final watchLoteamentosProvider =
    StreamProvider.family<List<Loteamento>, LoteamentoParams>((ref, params) {
      final repo = ref.watch(loteamentoRepositoryProvider);
      return repo.watchLoteamentos(params.construtoraId);
    });
