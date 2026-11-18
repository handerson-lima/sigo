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
        fromFirestore: (snapshot, _) {
          final data = Map<String, dynamic>.from(snapshot.data()!);
          data['id'] ??= snapshot.id;
          return Quadra.fromJson(data).copyWith(id: snapshot.id);
        },
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

  Future<void> updateQuadra(Quadra quadra) async {
    final updated = quadra.copyWith(updatedAt: DateTime.now());
    await _quadrasRef().doc(updated.id).update(updated.toJson());
  }

  Future<void> createQuadraComLotes({
    required Quadra quadra,
    required List<Lote> lotes,
  }) async {
    if (quadra.id.trim().isEmpty) {
      throw ArgumentError.value(quadra.id, 'quadra.id', 'ID da quadra inválido');
    }
    if (quadra.construtoraId.trim().isEmpty) {
      throw ArgumentError.value(
        quadra.construtoraId,
        'quadra.construtoraId',
        'construtoraId da quadra inválido',
      );
    }
    if (quadra.loteamentoId.trim().isEmpty) {
      throw ArgumentError.value(
        quadra.loteamentoId,
        'quadra.loteamentoId',
        'loteamentoId da quadra inválido',
      );
    }
    final operations = <FirestoreBatchWrite>[
      (batch) => batch.set(_quadrasRef().doc(quadra.id), quadra),
    ];
    LoteRepository.appendLotesComEtapasWrites(
      firestore: _firestore,
      operations: operations,
      lotes: lotes,
      expectedConstrutoraId: quadra.construtoraId,
      expectedLoteamentoId: quadra.loteamentoId,
      expectedQuadraId: quadra.id,
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
