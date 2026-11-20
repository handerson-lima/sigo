import 'dart:async';

import 'package:app/src/features/authentication/data/user_repository.dart';
import 'package:app/src/features/loteamentos/data/loteamento_repository.dart';
import 'package:app/src/features/loteamentos/domain/loteamento.dart';
import 'package:app/src/features/lotes/data/lote_repository.dart';
import 'package:app/src/features/lotes/domain/lote.dart';
import 'package:app/src/features/obras/presentation/current_permissions_provider.dart';
import 'package:app/src/features/quadras/data/quadra_repository.dart';
import 'package:app/src/features/quadras/domain/quadra.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeLoteamentoRepository implements LoteamentoRepository {
  final List<Loteamento> loteamentos;
  FakeLoteamentoRepository(this.loteamentos);

  @override
  Stream<List<Loteamento>> watchLoteamentos(String construtoraId) =>
      Stream.value(loteamentos);

  @override
  Future<void> createLoteamento(Loteamento loteamento) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeQuadraRepository implements QuadraRepository {
  final List<Quadra> quadras;
  final List<(String, String)> calls = [];
  FakeQuadraRepository(this.quadras);

  @override
  Stream<List<Quadra>> watchQuadras(String construtoraId, String loteamentoId) {
    calls.add((construtoraId, loteamentoId));
    return Stream.value(quadras);
  }

  @override
  Future<void> createQuadra(Quadra quadra) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeLoteRepository implements LoteRepository {
  final List<Lote> lotes;
  final List<(String, String, String)> calls = [];
  FakeLoteRepository(this.lotes);

  @override
  Stream<List<Lote>> watchLotes(
    String construtoraId,
    String loteamentoId,
    String quadraId,
  ) {
    calls.add((construtoraId, loteamentoId, quadraId));
    return Stream.value(lotes);
  }

  @override
  Future<void> createLoteComEtapas(Lote lote) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Loteamento makeLoteamento(String id) => Loteamento(
  id: id,
  construtoraId: 'c1',
  name: 'Loteamento $id',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

Quadra makeQuadra(String id) => Quadra(
  id: id,
  construtoraId: 'c1',
  loteamentoId: 'l1',
  name: 'Quadra $id',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

Lote makeLote(String id) => Lote(
  id: id,
  construtoraId: 'c1',
  loteamentoId: 'l1',
  quadraId: 'q1',
  name: 'Lote $id',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  test(
    'watchLoteamentosProvider resolve via Records sem novo loading',
    () async {
      final container = ProviderContainer(
        overrides: [
          loteamentoRepositoryProvider.overrideWithValue(
            FakeLoteamentoRepository([makeLoteamento('l1')]),
          ),
        ],
      );
      addTearDown(container.dispose);

      const params = (construtoraId: 'c1');
      final sub = container.listen(watchLoteamentosProvider(params), (_, _) {});
      addTearDown(sub.close);

      expect(
        container.read(watchLoteamentosProvider(params)).isLoading,
        isTrue,
      );

      await container.read(watchLoteamentosProvider(params).future);

      final data = container.read(watchLoteamentosProvider(params));
      expect(data.hasValue, isTrue);
      expect(data.value!.single.name, 'Loteamento l1');

      final reread = container.read(watchLoteamentosProvider(params));
      expect(identical(data, reread), isTrue);
    },
  );

  test('watchQuadrasProvider encaminha os IDs na ordem correta', () async {
    final fake = FakeQuadraRepository([makeQuadra('q1')]);
    final container = ProviderContainer(
      overrides: [quadraRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    const params = (construtoraId: 'c1', loteamentoId: 'l1');
    final sub = container.listen(watchQuadrasProvider(params), (_, _) {});
    addTearDown(sub.close);

    expect(container.read(watchQuadrasProvider(params)).isLoading, isTrue);

    await container.read(watchQuadrasProvider(params).future);

    final data = container.read(watchQuadrasProvider(params));
    expect(data.hasValue, isTrue);
    expect(data.value!.single.name, 'Quadra q1');

    expect(fake.calls, [('c1', 'l1')]);

    final reread = container.read(watchQuadrasProvider(params));
    expect(identical(data, reread), isTrue);
  });

  test('watchLotesProvider encaminha os IDs na ordem correta', () async {
    final fake = FakeLoteRepository([makeLote('lo1')]);
    final container = ProviderContainer(
      overrides: [loteRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    const params = (construtoraId: 'c1', loteamentoId: 'l1', quadraId: 'q1');
    final sub = container.listen(watchLotesProvider(params), (_, _) {});
    addTearDown(sub.close);

    expect(container.read(watchLotesProvider(params)).isLoading, isTrue);

    await container.read(watchLotesProvider(params).future);

    final data = container.read(watchLotesProvider(params));
    expect(data.hasValue, isTrue);
    expect(data.value!.single.name, 'Lote lo1');

    expect(fake.calls, [('c1', 'l1', 'q1')]);

    final reread = container.read(watchLotesProvider(params));
    expect(identical(data, reread), isTrue);
  });

  test('watchLotesProvider isola chaves de family distintas', () async {
    final fake = FakeLoteRepository([makeLote('lo1')]);
    final container = ProviderContainer(
      overrides: [loteRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    const a = (construtoraId: 'c1', loteamentoId: 'l1', quadraId: 'q1');
    const b = (construtoraId: 'c1', loteamentoId: 'l1', quadraId: 'q2');

    final subA = container.listen(watchLotesProvider(a), (_, _) {});
    final subB = container.listen(watchLotesProvider(b), (_, _) {});
    addTearDown(subA.close);
    addTearDown(subB.close);

    await container.read(watchLotesProvider(a).future);
    await container.read(watchLotesProvider(b).future);

    expect(fake.calls, containsAll([('c1', 'l1', 'q1'), ('c1', 'l1', 'q2')]));
  });

  group('watchLoteamentosByObraIds e watchLoteamentosProvider', () {
    test(
      'retorna loteamentos por docId, por obraId legado e com mais de 10 IDs em lotes',
      () async {
        final firestore = FakeFirebaseFirestore();
        final repo = LoteamentoRepository(firestore);
        final now = DateTime(2026, 1, 1);

        // 11 docs correspondidos por id + 1 legado correspondido por obraId
        for (var i = 1; i <= 11; i++) {
          final id = 'lt_${i.toString().padLeft(2, '0')}';
          await firestore.collection('loteamentos').doc(id).set(
                Loteamento(
                  id: id,
                  construtoraId: 'c1',
                  name: 'Loteamento $id',
                  createdAt: now,
                  updatedAt: now,
                ).toJson(),
              );
        }
        await firestore.collection('loteamentos').doc('lt_legado').set(
              Loteamento(
                id: 'lt_legado',
                construtoraId: 'c1',
                obraId: 'obra_legada',
                name: 'Legado CAOL',
                createdAt: now,
                updatedAt: now,
              ).toJson(),
            );
        await firestore.collection('loteamentos').doc('lt_outro').set(
              Loteamento(
                id: 'lt_outro',
                construtoraId: 'c1',
                name: 'Nao Vinculado',
                createdAt: now,
                updatedAt: now,
              ).toJson(),
            );

        final ids = [
          for (var i = 1; i <= 11; i++) 'lt_${i.toString().padLeft(2, '0')}',
          'obra_legada',
        ];

        final result = await repo.watchLoteamentosByObraIds('c1', ids).first;
        expect(result.length, 12);
        expect(result.any((l) => l.id == 'lt_legado'), isTrue);
        expect(result.any((l) => l.id == 'lt_outro'), isFalse);
      },
    );

    test(
      'watchLoteamentosByObraIds propaga erro parcial mesmo quando outro stream emite lista vazia',
      () async {
        final firestore = _PartialErrorLoteamentosFirestore(
          FakeFirebaseFirestore(),
        );
        final repo = LoteamentoRepository(firestore);

        await expectLater(
          repo.watchLoteamentosByObraIds('c1', ['o1']).first,
          throwsA(isA<FirebaseException>()),
        );
      },
    );

    test(
      'watchLoteamentosProvider propaga erro de construtoraPermissionProvider',
      () async {
        final container = ProviderContainer(
          overrides: [
            trustedDevProvider.overrideWithValue(const AsyncValue.data(false)),
            construtoraPermissionProvider('c1').overrideWithValue(
              AsyncValue.error(Exception('falha permissao'), StackTrace.current),
            ),
            loteamentoRepositoryProvider.overrideWithValue(
              FakeLoteamentoRepository([makeLoteamento('l1')]),
            ),
          ],
        );
        addTearDown(container.dispose);

        final states = <AsyncValue<List<Loteamento>>>[];
        final sub = container.listen(
          watchLoteamentosProvider((construtoraId: 'c1')),
          (_, next) => states.add(next),
          fireImmediately: true,
        );
        addTearDown(sub.close);

        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(states.any((s) => s.hasError), isTrue);
      },
    );
  });
}

class _PartialErrorLoteamentosFirestore implements FirebaseFirestore {
  final FakeFirebaseFirestore _delegate;
  int _whereInCall = 0;

  _PartialErrorLoteamentosFirestore(this._delegate);

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    if (collectionPath == 'loteamentos') {
      return _PartialErrorCollection(_delegate.collection(collectionPath), () {
        _whereInCall++;
        return _whereInCall == 2;
      });
    }
    return _delegate.collection(collectionPath);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => _delegate.noSuchMethod(invocation);
}

class _PartialErrorCollection implements CollectionReference<Map<String, dynamic>> {
  final CollectionReference<Map<String, dynamic>> _delegate;
  final bool Function() _shouldError;

  _PartialErrorCollection(this._delegate, this._shouldError);

  @override
  CollectionReference<R> withConverter<R>({
    required FromFirestore<R> fromFirestore,
    required ToFirestore<R> toFirestore,
  }) {
    return _PartialErrorConvertedCollection<R>(
      _delegate.withConverter<R>(
        fromFirestore: fromFirestore,
        toFirestore: toFirestore,
      ),
      _shouldError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => _delegate.noSuchMethod(invocation);
}

class _PartialErrorConvertedCollection<R> implements CollectionReference<R> {
  final CollectionReference<R> _delegate;
  final bool Function() _shouldError;

  _PartialErrorConvertedCollection(this._delegate, this._shouldError);

  @override
  Query<R> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) {
    final q = _delegate.where(
      field,
      isEqualTo: isEqualTo,
      isNotEqualTo: isNotEqualTo,
      isLessThan: isLessThan,
      isLessThanOrEqualTo: isLessThanOrEqualTo,
      isGreaterThan: isGreaterThan,
      isGreaterThanOrEqualTo: isGreaterThanOrEqualTo,
      arrayContains: arrayContains,
      arrayContainsAny: arrayContainsAny,
      whereIn: whereIn,
      whereNotIn: whereNotIn,
      isNull: isNull,
    );
    return _PartialErrorQuery<R>(q, _shouldError);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => _delegate.noSuchMethod(invocation);
}

class _PartialErrorQuery<R> implements Query<R> {
  final Query<R> _delegate;
  final bool Function() _shouldError;

  _PartialErrorQuery(this._delegate, this._shouldError);

  @override
  Query<R> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) {
    final q = _delegate.where(
      field,
      isEqualTo: isEqualTo,
      isNotEqualTo: isNotEqualTo,
      isLessThan: isLessThan,
      isLessThanOrEqualTo: isLessThanOrEqualTo,
      isGreaterThan: isGreaterThan,
      isGreaterThanOrEqualTo: isGreaterThanOrEqualTo,
      arrayContains: arrayContains,
      arrayContainsAny: arrayContainsAny,
      whereIn: whereIn,
      whereNotIn: whereNotIn,
      isNull: isNull,
    );
    if (whereIn != null && _shouldError()) {
      return _FailingSnapshotsQuery<R>(q);
    }
    return _PartialErrorQuery<R>(q, _shouldError);
  }

  @override
  Stream<QuerySnapshot<R>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) =>
      _delegate.snapshots(
        includeMetadataChanges: includeMetadataChanges,
        source: source,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => _delegate.noSuchMethod(invocation);
}

class _FailingSnapshotsQuery<R> implements Query<R> {
  final Query<R> _delegate;

  _FailingSnapshotsQuery(this._delegate);

  @override
  Stream<QuerySnapshot<R>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    return Stream.error(
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => _delegate.noSuchMethod(invocation);
}
