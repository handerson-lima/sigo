import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/setor.dart';

final setorRepositoryProvider = Provider<SetorRepository>((ref) {
  return SetorRepository(FirebaseFirestore.instance);
});

class SetorRepository {
  final FirebaseFirestore _firestore;

  SetorRepository(this._firestore);

  CollectionReference<Setor> _setoresRef(String construtoraId, String loteamentoId, String quadraId, String loteId) =>
      _firestore
          .collection('construtoras/$construtoraId/loteamentos/$loteamentoId/quadras/$quadraId/lotes/$loteId/setores')
          .withConverter<Setor>(
            fromFirestore: (snapshot, _) => Setor.fromJson(snapshot.data()!),
            toFirestore: (setor, _) => setor.toJson(),
          );

  Stream<List<Setor>> watchSetores(String construtoraId, String loteamentoId, String quadraId, String loteId) {
    return _setoresRef(construtoraId, loteamentoId, quadraId, loteId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
}
