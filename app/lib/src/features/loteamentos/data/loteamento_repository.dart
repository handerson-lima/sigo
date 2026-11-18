import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contracts.dart';
import '../../lotes/data/lote_repository.dart';
import '../../lotes/domain/lote.dart';
import '../../quadras/data/quadra_repository.dart';
import '../../quadras/domain/quadra.dart';
import '../domain/loteamento.dart';

final loteamentoRepositoryProvider = Provider<LoteamentoRepository>((ref) {
  return LoteamentoRepository(FirebaseFirestore.instance);
});

class LoteamentoRepository {
  final FirebaseFirestore _firestore;

  LoteamentoRepository(this._firestore);

  CollectionReference<Loteamento> _loteamentosRef() => _firestore
      .collection('loteamentos')
      .withConverter<Loteamento>(
        fromFirestore: (snapshot, _) {
          final data = Map<String, dynamic>.from(snapshot.data()!);
          data['id'] ??= snapshot.id;
          return Loteamento.fromJson(data).copyWith(id: snapshot.id);
        },
        toFirestore: (loteamento, _) => loteamento.toJson(),
      );

  Stream<List<Loteamento>> watchLoteamentos(String construtoraId) {
    return _loteamentosRef()
        .where('construtoraId', isEqualTo: construtoraId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<void> createLoteamento(Loteamento loteamento) async {
    final docRef = _loteamentosRef().doc(loteamento.id);
    await docRef.set(loteamento);
  }

  Future<void> updateLoteamento(Loteamento loteamento) async {
    final updated = loteamento.copyWith(updatedAt: DateTime.now());
    await _loteamentosRef().doc(updated.id).update(updated.toJson());
  }

  Future<void> createLoteamentoEmMassa({
    required Loteamento loteamento,
    required List<Quadra> quadras,
    required List<Lote> lotes,
  }) async {
    if (loteamento.id.trim().isEmpty) {
      throw ArgumentError.value(
        loteamento.id,
        'loteamento.id',
        'ID do loteamento inválido',
      );
    }
    if (loteamento.construtoraId.trim().isEmpty) {
      throw ArgumentError.value(
        loteamento.construtoraId,
        'loteamento.construtoraId',
        'construtoraId do loteamento inválido',
      );
    }
    final quadraIds = <String>{};
    for (final quadra in quadras) {
      if (quadra.id.trim().isEmpty) {
        throw ArgumentError.value(quadra.id, 'quadra.id', 'ID da quadra inválido');
      }
      if (!quadraIds.add(quadra.id)) {
        throw ArgumentError.value(
          quadra.id,
          'quadras',
          'Quadra duplicada no loteamento em massa: ${quadra.id}',
        );
      }
      if (quadra.construtoraId != loteamento.construtoraId) {
        throw ArgumentError.value(
          quadra.construtoraId,
          'quadra.construtoraId',
          'Quadra ${quadra.id} possui construtoraId divergente',
        );
      }
      if (quadra.loteamentoId != loteamento.id) {
        throw ArgumentError.value(
          quadra.loteamentoId,
          'quadra.loteamentoId',
          'Quadra ${quadra.id} possui loteamentoId divergente',
        );
      }
    }

    final quadrasRef = QuadraRepository.quadrasCollection(_firestore);
    final operations = <FirestoreBatchWrite>[
      (batch) => batch.set(_loteamentosRef().doc(loteamento.id), loteamento),
      for (final quadra in quadras)
        (batch) => batch.set(quadrasRef.doc(quadra.id), quadra),
    ];
    LoteRepository.appendLotesComEtapasWrites(
      firestore: _firestore,
      operations: operations,
      lotes: lotes,
      expectedConstrutoraId: loteamento.construtoraId,
      expectedLoteamentoId: loteamento.id,
      allowedQuadraIds: quadraIds,
    );
    await commitFirestoreBatches(_firestore, operations);
  }
}

typedef LoteamentoParams = ({String construtoraId});

final watchLoteamentosProvider =
    StreamProvider.family<List<Loteamento>, LoteamentoParams>((ref, params) {
      final repo = ref.watch(loteamentoRepositoryProvider);
      return repo.watchLoteamentos(params.construtoraId);
    });
