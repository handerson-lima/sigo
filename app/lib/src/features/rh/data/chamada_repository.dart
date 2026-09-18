import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../sync/read_cache.dart';
import '../domain/chamada_diaria.dart';

import '../domain/rh_invariante_validator.dart';

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

  Future<ChamadaDiaria?> findChamadaByDate(
    String construtoraId,
    String obraId,
    String date,
  ) async {
    final query = await _chamadasRef(construtoraId, obraId)
        .where('date', isEqualTo: date)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return query.docs.first.data();
  }

  Future<List<({String obraId, String date, ApontamentoTrabalhador apontamento})>>
      findCrossObraApontamentos({
    required String construtoraId,
    required String currentObraId,
    required String date,
  }) async {
    final snapshot = await _firestore
        .collectionGroup('chamadas')
        .where('construtoraId', isEqualTo: construtoraId)
        .where('date', isEqualTo: date)
        .get();

    final result =
        <({String obraId, String date, ApontamentoTrabalhador apontamento})>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final chObraId = data['obraId'] as String? ?? '';
      final status = data['status'] as String? ?? '';
      if (chObraId == currentObraId || status == 'cancelada') continue;

      final chamada = ChamadaDiaria.fromMap(data, id: doc.id);
      for (final worker in chamada.workers) {
        if (worker.status != PresencaStatus.falta) {
          result.add((obraId: chObraId, date: date, apontamento: worker));
        }
      }
    }
    return result;
  }

  Future<void> saveChamada(ChamadaDiaria chamada) async {
    final erros = RhInvarianteValidator.validarChamada(
      apontamentos: chamada.workers,
    );
    if (erros.isNotEmpty) {
      throw ArgumentError(
        'Invariantes de RH violadas: ${erros.join("; ")}',
      );
    }
    if (chamada.isRetificada &&
        (chamada.motivoRetificacao == null ||
            chamada.motivoRetificacao!.trim().length < 10)) {
      throw ArgumentError(
        'Retificação de chamada exige justificativa com ao menos 10 caracteres.',
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
