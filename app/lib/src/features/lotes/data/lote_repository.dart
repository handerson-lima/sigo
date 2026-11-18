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
        fromFirestore: (snapshot, _) {
          final data = Map<String, dynamic>.from(snapshot.data()!);
          data['id'] ??= snapshot.id;
          return Lote.fromJson(data).copyWith(id: snapshot.id);
        },
        toFirestore: (lote, _) => lote.toJson(),
      );

  CollectionReference<Lote> _lotesRef() => lotesCollection(_firestore);

  static String _requireNonEmpty(String value, String fieldName) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(value, fieldName, '$fieldName é obrigatório');
    }
    return trimmed;
  }

  static void appendLotesComEtapasWrites({
    required FirebaseFirestore firestore,
    required List<FirestoreBatchWrite> operations,
    required List<Lote> lotes,
    String? expectedConstrutoraId,
    String? expectedLoteamentoId,
    String? expectedQuadraId,
    Set<String>? allowedQuadraIds,
  }) {
    final seenLoteIds = <String>{};
    for (final lote in lotes) {
      _requireNonEmpty(lote.id, 'lote.id');
      _requireNonEmpty(lote.construtoraId, 'lote.construtoraId');
      _requireNonEmpty(lote.loteamentoId, 'lote.loteamentoId');
      _requireNonEmpty(lote.quadraId, 'lote.quadraId');
      if (!seenLoteIds.add(lote.id)) {
        throw ArgumentError.value(
          lote.id,
          'lotes',
          'Lote duplicado no lote em massa: ${lote.id}',
        );
      }
      if (expectedConstrutoraId != null &&
          lote.construtoraId != expectedConstrutoraId) {
        throw ArgumentError.value(
          lote.construtoraId,
          'lote.construtoraId',
          'Lote ${lote.id} possui construtoraId divergente',
        );
      }
      if (expectedLoteamentoId != null &&
          lote.loteamentoId != expectedLoteamentoId) {
        throw ArgumentError.value(
          lote.loteamentoId,
          'lote.loteamentoId',
          'Lote ${lote.id} possui loteamentoId divergente',
        );
      }
      if (expectedQuadraId != null && lote.quadraId != expectedQuadraId) {
        throw ArgumentError.value(
          lote.quadraId,
          'lote.quadraId',
          'Lote ${lote.id} possui quadraId divergente',
        );
      }
      if (allowedQuadraIds != null &&
          !allowedQuadraIds.contains(lote.quadraId)) {
        throw ArgumentError.value(
          lote.quadraId,
          'lote.quadraId',
          'Lote ${lote.id} referencia quadraId inexistente no loteamento: ${lote.quadraId}',
        );
      }
    }

    final lotesRef = lotesCollection(firestore);
    for (final lote in lotes) {
      operations.add((batch) {
        batch.set(lotesRef.doc(lote.id), lote);
      });
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
    _requireNonEmpty(lote.id, 'lote.id');
    _requireNonEmpty(lote.construtoraId, 'lote.construtoraId');
    _requireNonEmpty(lote.loteamentoId, 'lote.loteamentoId');
    _requireNonEmpty(lote.quadraId, 'lote.quadraId');

    final batch = _firestore.batch();

    final docRef = _lotesRef().doc(lote.id);
    batch.set(docRef, lote);

    _etapaRepository.addDefaultEtapasToBatch(
      batch: batch,
      construtoraId: lote.construtoraId,
      loteamentoId: lote.loteamentoId,
      quadraId: lote.quadraId,
      loteId: lote.id,
      now: lote.createdAt,
    );

    await batch.commit();
  }

  Future<void> createLotesEmMassa(List<Lote> lotes) async {
    if (lotes.isEmpty) return;
    final first = lotes.first;
    final operations = <FirestoreBatchWrite>[];
    appendLotesComEtapasWrites(
      firestore: _firestore,
      operations: operations,
      lotes: lotes,
      expectedConstrutoraId: first.construtoraId,
      expectedLoteamentoId: first.loteamentoId,
      expectedQuadraId: first.quadraId,
    );
    await commitFirestoreBatches(_firestore, operations);
  }

  Future<void> updateLote(Lote lote) async {
    final updated = lote.copyWith(updatedAt: DateTime.now());
    final payload = Map<String, dynamic>.from(updated.toJson())
      ..remove('progressoPercentual')
      ..remove('etapasConcluidasCount')
      ..remove('etapasTotalCount')
      ..remove('statusEtapasMap')
      ..remove('equipesVinculadas')
      ..remove('funcionariosVinculados');
    await _firestore.collection('lotes').doc(updated.id).update(payload);
  }

  Future<void> atribuirEquipe({
    required String loteId,
    required String equipeId,
    required String equipeNome,
    String? leaderName,
    String? etapaId,
  }) async {
    final validLoteId = _requireNonEmpty(loteId, 'loteId');
    final validEquipeId = _requireNonEmpty(equipeId, 'equipeId');
    final validEquipeNome = _requireNonEmpty(equipeNome, 'equipeNome');
    final normalizedEtapaId = _normalizeOptionalId(etapaId);
    final normalizedLeader = _normalizeOptionalId(leaderName);
    final entry = <String, dynamic>{
      'id': validEquipeId,
      'name': validEquipeNome,
      'leaderName': ?normalizedLeader,
      'etapaId': ?normalizedEtapaId,
    };

    return _upsertVinculoInLote(
      loteId: validLoteId,
      fieldName: 'equipesVinculadas',
      extractCurrent: (lote) => lote.equipesVinculadas,
      vinculoId: validEquipeId,
      etapaId: normalizedEtapaId,
      newEntry: entry,
      etapaUpdates: {'equipeId': validEquipeId, 'equipeNome': validEquipeNome},
    );
  }

  Future<void> removerEquipe({
    required String loteId,
    required String equipeId,
    String? etapaId,
  }) async {
    final validLoteId = _requireNonEmpty(loteId, 'loteId');
    final validEquipeId = _requireNonEmpty(equipeId, 'equipeId');
    return _removeVinculoFromLote(
      loteId: validLoteId,
      fieldName: 'equipesVinculadas',
      extractCurrent: (lote) => lote.equipesVinculadas,
      vinculoId: validEquipeId,
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
  }) async {
    final validLoteId = _requireNonEmpty(loteId, 'loteId');
    final validFuncionarioId = _requireNonEmpty(funcionarioId, 'funcionarioId');
    final validFuncionarioNome = _requireNonEmpty(
      funcionarioNome,
      'funcionarioNome',
    );
    final validRole = _requireNonEmpty(role, 'role');
    final normalizedEtapaId = _normalizeOptionalId(etapaId);
    final entry = <String, dynamic>{
      'id': validFuncionarioId,
      'name': validFuncionarioNome,
      'role': validRole,
      'etapaId': ?normalizedEtapaId,
    };

    return _upsertVinculoInLote(
      loteId: validLoteId,
      fieldName: 'funcionariosVinculados',
      extractCurrent: (lote) => lote.funcionariosVinculados,
      vinculoId: validFuncionarioId,
      etapaId: normalizedEtapaId,
      newEntry: entry,
      etapaUpdates: {
        'funcionarioId': validFuncionarioId,
        'funcionarioNome': validFuncionarioNome,
      },
    );
  }

  Future<void> removerFuncionario({
    required String loteId,
    required String funcionarioId,
    String? etapaId,
  }) async {
    final validLoteId = _requireNonEmpty(loteId, 'loteId');
    final validFuncionarioId = _requireNonEmpty(funcionarioId, 'funcionarioId');
    return _removeVinculoFromLote(
      loteId: validLoteId,
      fieldName: 'funcionariosVinculados',
      extractCurrent: (lote) => lote.funcionariosVinculados,
      vinculoId: validFuncionarioId,
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

  String? _entryEtapaId(Map<String, dynamic> entry) =>
      _normalizeOptionalId(entry['etapaId']?.toString());

  bool _matchesVinculo(
    Map<String, dynamic> entry,
    String vinculoId,
    String? etapaId,
  ) {
    return entry['id']?.toString().trim() == vinculoId &&
        _entryEtapaId(entry) == etapaId;
  }

  bool _shouldReplaceOnUpsert(
    Map<String, dynamic> entry,
    String vinculoId,
    String? etapaId,
  ) {
    final entryEtapaId = _entryEtapaId(entry);
    if (etapaId != null) {
      return entryEtapaId == etapaId;
    }
    return entry['id']?.toString().trim() == vinculoId && entryEtapaId == null;
  }

  Lote? _loteFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final raw = doc.data();
    if (!doc.exists || raw == null) return null;
    final data = Map<String, dynamic>.from(raw);
    data['id'] ??= doc.id;
    return Lote.fromJson(data).copyWith(id: doc.id);
  }

  Etapa? _etapaFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final raw = doc.data();
    if (!doc.exists || raw == null) return null;
    final data = Map<String, dynamic>.from(raw);
    data['id'] ??= doc.id;
    return Etapa.fromJson(data).copyWith(id: doc.id);
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
    final loteRawRef = _firestore.collection('lotes').doc(loteId);
    final candidateStageIds = <String>{};
    if (etapaId != null) {
      final preLoteSnap = await loteRawRef.get();
      final preLote = _loteFromDoc(preLoteSnap);
      if (preLote == null) {
        throw StateError('Lote $loteId não encontrado');
      }
      final preEtapasSnap = await _firestore
          .collection('etapas')
          .where('construtoraId', isEqualTo: preLote.construtoraId)
          .where('loteId', isEqualTo: loteId)
          .get();
      candidateStageIds.addAll(preEtapasSnap.docs.map((d) => d.id));
      for (final tipo in EtapaTipo.values) {
        candidateStageIds.add('${loteId}_${tipo.name}');
      }
      candidateStageIds.add(etapaId);
    }

    await _firestore.runTransaction((transaction) async {
      final loteSnap = await transaction.get(loteRawRef);
      final lote = _loteFromDoc(loteSnap);
      if (lote == null) {
        throw StateError('Lote $loteId não encontrado');
      }

      final stagesById = <String, Etapa>{};
      if (etapaId != null) {
        for (final stageId in candidateStageIds) {
          final stageSnap = await transaction.get(
            _firestore.collection('etapas').doc(stageId),
          );
          final stage = _etapaFromDoc(stageSnap);
          if (stage != null) {
            stagesById[stageId] = stage;
          }
        }
      }

      Etapa? existingStage;
      EtapaTipo? targetTipo;
      final byTipo = <EtapaTipo, Etapa>{};
      if (etapaId != null) {
        existingStage = stagesById[etapaId];
        if (existingStage != null) {
          if (existingStage.loteId != loteId ||
              existingStage.construtoraId != lote.construtoraId ||
              existingStage.loteamentoId != lote.loteamentoId ||
              existingStage.quadraId != lote.quadraId) {
            throw ArgumentError.value(
              etapaId,
              'etapaId',
              'Etapa $etapaId não pertence ao lote $loteId',
            );
          }
        } else {
          for (final stage in stagesById.values) {
            if (stage.loteId != loteId) continue;
            final resolved = stage.tipo;
            if (resolved != null) {
              byTipo[resolved] = stage;
            }
          }
          targetTipo = resolveEtapaTipo(id: etapaId);
          if (targetTipo == null) {
            throw ArgumentError.value(
              etapaId,
              'etapaId',
              'Etapa $etapaId não encontrada',
            );
          }
          if (etapaId != '${loteId}_${targetTipo.name}' ||
              byTipo.containsKey(targetTipo)) {
            throw ArgumentError.value(
              etapaId,
              'etapaId',
              'Etapa $etapaId não pertence ao lote $loteId',
            );
          }
        }
      }

      final current = extractCurrent(lote);
      final updatedList = <Map<String, dynamic>>[];
      var replaced = false;
      for (final item in current) {
        if (_shouldReplaceOnUpsert(item, vinculoId, etapaId)) {
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

      final now = DateTime.now();
      final nowIso = now.toIso8601String();
      transaction.update(loteRawRef, {
        fieldName: updatedList,
        'updatedAt': nowIso,
      });

      if (etapaId != null) {
        if (existingStage != null) {
          transaction.update(_firestore.collection('etapas').doc(etapaId), {
            ...etapaUpdates,
            'updatedAt': nowIso,
          });
        } else {
          for (final tipo in EtapaTipo.values) {
            if (byTipo.containsKey(tipo)) continue;
            final isTarget = tipo == targetTipo;
            final stage = Etapa(
              id: '${loteId}_${tipo.name}',
              construtoraId: lote.construtoraId,
              loteamentoId: lote.loteamentoId,
              quadraId: lote.quadraId,
              loteId: lote.id,
              nome: tipo.label,
              ordem: tipo.ordem,
              equipeId: isTarget ? etapaUpdates['equipeId'] as String? : null,
              equipeNome: isTarget
                  ? etapaUpdates['equipeNome'] as String?
                  : null,
              funcionarioId: isTarget
                  ? etapaUpdates['funcionarioId'] as String?
                  : null,
              funcionarioNome: isTarget
                  ? etapaUpdates['funcionarioNome'] as String?
                  : null,
              createdAt: now,
              updatedAt: now,
            );
            transaction.set(
              _firestore.collection('etapas').doc(stage.id),
              stage.toJson(),
            );
          }
        }
      }
    });
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
    final loteRawRef = _firestore.collection('lotes').doc(loteId);
    await _firestore.runTransaction((transaction) async {
      final loteSnap = await transaction.get(loteRawRef);
      final lote = _loteFromDoc(loteSnap);
      if (lote == null) {
        return;
      }

      DocumentReference<Map<String, dynamic>>? etapaRawRef;
      DocumentSnapshot<Map<String, dynamic>>? etapaSnap;
      if (etapaId != null) {
        etapaRawRef = _firestore.collection('etapas').doc(etapaId);
        etapaSnap = await transaction.get(etapaRawRef);
        if (etapaSnap.exists) {
          final etapa = _etapaFromDoc(etapaSnap);
          if (etapa == null ||
              etapa.loteId != loteId ||
              etapa.construtoraId != lote.construtoraId ||
              etapa.loteamentoId != lote.loteamentoId ||
              etapa.quadraId != lote.quadraId) {
            throw ArgumentError.value(
              etapaId,
              'etapaId',
              'Etapa $etapaId não pertence ao lote $loteId',
            );
          }
        } else {
          final targetTipo = resolveEtapaTipo(id: etapaId);
          if (targetTipo == null || etapaId != '${loteId}_${targetTipo.name}') {
            throw ArgumentError.value(
              etapaId,
              'etapaId',
              'Etapa $etapaId não encontrada para o lote $loteId',
            );
          }
        }
      }

      final current = extractCurrent(lote);
      final filtered = current
          .where((item) => !_matchesVinculo(item, vinculoId, etapaId))
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final removedFromLote = filtered.length != current.length;

      final shouldClearEtapa =
          etapaSnap != null &&
          etapaSnap.exists &&
          etapaSnap.data()?[etapaIdField]?.toString().trim() == vinculoId;

      if (!removedFromLote && !shouldClearEtapa) {
        return;
      }

      final nowIso = DateTime.now().toIso8601String();
      if (removedFromLote) {
        transaction.update(loteRawRef, {
          fieldName: filtered,
          'updatedAt': nowIso,
        });
      }
      if (shouldClearEtapa && etapaRawRef != null) {
        transaction.update(etapaRawRef, {
          etapaIdField: null,
          etapaNameField: null,
          'updatedAt': nowIso,
        });
      }
    });
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
