import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/quadra.dart';

final quadraRepositoryProvider = Provider<QuadraRepository>((ref) {
  return QuadraRepository(FirebaseFirestore.instance);
});

class QuadraRepository {
  final FirebaseFirestore _firestore;

  QuadraRepository(this._firestore);

  CollectionReference<Quadra> _quadrasRef() => _firestore
      .collection('quadras')
      .withConverter<Quadra>(
        fromFirestore: (snapshot, _) => Quadra.fromJson(snapshot.data()!),
        toFirestore: (quadra, _) => quadra.toJson(),
      );

  Stream<List<Quadra>> watchQuadras(String construtoraId, String loteamentoId) {
    return _quadrasRef()
        .where('construtoraId', isEqualTo: construtoraId)
        .where('loteamentoId', isEqualTo: loteamentoId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<void> createQuadra(Quadra quadra) async {
    final docRef = _quadrasRef().doc(quadra.id);
    await docRef.set(quadra);
  }
}

typedef QuadraParams = ({String construtoraId, String loteamentoId});

final watchQuadrasProvider = StreamProvider.family<List<Quadra>, QuadraParams>((
  ref,
  params,
) {
  final repo = ref.watch(quadraRepositoryProvider);
  return repo.watchQuadras(params.construtoraId, params.loteamentoId);
});
