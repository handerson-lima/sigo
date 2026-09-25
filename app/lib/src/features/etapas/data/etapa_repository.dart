import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/etapa.dart';

final etapaRepositoryProvider = Provider<EtapaRepository>((ref) {
  return EtapaRepository(FirebaseFirestore.instance);
});

class EtapaRepository {
  final FirebaseFirestore _firestore;

  EtapaRepository(this._firestore);

  CollectionReference<Etapa> _etapasRef() => _firestore
      .collection('etapas')
      .withConverter<Etapa>(
        fromFirestore: (snapshot, _) => Etapa.fromJson(snapshot.data()!),
        toFirestore: (etapa, _) => etapa.toJson(),
      );

  Stream<List<Etapa>> watchEtapas(
    String construtoraId,
    String loteamentoId,
    String quadraId,
    String loteId,
  ) {
    return _etapasRef()
        .where('construtoraId', isEqualTo: construtoraId)
        .where('loteamentoId', isEqualTo: loteamentoId)
        .where('quadraId', isEqualTo: quadraId)
        .where('loteId', isEqualTo: loteId)
        .orderBy('ordem')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<void> createEtapa(Etapa etapa) async {
    final docRef = _etapasRef().doc(etapa.id);
    await docRef.set(etapa);
  }

  static List<Etapa> buildDefaultEtapas({
    required String construtoraId,
    required String loteamentoId,
    required String quadraId,
    required String loteId,
    required String Function(EtapaTipo) newId,
    required DateTime now,
  }) {
    return EtapaTipo.values
        .map(
          (tipo) => Etapa(
            id: newId(tipo),
            construtoraId: construtoraId,
            loteamentoId: loteamentoId,
            quadraId: quadraId,
            loteId: loteId,
            nome: tipo.label,
            ordem: tipo.ordem,
            createdAt: now,
            updatedAt: now,
          ),
        )
        .toList();
  }

  Future<void> createDefaultEtapas({
    required String construtoraId,
    required String loteamentoId,
    required String quadraId,
    required String loteId,
    WriteBatch? batch,
  }) async {
    final etapasDefault = buildDefaultEtapas(
      construtoraId: construtoraId,
      loteamentoId: loteamentoId,
      quadraId: quadraId,
      loteId: loteId,
      newId: (tipo) => '${loteId}_${tipo.name}',
      now: DateTime.now(),
    );

    final localBatch = batch ?? _firestore.batch();
    for (final etapa in etapasDefault) {
      localBatch.set(_etapasRef().doc(etapa.id), etapa);
    }

    if (batch == null) {
      await localBatch.commit();
    }
  }
}

typedef EtapaParams = ({
  String construtoraId,
  String loteamentoId,
  String quadraId,
  String loteId,
});

final watchEtapasProvider = StreamProvider.family<List<Etapa>, EtapaParams>((
  ref,
  params,
) {
  final repo = ref.watch(etapaRepositoryProvider);
  return repo.watchEtapas(
    params.construtoraId,
    params.loteamentoId,
    params.quadraId,
    params.loteId,
  );
});
