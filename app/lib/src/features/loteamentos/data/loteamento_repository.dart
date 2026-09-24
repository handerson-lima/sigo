import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/loteamento.dart';

final loteamentoRepositoryProvider = Provider<LoteamentoRepository>((ref) {
  return LoteamentoRepository(FirebaseFirestore.instance);
});

class LoteamentoRepository {
  final FirebaseFirestore _firestore;

  LoteamentoRepository(this._firestore);

  CollectionReference<Loteamento> _loteamentosRef(String construtoraId) =>
      _firestore
          .collection('construtoras/$construtoraId/loteamentos')
          .withConverter<Loteamento>(
            fromFirestore: (snapshot, _) => Loteamento.fromJson(snapshot.data()!),
            toFirestore: (loteamento, _) => loteamento.toJson(),
          );

  Stream<List<Loteamento>> watchLoteamentos(String construtoraId) {
    return _loteamentosRef(construtoraId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<void> createLoteamento(Loteamento loteamento) async {
    final docRef = _loteamentosRef(loteamento.construtoraId).doc(loteamento.id);
    await docRef.set(loteamento);
  }
}

typedef LoteamentoParams = ({String construtoraId});

final watchLoteamentosProvider =
    StreamProvider.family<List<Loteamento>, LoteamentoParams>((ref, params) {
  final repo = ref.watch(loteamentoRepositoryProvider);
  return repo.watchLoteamentos(params.construtoraId);
});
