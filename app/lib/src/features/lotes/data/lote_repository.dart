import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/lote.dart';

final loteRepositoryProvider = Provider<LoteRepository>((ref) {
  return LoteRepository(FirebaseFirestore.instance);
});

class LoteRepository {
  final FirebaseFirestore _firestore;

  LoteRepository(this._firestore);

  CollectionReference<Lote> _lotesRef() =>
      _firestore
          .collection('lotes')
          .withConverter<Lote>(
            fromFirestore: (snapshot, _) => Lote.fromJson(snapshot.data()!),
            toFirestore: (lote, _) => lote.toJson(),
          );

  Stream<List<Lote>> watchLotes(String construtoraId, String loteamentoId, String quadraId) {
    return _lotesRef()
        .where('construtoraId', isEqualTo: construtoraId)
        .where('loteamentoId', isEqualTo: loteamentoId)
        .where('quadraId', isEqualTo: quadraId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<void> createLote(Lote lote) async {
    final docRef = _lotesRef().doc(lote.id);
    await docRef.set(lote);
  }
}

typedef LoteParams = ({
  String construtoraId,
  String loteamentoId,
  String quadraId,
});

final watchLotesProvider =
    StreamProvider.family<List<Lote>, LoteParams>((ref, params) {
  final repo = ref.watch(loteRepositoryProvider);
  return repo.watchLotes(
    params.construtoraId,
    params.loteamentoId,
    params.quadraId,
  );
});
