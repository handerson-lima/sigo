import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/equipe.dart';

final equipeRepositoryProvider = Provider<EquipeRepository>((ref) {
  return EquipeRepository(FirebaseFirestore.instance);
});

class EquipeRepository {
  final FirebaseFirestore _firestore;

  EquipeRepository(this._firestore);

  CollectionReference<Equipe> _equipesRef() =>
      _firestore
          .collection('equipes')
          .withConverter<Equipe>(
            fromFirestore: (snapshot, _) => Equipe.fromJson(snapshot.data() ?? {}),
            toFirestore: (equipe, _) => equipe.toJson(),
          );

  Stream<List<Equipe>> watchEquipes(
    String construtoraId,
    String loteamentoId,
    String quadraId,
    String loteId,
    String etapaId,
  ) {
    return _equipesRef()
        .where('construtoraId', isEqualTo: construtoraId)
        .where('loteamentoId', isEqualTo: loteamentoId)
        .where('quadraId', isEqualTo: quadraId)
        .where('loteId', isEqualTo: loteId)
        .where('etapaId', isEqualTo: etapaId)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<void> createEquipe(Equipe equipe) async {
    final docRef = _equipesRef().doc(equipe.id);
    await docRef.set(equipe);
  }
}
typedef EquipeParams = ({String construtoraId, String loteamentoId, String quadraId, String loteId, String etapaId});

final watchEquipesProvider = StreamProvider.family<List<Equipe>, EquipeParams>((ref, params) {
  final repo = ref.watch(equipeRepositoryProvider);
  return repo.watchEquipes(
    params.construtoraId,
    params.loteamentoId,
    params.quadraId,
    params.loteId,
    params.etapaId,
  );
});
