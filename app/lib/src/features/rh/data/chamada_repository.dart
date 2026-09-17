import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../sync/read_cache.dart';
import '../domain/chamada_diaria.dart';

final chamadaRepositoryProvider = Provider<ChamadaRepository>((ref) {
  return ChamadaRepository(FirebaseFirestore.instance);
});

final chamadasStreamProvider = StreamProvider.family<List<ChamadaDiaria>,
    ({String construtoraId, String obraId})>((ref, scope) {
  return ref
      .watch(chamadaRepositoryProvider)
      .watchChamadas(scope.construtoraId, scope.obraId);
});

final chamadaDetailProvider = FutureProvider.family<ChamadaDiaria?,
    ({String construtoraId, String obraId, String chamadaId})>((ref, scope) {
  return ref.watch(chamadaRepositoryProvider).getChamada(
        scope.construtoraId,
        scope.obraId,
        scope.chamadaId,
      );
});

class ChamadaRepository {
  final FirebaseFirestore _firestore;

  ChamadaRepository(this._firestore);

  CollectionReference<ChamadaDiaria> _chamadasRef(
    String construtoraId,
    String obraId,
  ) {
    return _firestore
        .collection('construtoras')
        .doc(construtoraId)
        .collection('obras')
        .doc(obraId)
        .collection('chamadas')
        .withConverter<ChamadaDiaria>(
          fromFirestore: (snapshot, _) =>
              ChamadaDiaria.fromMap(snapshot.data()!, id: snapshot.id),
          toFirestore: (ch, _) => ch.toMap(),
        );
  }

  Stream<List<ChamadaDiaria>> watchChamadas(
    String construtoraId,
    String obraId,
  ) {
    return cachedList(
      'construtoras/$construtoraId/obras/$obraId/chamadas',
      _liveWatchChamadas(construtoraId, obraId),
      (c) => c.toMap(),
      (d) => ChamadaDiaria.fromMap(Map<String, dynamic>.from(d)),
    );
  }

  Stream<List<ChamadaDiaria>> _liveWatchChamadas(
    String construtoraId,
    String obraId,
  ) {
    return _chamadasRef(construtoraId, obraId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<ChamadaDiaria?> getChamada(
    String construtoraId,
    String obraId,
    String chamadaId,
  ) async {
    final doc = await _chamadasRef(construtoraId, obraId).doc(chamadaId).get();
    return doc.data();
  }

  Future<void> saveChamada(ChamadaDiaria chamada) async {
    if (!chamada.isValid) {
      throw ArgumentError(
        'Chamada possui colaboradores com alocações inválidas ou lista vazia.',
      );
    }
    await _chamadasRef(chamada.construtoraId, chamada.obraId)
        .doc(chamada.id)
        .set(chamada, SetOptions(merge: true));
  }

  Future<void> cancelChamada(
    String construtoraId,
    String obraId,
    String chamadaId,
  ) async {
    await _chamadasRef(construtoraId, obraId).doc(chamadaId).update({
      'status': 'cancelada',
      'updatedAt': Timestamp.now(),
    });
  }
}
