import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/lote.dart';

final loteRepositoryProvider = Provider<LoteRepository>((ref) {
  return LoteRepository(FirebaseFirestore.instance);
});

class LoteRepository {
  final FirebaseFirestore _firestore;

  LoteRepository(this._firestore);

  CollectionReference<Lote> _lotesRef(String construtoraId, String loteamentoId, String quadraId) =>
      _firestore
          .collection('construtoras/$construtoraId/loteamentos/$loteamentoId/quadras/$quadraId/lotes')
          .withConverter<Lote>(
            fromFirestore: (snapshot, _) => Lote.fromJson(snapshot.data()!),
            toFirestore: (lote, _) => lote.toJson(),
          );

  Stream<List<Lote>> watchLotes(String construtoraId, String loteamentoId, String quadraId) {
    return _lotesRef(construtoraId, loteamentoId, quadraId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<void> createLote(Lote lote) async {
    final docRef = _lotesRef(lote.construtoraId, lote.loteamentoId, lote.quadraId).doc(lote.id);
    await docRef.set(lote);
  }
}
