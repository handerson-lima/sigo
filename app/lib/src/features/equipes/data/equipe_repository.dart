import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/equipe.dart';

final equipeRepositoryProvider = Provider<EquipeRepository>((ref) {
  return EquipeRepository(FirebaseFirestore.instance);
});

class EquipeRepository {
  final FirebaseFirestore _firestore;

  EquipeRepository(this._firestore);

  CollectionReference<Equipe> _equipesRef(String construtoraId, String loteamentoId, String quadraId, String loteId, String setorId) =>
      _firestore
          .collection('construtoras/$construtoraId/loteamentos/$loteamentoId/quadras/$quadraId/lotes/$loteId/setores/$setorId/equipes')
          .withConverter<Equipe>(
            fromFirestore: (snapshot, _) => Equipe.fromJson(snapshot.data()!),
            toFirestore: (equipe, _) => equipe.toJson(),
          );

  Stream<List<Equipe>> watchEquipes(String construtoraId, String loteamentoId, String quadraId, String loteId, String setorId) {
    return _equipesRef(construtoraId, loteamentoId, quadraId, loteId, setorId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
}
