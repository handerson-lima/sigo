import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/lote.dart';

import '../../etapas/data/etapa_repository.dart';

final loteRepositoryProvider = Provider<LoteRepository>((ref) {
  return LoteRepository(
    FirebaseFirestore.instance,
    ref.read(etapaRepositoryProvider),
  );
});

class LoteRepository {
  final FirebaseFirestore _firestore;
  final EtapaRepository _etapaRepository;

  LoteRepository(this._firestore, this._etapaRepository);

  CollectionReference<Lote> _lotesRef() => _firestore
      .collection('lotes')
      .withConverter<Lote>(
        fromFirestore: (snapshot, _) => Lote.fromJson(snapshot.data()!),
        toFirestore: (lote, _) => lote.toJson(),
      );

  Stream<List<Lote>> watchLotes(
    String construtoraId,
    String loteamentoId,
    String quadraId,
  ) {
    return _lotesRef()
        .where('construtoraId', isEqualTo: construtoraId)
        .where('loteamentoId', isEqualTo: loteamentoId)
        .where('quadraId', isEqualTo: quadraId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }



  Future<void> createLoteComEtapas(Lote lote) async {
    final batch = _firestore.batch();

    final docRef = _lotesRef().doc(lote.id);
    batch.set(docRef, lote);

    await _etapaRepository.createDefaultEtapas(
      construtoraId: lote.construtoraId,
      loteamentoId: lote.loteamentoId,
      quadraId: lote.quadraId,
      loteId: lote.id,
      batch: batch,
    );

    await batch.commit();
  }
}

typedef LoteParams = ({
  String construtoraId,
  String loteamentoId,
  String quadraId,
});

final watchLotesProvider = StreamProvider.family<List<Lote>, LoteParams>((
  ref,
  params,
) {
  final repo = ref.watch(loteRepositoryProvider);
  return repo.watchLotes(
    params.construtoraId,
    params.loteamentoId,
    params.quadraId,
  );
});
