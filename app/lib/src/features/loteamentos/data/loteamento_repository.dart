import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contracts.dart';
import '../../authentication/data/user_repository.dart';
import '../../lotes/data/lote_repository.dart';
import '../../lotes/domain/lote.dart';
import '../../obras/domain/obra.dart';
import '../../obras/presentation/current_permissions_provider.dart';
import '../../quadras/data/quadra_repository.dart';
import '../../quadras/domain/quadra.dart';
import '../domain/loteamento.dart';

final loteamentoRepositoryProvider = Provider<LoteamentoRepository>((ref) {
  return LoteamentoRepository(
    Firebase.apps.isEmpty ? null : FirebaseFirestore.instance,
  );
});

class LoteamentoRepository {
  final FirebaseFirestore? _firestore;

  LoteamentoRepository(this._firestore);

  CollectionReference<Loteamento> _loteamentosRef() => _firestore!
      .collection('loteamentos')
      .withConverter<Loteamento>(
        fromFirestore: (snapshot, _) {
          final data = Map<String, dynamic>.from(snapshot.data()!);
          data['id'] ??= snapshot.id;
          return Loteamento.fromJson(data).copyWith(id: snapshot.id);
        },
        toFirestore: (loteamento, _) => loteamento.toJson(),
      );

  DocumentReference<Map<String, dynamic>> _mirrorObraRef(
    FirebaseFirestore firestore,
    Loteamento loteamento,
  ) {
    return firestore
        .collection('construtoras')
        .doc(loteamento.construtoraId)
        .collection('obras')
        .doc(loteamento.effectiveObraId);
  }

  Map<String, dynamic> _buildMirrorObraPayload(Loteamento loteamento) {
    return Obra(
      id: loteamento.effectiveObraId,
      construtoraId: loteamento.construtoraId,
      name: loteamento.name,
      createdAt: loteamento.createdAt,
      isActive: true,
    ).toJson();
  }

