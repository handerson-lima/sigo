import 'package:app/src/features/loteamentos/data/loteamento_repository.dart';
import 'package:app/src/features/loteamentos/domain/loteamento.dart';
import 'package:app/src/features/lotes/data/lote_repository.dart';
import 'package:app/src/features/lotes/domain/lote.dart';
import 'package:app/src/features/quadras/data/quadra_repository.dart';
import 'package:app/src/features/quadras/domain/quadra.dart';
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
  Future<void> createLote(Lote lote) async {}
}

Loteamento makeLoteamento(String id) => Loteamento(
      id: id,
      construtoraId: 'c1',
      name: 'Loteamento $id',
      createdAt: DateTime(2026, 1, 1),
    );

Quadra makeQuadra(String id) => Quadra(
      id: id,
      construtoraId: 'c1',
      loteamentoId: 'l1',
      name: 'Quadra $id',
      createdAt: DateTime(2026, 1, 1),
    );

Lote makeLote(String id) => Lote(
      id: id,
      construtoraId: 'c1',
      loteamentoId: 'l1',
      quadraId: 'q1',
      name: 'Lote $id',
      phase: 'Plantas',
      status: LoteStatus.noPrazo,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  test('watchLoteamentosProvider resolve via Records sem novo loading', () async {
    final container = ProviderContainer(
      overrides: [
        loteamentoRepositoryProvider.overrideWithValue(
          FakeLoteamentoRepository([makeLoteamento('l1')]),
        ),
      ],
    );
    addTearDown(container.dispose);

    const params = (construtoraId: 'c1');
    final sub = container.listen(
      watchLoteamentosProvider(params),
      (_, _) {},
    );
    addTearDown(sub.close);

    expect(container.read(watchLoteamentosProvider(params)).isLoading, isTrue);

    await container.read(watchLoteamentosProvider(params).future);

    final data = container.read(watchLoteamentosProvider(params));
    expect(data.hasValue, isTrue);
    expect(data.value!.single.name, 'Loteamento l1');

    final reread = container.read(watchLoteamentosProvider(params));
    expect(identical(data, reread), isTrue);
  });

  test('watchQuadrasProvider encaminha os IDs na ordem correta', () async {
    final fake = FakeQuadraRepository([makeQuadra('q1')]);
    final container = ProviderContainer(
      overrides: [
        quadraRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);

    const params = (construtoraId: 'c1', loteamentoId: 'l1');
    final sub = container.listen(
      watchQuadrasProvider(params),
      (_, _) {},
    );
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
      overrides: [
        loteRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);

    const params = (construtoraId: 'c1', loteamentoId: 'l1', quadraId: 'q1');
    final sub = container.listen(
      watchLotesProvider(params),
      (_, _) {},
    );
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
      overrides: [
        loteRepositoryProvider.overrideWithValue(fake),
      ],
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
}
