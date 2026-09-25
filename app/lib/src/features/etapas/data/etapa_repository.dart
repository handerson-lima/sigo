import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/etapa.dart';

final etapaRepositoryProvider = Provider<EtapaRepository>((ref) {
  return EtapaRepository(FirebaseFirestore.instance);
});

class EtapaRepository {
  final FirebaseFirestore _firestore;

  EtapaRepository(this._firestore);

  CollectionReference<Etapa> _etapasRef() =>
      _firestore
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

  Future<void> createDefaultEtapas({
    required String construtoraId,
    required String loteamentoId,
    required String quadraId,
    required String loteId,
  }) async {
    final batch = _firestore.batch();
    final now = DateTime.now();

    final etapasDefault = [
      Etapa(
        id: _firestore.collection('etapas').doc().id,
        construtoraId: construtoraId,
        loteamentoId: loteamentoId,
        quadraId: quadraId,
        loteId: loteId,
        nome: EtapaTipo.muro.label,
        ordem: EtapaTipo.muro.ordem,
        createdAt: now,
        updatedAt: now,
      ),
      Etapa(
        id: _firestore.collection('etapas').doc().id,
        construtoraId: construtoraId,
        loteamentoId: loteamentoId,
        quadraId: quadraId,
        loteId: loteId,
        nome: EtapaTipo.cinza1.label,
        ordem: EtapaTipo.cinza1.ordem,
        createdAt: now,
        updatedAt: now,
      ),
      Etapa(
        id: _firestore.collection('etapas').doc().id,
        construtoraId: construtoraId,
        loteamentoId: loteamentoId,
        quadraId: quadraId,
        loteId: loteId,
        nome: EtapaTipo.cinza2.label,
        ordem: EtapaTipo.cinza2.ordem,
        createdAt: now,
        updatedAt: now,
      ),
      Etapa(
        id: _firestore.collection('etapas').doc().id,
        construtoraId: construtoraId,
        loteamentoId: loteamentoId,
        quadraId: quadraId,
        loteId: loteId,
        nome: EtapaTipo.cinza3.label,
        ordem: EtapaTipo.cinza3.ordem,
        createdAt: now,
        updatedAt: now,
      ),
      Etapa(
        id: _firestore.collection('etapas').doc().id,
        construtoraId: construtoraId,
        loteamentoId: loteamentoId,
        quadraId: quadraId,
        loteId: loteId,
        nome: EtapaTipo.branca.label,
        ordem: EtapaTipo.branca.ordem,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    for (final etapa in etapasDefault) {
      batch.set(_etapasRef().doc(etapa.id), etapa);
    }

    await batch.commit();
  }
}

typedef EtapaParams = ({
  String construtoraId,
  String loteamentoId,
  String quadraId,
  String loteId,
});

final watchEtapasProvider =
    StreamProvider.family<List<Etapa>, EtapaParams>((ref, params) {
  final repo = ref.watch(etapaRepositoryProvider);
  return repo.watchEtapas(
    params.construtoraId,
    params.loteamentoId,
    params.quadraId,
    params.loteId,
  );
});