  Stream<List<Loteamento>> watchLoteamentos(String construtoraId) {
    final firestore = _firestore;
    if (firestore == null) return Stream.value(const <Loteamento>[]);
    return _loteamentosRef()
        .where('construtoraId', isEqualTo: construtoraId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// Assina apenas os loteamentos da construtora cujo `id` ou `obraId` pertença
  /// a [obraIds], respeitando o limite de `whereIn` por lote.
  Stream<List<Loteamento>> watchLoteamentosByObraIds(
    String construtoraId,
    List<String> obraIds,
  ) {
    final firestore = _firestore;
    final cleanIds =
        obraIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList()
          ..sort();
    if (firestore == null || cleanIds.isEmpty) {
      return Stream.value(const <Loteamento>[]);
    }

    const chunkSize = 10;
    final chunks = <List<String>>[
      for (var i = 0; i < cleanIds.length; i += chunkSize)
        cleanIds.sublist(
          i,
          i + chunkSize < cleanIds.length ? i + chunkSize : cleanIds.length,
        ),
    ];

    final queries = <Query<Loteamento>>[
      for (final chunk in chunks) ...[
        _loteamentosRef()
            .where('construtoraId', isEqualTo: construtoraId)
            .where(FieldPath.documentId, whereIn: chunk),
        _loteamentosRef()
            .where('construtoraId', isEqualTo: construtoraId)
            .where('obraId', whereIn: chunk),
      ],
    ];

    late final StreamController<List<Loteamento>> controller;
    final subs = <StreamSubscription<QuerySnapshot<Loteamento>>>[];
    final resultsByStream = <int, List<Loteamento>>{};
    final errorsByStream = <int, (Object, StackTrace)>{};
    final readyStreams = <int>{};

    void emitIfReady() {
      if (controller.isClosed) return;
      if (readyStreams.length < queries.length) return;
      if (errorsByStream.isNotEmpty) {
        final firstErr = errorsByStream.values.first;
        controller.addError(firstErr.$1, firstErr.$2);
        return;
      }
      final merged = <String, Loteamento>{};
      for (final list in resultsByStream.values) {
        for (final item in list) {
          merged[item.id] = item;
        }
      }
      final sorted = merged.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      controller.add(sorted);
    }

    controller = StreamController<List<Loteamento>>(
      onListen: () {
        for (var i = 0; i < queries.length; i++) {
          final index = i;
          subs.add(
            queries[index].snapshots().listen(
              (snap) {
                errorsByStream.remove(index);
                resultsByStream[index] = snap.docs
                    .map((doc) => doc.data())
                    .toList();
                readyStreams.add(index);
                emitIfReady();
              },
              onError: (err, stack) {
                errorsByStream[index] = (err, stack);
                readyStreams.add(index);
                emitIfReady();
              },
            ),
          );
        }
      },
      onCancel: () async {
        for (final sub in subs) {
          await sub.cancel();
        }
        if (!controller.isClosed) {
          await controller.close();
        }
      },
    );

    return controller.stream;
  }

  Future<void> createLoteamento(Loteamento loteamento) async {
    final firestore = _firestore;
    if (firestore == null) return;
    final batch = firestore.batch();
    batch.set(_loteamentosRef().doc(loteamento.id), loteamento);
    if ((loteamento.obraId ?? '').trim().isEmpty) {
      batch.set(
        _mirrorObraRef(firestore, loteamento),
        _buildMirrorObraPayload(loteamento),
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  Future<void> updateLoteamento(Loteamento loteamento) async {
    final firestore = _firestore;
    if (firestore == null) return;
    final updated = loteamento.copyWith(updatedAt: DateTime.now());
    final fullJson = updated.toJson();
    final editablePayload = <String, dynamic>{
      'name': fullJson['name'],
      'bairro': fullJson['bairro'],
      'cidade': fullJson['cidade'],
      'uf': fullJson['uf'],
      'proprietarioNome': fullJson['proprietarioNome'],
      'proprietarioDocumento': fullJson['proprietarioDocumento'],
      'responsavelTecnicoNome': fullJson['responsavelTecnicoNome'],
      'responsavelTecnicoRegistro': fullJson['responsavelTecnicoRegistro'],
      'updatedAt': fullJson['updatedAt'],
    };
    await firestore
        .collection('loteamentos')
        .doc(updated.id)
        .update(editablePayload);
    try {
      await _mirrorObraRef(firestore, updated).update({'name': updated.name});
    } on FirebaseException catch (e) {
      if (e.code != 'not-found') rethrow;
    }
  }

  Future<void> createLoteamentoEmMassa({
    required Loteamento loteamento,
    required List<Quadra> quadras,
    required List<Lote> lotes,
  }) async {
    final firestore = _firestore!;
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
        throw ArgumentError.value(
          quadra.id,
          'quadra.id',
          'ID da quadra inválido',
        );
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

    final quadrasRef = QuadraRepository.quadrasCollection(firestore);
    final operations = <FirestoreBatchWrite>[
      (batch) => batch.set(_loteamentosRef().doc(loteamento.id), loteamento),
      if ((loteamento.obraId ?? '').trim().isEmpty)
        (batch) => batch.set(
          _mirrorObraRef(firestore, loteamento),
          _buildMirrorObraPayload(loteamento),
          SetOptions(merge: true),
        ),
      for (final quadra in quadras)
        (batch) => batch.set(quadrasRef.doc(quadra.id), quadra),
    ];
    LoteRepository.appendLotesComEtapasWrites(
      firestore: firestore,
      operations: operations,
      lotes: lotes,
      expectedConstrutoraId: loteamento.construtoraId,
      expectedLoteamentoId: loteamento.id,
      allowedQuadraIds: quadraIds,
    );
    await commitFirestoreBatches(firestore, operations);
  }
}

typedef LoteamentoParams = ({String construtoraId});

final watchLoteamentosProvider =
    StreamProvider.family<List<Loteamento>, LoteamentoParams>((ref, params) {
      final repo = ref.watch(loteamentoRepositoryProvider);
      final devAsync = ref.watch(trustedDevProvider);
      if (devAsync.value == true) {
        return repo.watchLoteamentos(params.construtoraId);
      }
      if (devAsync.hasError) {
        return Stream.error(
          devAsync.error!,
          devAsync.stackTrace ?? StackTrace.current,
        );
      }

      final cmAsync = ref.watch(
        construtoraPermissionProvider(params.construtoraId),
      );
      if (cmAsync.isLoading && !cmAsync.hasValue) {
        return Firebase.apps.isEmpty
            ? repo.watchLoteamentos(params.construtoraId)
            : const Stream.empty();
      }
      if (cmAsync.hasError) {
        return Stream.error(
          cmAsync.error!,
          cmAsync.stackTrace ?? StackTrace.current,
        );
      }

      final cm = cmAsync.value;
      if (cm == null) {
        return Firebase.apps.isEmpty
            ? repo.watchLoteamentos(params.construtoraId)
            : Stream.value(const <Loteamento>[]);
      }

      if (cm['isActive'] != true) {
        return Stream.value(const <Loteamento>[]);
      }

      if (hasGlobalLotesAccess(cm)) {
        return repo.watchLoteamentos(params.construtoraId);
      }

      final obraIdsAsync = ref.watch(
        userActiveObraIdsProvider(params.construtoraId),
      );
      if (obraIdsAsync.isLoading && !obraIdsAsync.hasValue) {
        return const Stream.empty();
      }
      if (obraIdsAsync.hasError) {
        return Stream.error(
          obraIdsAsync.error!,
          obraIdsAsync.stackTrace ?? StackTrace.current,
        );
      }
      final obraIds = obraIdsAsync.value ?? ObraIdSet.empty;
      if (obraIds.isEmpty) {
        return Stream.value(const <Loteamento>[]);
      }
      try {
        return repo.watchLoteamentosByObraIds(
          params.construtoraId,
          obraIds.ids,
        );
      } on NoSuchMethodError {
        return repo
            .watchLoteamentos(params.construtoraId)
            .map(
              (items) => items
                  .where(
                    (item) =>
                        obraIds.contains(item.id) ||
                        obraIds.contains(item.effectiveObraId),
                  )
                  .toList(),
            );
      }
    });
