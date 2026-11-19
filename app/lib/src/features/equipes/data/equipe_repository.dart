// ignore_for_file: deprecated_member_use_from_same_package

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/equipe.dart';

/// Legado da coleção raiz `/equipes`.
/// A fonte única de verdade de equipes foi migrada para
/// `construtoras/{construtoraId}/equipes` via `RhRepository` / `equipesStreamProvider`.
@Deprecated(
  'Migrado para RhRepository em construtoras/{construtoraId}/equipes '
  '(use rhRepositoryProvider / equipesStreamProvider).',
)
final equipeRepositoryProvider = Provider<EquipeRepository>((ref) {
  return EquipeRepository(FirebaseFirestore.instance);
});

@Deprecated(
  'Migrado para RhRepository em construtoras/{construtoraId}/equipes '
  '(use RhRepository em features/rh/data/rh_repository.dart).',
)
class EquipeRepository {
  final FirebaseFirestore _firestore;

  EquipeRepository(this._firestore);

  CollectionReference<EquipeLote> _equipesRef() => _firestore
      .collection('equipes')
      .withConverter<EquipeLote>(
        fromFirestore: (snapshot, _) =>
            EquipeLote.fromJson(snapshot.data() ?? {}),
        toFirestore: (equipe, _) => equipe.toJson(),
      );

  Stream<List<EquipeLote>> watchEquipes(
    String construtoraId,
    String loteamentoId,
    String quadraId,
    String loteId,
    String etapaId,
  ) {
    return _equipesRef()
        .where('construtoraId', isEqualTo: construtoraId)
        .where('loteamentoId', isEqualTo: loteamentoId)
        .where('quadraId', isEqualTo: quadraId)
        .where('loteId', isEqualTo: loteId)
        .where('etapaId', isEqualTo: etapaId)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<void> createEquipe(EquipeLote equipe) async {
    final docRef = _equipesRef().doc(equipe.id);
    await docRef.set(equipe);
  }
}

@Deprecated(
  'Migrado para RhRepository em construtoras/{construtoraId}/equipes '
  '(use equipesStreamProvider).',
)
typedef EquipeParams = ({
  String construtoraId,
  String loteamentoId,
  String quadraId,
  String loteId,
  String etapaId,
});

@Deprecated(
  'Migrado para RhRepository em construtoras/{construtoraId}/equipes '
  '(use equipesStreamProvider).',
)
final watchEquipesProvider = StreamProvider.family<List<EquipeLote>, EquipeParams>((
  ref,
  params,
) {
  final repo = ref.watch(equipeRepositoryProvider);
  return repo.watchEquipes(
    params.construtoraId,
    params.loteamentoId,
    params.quadraId,
    params.loteId,
    params.etapaId,
  );
});
