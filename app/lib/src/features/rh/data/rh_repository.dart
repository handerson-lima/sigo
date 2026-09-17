import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../sync/read_cache.dart';
import '../domain/equipe.dart';
import '../domain/funcionario.dart';

final rhRepositoryProvider = Provider<RhRepository>((ref) {
  return RhRepository(FirebaseFirestore.instance);
});

final funcionariosStreamProvider =
    StreamProvider.family<List<Funcionario>, String>((ref, construtoraId) {
  return ref.watch(rhRepositoryProvider).watchFuncionarios(construtoraId);
});

final equipesStreamProvider =
    StreamProvider.family<List<Equipe>, String>((ref, construtoraId) {
  return ref.watch(rhRepositoryProvider).watchEquipes(construtoraId);
});

class RhRepository {
  final FirebaseFirestore _firestore;

  RhRepository(this._firestore);

  CollectionReference<Funcionario> _funcionariosRef(String construtoraId) =>
      _firestore
          .collection('construtoras')
          .doc(construtoraId)
          .collection('funcionarios')
          .withConverter<Funcionario>(
            fromFirestore: (snapshot, _) =>
                Funcionario.fromJson(snapshot.data()!),
            toFirestore: (f, _) => f.toJson(),
          );

  CollectionReference<Equipe> _equipesRef(String construtoraId) => _firestore
      .collection('construtoras')
      .doc(construtoraId)
      .collection('equipes')
      .withConverter<Equipe>(
        fromFirestore: (snapshot, _) => Equipe.fromJson(snapshot.data()!),
        toFirestore: (e, _) => e.toJson(),
      );

  Stream<List<Funcionario>> watchFuncionarios(String construtoraId) {
    return cachedList(
      'construtoras/$construtoraId/funcionarios',
      _liveWatchFuncionarios(construtoraId),
      (f) => f.toJson(),
      (d) => Funcionario.fromJson(Map<String, dynamic>.from(d)),
    );
  }

  Stream<List<Funcionario>> _liveWatchFuncionarios(String construtoraId) {
    return _funcionariosRef(construtoraId).snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) => doc.data()).toList();
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  Future<List<Funcionario>> getFuncionarios(String construtoraId) async {
    final snapshot = await _funcionariosRef(construtoraId).get();
    final list = snapshot.docs.map((doc) => doc.data()).toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Future<void> createFuncionario(Funcionario funcionario) async {
    await _funcionariosRef(funcionario.construtoraId)
        .doc(funcionario.id)
        .set(funcionario);
  }

  Future<void> updateFuncionario(Funcionario funcionario) async {
    await _funcionariosRef(funcionario.construtoraId)
        .doc(funcionario.id)
        .update({
      ...funcionario.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setFuncionarioActive(
    String construtoraId,
    String funcionarioId,
    bool isActive,
  ) async {
    await _funcionariosRef(construtoraId).doc(funcionarioId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Equipe>> watchEquipes(String construtoraId) {
    return cachedList(
      'construtoras/$construtoraId/equipes',
      _liveWatchEquipes(construtoraId),
      (e) => e.toJson(),
      (d) => Equipe.fromJson(Map<String, dynamic>.from(d)),
    );
  }

  Stream<List<Equipe>> _liveWatchEquipes(String construtoraId) {
    return _equipesRef(construtoraId).snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) => doc.data()).toList();
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  Future<List<Equipe>> getEquipes(String construtoraId) async {
    final snapshot = await _equipesRef(construtoraId).get();
    final list = snapshot.docs.map((doc) => doc.data()).toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Future<void> createEquipe(Equipe equipe) async {
    await _equipesRef(equipe.construtoraId).doc(equipe.id).set(equipe);
  }

  Future<void> updateEquipe(Equipe equipe) async {
    await _equipesRef(equipe.construtoraId).doc(equipe.id).update({
      ...equipe.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setEquipeActive(
    String construtoraId,
    String equipeId,
    bool isActive,
  ) async {
    await _equipesRef(construtoraId).doc(equipeId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
