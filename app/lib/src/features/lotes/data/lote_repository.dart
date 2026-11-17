import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contracts.dart';
import '../../etapas/data/etapa_repository.dart';
import '../../etapas/domain/etapa.dart';
import '../domain/lote.dart';

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

  static CollectionReference<Lote> lotesCollection(
    FirebaseFirestore firestore,
  ) => firestore
      .collection('lotes')
      .withConverter<Lote>(
        fromFirestore: (snapshot, _) => Lote.fromJson(snapshot.data()!),
        toFirestore: (lote, _) => lote.toJson(),
      );

  CollectionReference<Lote> _lotesRef() => lotesCollection(_firestore);

  static void appendLotesComEtapasWrites({
    required FirebaseFirestore firestore,
    required List<FirestoreBatchWrite> operations,
    required List<Lote> lotes,
  }) {
    final lotesRef = lotesCollection(firestore);
    for (final lote in lotes) {
      operations.add((batch) {
        batch.set(lotesRef.doc(lote.id), lote);
      });
    }
    for (final lote in lotes) {
      EtapaRepository.appendDefaultEtapasWrites(
        firestore: firestore,
        operations: operations,
        construtoraId: lote.construtoraId,
        loteamentoId: lote.loteamentoId,
        quadraId: lote.quadraId,
        loteId: lote.id,
        now: lote.createdAt,
      );
    }
  }

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

  Stream<Lote?> watchLote(String loteId) {
    return _lotesRef()
        .doc(loteId)
        .snapshots()
        .map((snapshot) => snapshot.data());
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

  Future<void> createLotesEmMassa(List<Lote> lotes) async {
    if (lotes.isEmpty) return;
    final operations = <FirestoreBatchWrite>[];
    appendLotesComEtapasWrites(
      firestore: _firestore,
      operations: operations,
      lotes: lotes,
    );
    await commitFirestoreBatches(_firestore, operations);
  }

  Future<void> updateLote(Lote lote) async {
    final updated = lote.copyWith(updatedAt: DateTime.now());
    await _lotesRef().doc(updated.id).update(updated.toJson());
  }

  Future<void> atribuirEquipe({
    required String loteId,
    required String equipeId,
    required String equipeNome,
    String? leaderName,
    String? etapaId,
  }) {
    final normalizedEtapaId = _normalizeOptionalId(etapaId);
    final normalizedLeader = _normalizeOptionalId(leaderName);
    final entry = <String, dynamic>{
      'id': equipeId,
      'name': equipeNome,
      'leaderName': ?normalizedLeader,
      'etapaId': ?normalizedEtapaId,
    };

    return _upsertVinculoInLote(
      loteId: loteId,
      fieldName: 'equipesVinculadas',
      extractCurrent: (lote) => lote.equipesVinculadas,
      vinculoId: equipeId,
      etapaId: normalizedEtapaId,
      newEntry: entry,
      etapaUpdates: {'equipeId': equipeId, 'equipeNome': equipeNome},
    );
  }

  Future<void> removerEquipe({
    required String loteId,
    required String equipeId,
    String? etapaId,
  }) {
    return _removeVinculoFromLote(
      loteId: loteId,
      fieldName: 'equipesVinculadas',
      extractCurrent: (lote) => lote.equipesVinculadas,
      vinculoId: equipeId,
      etapaId: _normalizeOptionalId(etapaId),
      etapaIdField: 'equipeId',
      etapaNameField: 'equipeNome',
    );
  }

  Future<void> atribuirFuncionario({
    required String loteId,
    required String funcionarioId,
    required String funcionarioNome,
    required String role,
    String? etapaId,
  }) {
    final normalizedEtapaId = _normalizeOptionalId(etapaId);
    final entry = <String, dynamic>{
      'id': funcionarioId,
      'name': funcionarioNome,
      'role': role,
      'etapaId': ?normalizedEtapaId,
    };

    return _upsertVinculoInLote(
      loteId: loteId,
      fieldName: 'funcionariosVinculados',
      extractCurrent: (lote) => lote.funcionariosVinculados,
      vinculoId: funcionarioId,
      etapaId: normalizedEtapaId,
      newEntry: entry,
      etapaUpdates: {
        'funcionarioId': funcionarioId,
        'funcionarioNome': funcionarioNome,
      },
    );
  }

  Future<void> removerFuncionario({
    required String loteId,
    required String funcionarioId,
    String? etapaId,
  }) {
    return _removeVinculoFromLote(
      loteId: loteId,
      fieldName: 'funcionariosVinculados',
      extractCurrent: (lote) => lote.funcionariosVinculados,
      vinculoId: funcionarioId,
      etapaId: _normalizeOptionalId(etapaId),
      etapaIdField: 'funcionarioId',
      etapaNameField: 'funcionarioNome',
    );
  }

  String? _normalizeOptionalId(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  bool _matchesVinculo(
    Map<String, dynamic> entry,
    String vinculoId,
    String? etapaId,
  ) {
    return entry['id'] == vinculoId &&
        _normalizeOptionalId(entry['etapaId'] as String?) == etapaId;
  }

  Future<void> _upsertVinculoInLote({
    required String loteId,
    required String fieldName,
    required List<Map<String, dynamic>> Function(Lote) extractCurrent,
    required String vinculoId,
    required String? etapaId,
    required Map<String, dynamic> newEntry,
    required Map<String, dynamic> etapaUpdates,
  }) async {
    final loteRef = _lotesRef().doc(loteId);
    final loteSnap = await loteRef.get();
    final lote = loteSnap.data();
    if (!loteSnap.exists || lote == null) {
      throw StateError('Lote $loteId não encontrado');
    }

    final current = extractCurrent(lote);
    final updatedList = <Map<String, dynamic>>[];
    var replaced = false;
    for (final item in current) {
      if (_matchesVinculo(item, vinculoId, etapaId)) {
        if (!replaced) {
          updatedList.add(newEntry);
          replaced = true;
        }
      } else {
        updatedList.add(Map<String, dynamic>.from(item));
      }
    }
    if (!replaced) {
      updatedList.add(newEntry);
    }

    final nowIso = DateTime.now().toIso8601String();
    final batch = _firestore.batch();
    batch.update(_firestore.collection('lotes').doc(loteId), {
      fieldName: updatedList,
      'updatedAt': nowIso,
    });

    if (etapaId != null) {
      final etapaRawRef = _firestore.collection('etapas').doc(etapaId);
      final etapaSnap = await etapaRawRef.get();
      if (etapaSnap.exists) {
        batch.update(etapaRawRef, {...etapaUpdates, 'updatedAt': nowIso});
      } else {
        final tipo = resolveEtapaTipo(id: etapaId);
        if (tipo != null) {
          final now = DateTime.now();
          final novaEtapa = Etapa(
            id: etapaId,
            construtoraId: lote.construtoraId,
            loteamentoId: lote.loteamentoId,
            quadraId: lote.quadraId,
            loteId: lote.id,
            nome: tipo.label,
            ordem: tipo.ordem,
            equipeId: etapaUpdates['equipeId'] as String?,
            equipeNome: etapaUpdates['equipeNome'] as String?,
            funcionarioId: etapaUpdates['funcionarioId'] as String?,
            funcionarioNome: etapaUpdates['funcionarioNome'] as String?,
            createdAt: now,
            updatedAt: now,
          );
          batch.set(
            EtapaRepository.etapasCollection(_firestore).doc(etapaId),
            novaEtapa,
          );
        }
      }
    }

    await batch.commit();
  }

  Future<void> _removeVinculoFromLote({
    required String loteId,
    required String fieldName,
    required List<Map<String, dynamic>> Function(Lote) extractCurrent,
    required String vinculoId,
    required String? etapaId,
    required String etapaIdField,
    required String etapaNameField,
  }) async {
    final loteRef = _lotesRef().doc(loteId);
    final loteSnap = await loteRef.get();
    final lote = loteSnap.data();
    if (!loteSnap.exists || lote == null) {
      return;
    }

    final current = extractCurrent(lote);
    final filtered = current
        .where((item) => !_matchesVinculo(item, vinculoId, etapaId))
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final removedFromLote = filtered.length != current.length;

    DocumentReference<Map<String, dynamic>>? etapaRawRef;
    var shouldClearEtapa = false;
    if (etapaId != null) {
      etapaRawRef = _firestore.collection('etapas').doc(etapaId);
      final etapaSnap = await etapaRawRef.get();
      if (etapaSnap.exists && etapaSnap.data()?[etapaIdField] == vinculoId) {
        shouldClearEtapa = true;
      }
    }

    if (!removedFromLote && !shouldClearEtapa) {
      return;
    }

    final nowIso = DateTime.now().toIso8601String();
    final batch = _firestore.batch();
    if (removedFromLote) {
      batch.update(_firestore.collection('lotes').doc(loteId), {
        fieldName: filtered,
        'updatedAt': nowIso,
      });
    }
    if (shouldClearEtapa && etapaRawRef != null) {
      batch.update(etapaRawRef, {
        etapaIdField: null,
        etapaNameField: null,
        'updatedAt': nowIso,
      });
    }
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

final watchLoteProvider = StreamProvider.family<Lote?, String>((ref, loteId) {
  final repo = ref.watch(loteRepositoryProvider);
  return repo.watchLote(loteId);
});
