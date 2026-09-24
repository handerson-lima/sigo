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
  FakeQuadraRepository(this.quadras);

  @override
  Stream<List<Quadra>> watchQuadras(String construtoraId, String loteamentoId) =>
      Stream.value(quadras);

  @override
  Future<void> createQuadra(Quadra quadra) async {}
}

class FakeLoteRepository implements LoteRepository {
  final List<Lote> lotes;
  FakeLoteRepository(this.lotes);

  @override
  Stream<List<Lote>> watchLotes(
    String construtoraId,
    String loteamentoId,
    String quadraId,
  ) =>
      Stream.value(lotes);

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

  test('watchQuadrasProvider resolve via Records sem novo loading', () async {
    final container = ProviderContainer(
      overrides: [
        quadraRepositoryProvider.overrideWithValue(
          FakeQuadraRepository([makeQuadra('q1')]),
        ),
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

    final reread = container.read(watchQuadrasProvider(params));
    expect(identical(data, reread), isTrue);
  });

  test('watchLotesProvider resolve via Records sem novo loading', () async {
    final container = ProviderContainer(
      overrides: [
        loteRepositoryProvider.overrideWithValue(
          FakeLoteRepository([makeLote('lo1')]),
        ),
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

    final reread = container.read(watchLotesProvider(params));
    expect(identical(data, reread), isTrue);
  });
}
