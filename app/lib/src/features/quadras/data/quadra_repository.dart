import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contracts.dart';
import '../../lotes/data/lote_repository.dart';
import '../../lotes/domain/lote.dart';
import '../domain/quadra.dart';

final quadraRepositoryProvider = Provider<QuadraRepository>((ref) {
  return QuadraRepository(FirebaseFirestore.instance);
});

class QuadraRepository {
  final FirebaseFirestore _firestore;

  QuadraRepository(this._firestore);

  static CollectionReference<Quadra> quadrasCollection(
    FirebaseFirestore firestore,
  ) => firestore
      .collection('quadras')
      .withConverter<Quadra>(
        fromFirestore: (snapshot, _) => Quadra.fromJson(snapshot.data()!),
        toFirestore: (quadra, _) => quadra.toJson(),
      );

  CollectionReference<Quadra> _quadrasRef() => quadrasCollection(_firestore);

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

  Future<void> createQuadraComLotes({
    required Quadra quadra,
    required List<Lote> lotes,
  }) async {
    final operations = <FirestoreBatchWrite>[
      (batch) => batch.set(_quadrasRef().doc(quadra.id), quadra),
    ];
    LoteRepository.appendLotesComEtapasWrites(
      firestore: _firestore,
      operations: operations,
      lotes: lotes,
    );
    await commitFirestoreBatches(_firestore, operations);
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
