import '../../../sync/read_cache.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/lote.dart';

final loteRepositoryProvider = Provider<LoteRepository>((ref) {
  return LoteRepository(FirebaseFirestore.instance);
});

class LoteRepository {
  final FirebaseFirestore _firestore;

  LoteRepository(this._firestore);

  CollectionReference<Lote> _lotesRef(String construtoraId, String obraId) =>
      _firestore
          .collection('construtoras')
          .doc(construtoraId)
          .collection('obras')
          .doc(obraId)
          .collection('lotes')
          .withConverter<Lote>(
            fromFirestore: (snapshot, _) => Lote.fromJson(snapshot.data()!),
            toFirestore: (lote, _) => lote.toJson(),
          );

  Stream<List<Lote>> watchLotes(String construtoraId, String obraId) =>
      cachedList(
        'construtoras/$construtoraId/obras/$obraId/lotes',
        _livewatchLotes(construtoraId, obraId),
        (m) => m.toJson(),
        (d) => Lote.fromJson(Map<String, dynamic>.from(d)),
      );

  Stream<List<Lote>> _livewatchLotes(String construtoraId, String obraId) {
    return _lotesRef(construtoraId, obraId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => doc.data()).toList();
        });
  }

  Future<void> createLote(Lote lote) async {
    final docRef = _lotesRef(lote.construtoraId, lote.obraId).doc(lote.id);
    await docRef.set(lote);
    await docRef.snapshots().firstWhere((snap) => !snap.metadata.hasPendingWrites);
  }

  Future<void> updatePhase(
    String construtoraId,
    String obraId,
    String loteId,
    String newPhase,
  ) async {
    await _lotesRef(
      construtoraId,
      obraId,
    ).doc(loteId).update({'phase': newPhase});
  }

  Future<void> updateStatus(
    String construtoraId,
    String obraId,
    String loteId,
    LoteStatus newStatus,
  ) async {
    await _lotesRef(construtoraId, obraId).doc(loteId).update({
      'status': newStatus.name, // O JsonSerializable converte o Enum para string baseando no nome.
    });
  }
}
