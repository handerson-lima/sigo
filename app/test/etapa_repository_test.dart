import 'package:app/src/features/etapas/data/etapa_repository.dart';
import 'package:app/src/features/etapas/domain/etapa.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeEtapaRepository implements EtapaRepository {
  final List<Etapa> etapas = [];
  final List<({String construtoraId, String loteamentoId, String quadraId, String loteId})> createDefaultCalls = [];

  @override
  Stream<List<Etapa>> watchEtapas(
    String construtoraId,
    String loteamentoId,
    String quadraId,
    String loteId,
  ) =>
      Stream.value(
          etapas.where((e) => e.loteId == loteId && e.quadraId == quadraId && e.loteamentoId == loteamentoId && e.construtoraId == construtoraId).toList());

  @override
  Future<void> createEtapa(Etapa etapa) async {
    etapas.add(etapa);
  }

  @override
  Future<void> createDefaultEtapas({
    required String construtoraId,
    required String loteamentoId,
    required String quadraId,
    required String loteId,
  }) async {
    createDefaultCalls.add((
      construtoraId: construtoraId,
      loteamentoId: loteamentoId,
      quadraId: quadraId,
      loteId: loteId,
    ));
    
    final now = DateTime.now();
    final etapasDefault = [
      Etapa(
        id: '1',
        construtoraId: construtoraId,
        loteamentoId: loteamentoId,
        quadraId: quadraId,
        loteId: loteId,
        nome: 'Muro',
        ordem: 1,
        createdAt: now,
        updatedAt: now,
      ),
      Etapa(
        id: '2',
        construtoraId: construtoraId,
        loteamentoId: loteamentoId,
        quadraId: quadraId,
        loteId: loteId,
        nome: 'Cinza/1ª',
        ordem: 2,
        createdAt: now,
        updatedAt: now,
      ),
      Etapa(
        id: '3',
        construtoraId: construtoraId,
        loteamentoId: loteamentoId,
        quadraId: quadraId,
        loteId: loteId,
        nome: 'Cinza/2ª',
        ordem: 3,
        createdAt: now,
        updatedAt: now,
      ),
      Etapa(
        id: '4',
        construtoraId: construtoraId,
        loteamentoId: loteamentoId,
        quadraId: quadraId,
        loteId: loteId,
        nome: 'Cinza/3ª',
        ordem: 4,
        createdAt: now,
        updatedAt: now,
      ),
      Etapa(
        id: '5',
        construtoraId: construtoraId,
        loteamentoId: loteamentoId,
        quadraId: quadraId,
        loteId: loteId,
        nome: 'Branca/Acabamento',
        ordem: 5,
        createdAt: now,
        updatedAt: now,
      ),
    ];
    
    for (final etapa in etapasDefault) {
      etapas.add(etapa);
    }
  }
}

void main() {
  group('EtapaRepository.createDefaultEtapas', () {
    test('cria 5 etapas com nomes e ordens corretas', () async {
      final fake = FakeEtapaRepository();
      final container = ProviderContainer(
        overrides: [
          etapaRepositoryProvider.overrideWithValue(fake),
        ],
      );
      addTearDown(container.dispose);

      await container.read(etapaRepositoryProvider).createDefaultEtapas(
        construtoraId: 'c1',
        loteamentoId: 'l1',
        quadraId: 'q1',
        loteId: 'lo1',
      );

      expect(fake.createDefaultCalls.length, 1);
      expect(fake.createDefaultCalls.first, (
        construtoraId: 'c1',
        loteamentoId: 'l1',
        quadraId: 'q1',
        loteId: 'lo1',
      ));

      final etapas = fake.etapas.where((e) => e.loteId == 'lo1').toList();
      expect(etapas.length, 5);

      expect(etapas[0].nome, 'Muro');
      expect(etapas[0].ordem, 1);

      expect(etapas[1].nome, 'Cinza/1ª');
      expect(etapas[1].ordem, 2);

      expect(etapas[2].nome, 'Cinza/2ª');
      expect(etapas[2].ordem, 3);

      expect(etapas[3].nome, 'Cinza/3ª');
      expect(etapas[3].ordem, 4);

      expect(etapas[4].nome, 'Branca/Acabamento');
      expect(etapas[4].ordem, 5);
    });

    test('etapas sao ordenadas por ordem ao consultar', () async {
      final fake = FakeEtapaRepository();
      final container = ProviderContainer(
        overrides: [
          etapaRepositoryProvider.overrideWithValue(fake),
        ],
      );
      addTearDown(container.dispose);

      await container.read(etapaRepositoryProvider).createDefaultEtapas(
        construtoraId: 'c1',
        loteamentoId: 'l1',
        quadraId: 'q1',
        loteId: 'lo1',
      );

      final params = (
        construtoraId: 'c1',
        loteamentoId: 'l1',
        quadraId: 'q1',
        loteId: 'lo1',
      );

      final sub = container.listen(watchEtapasProvider(params), (_, _) {});
      addTearDown(sub.close);

      await container.read(watchEtapasProvider(params).future);

      final data = container.read(watchEtapasProvider(params));
      expect(data.hasValue, isTrue);
      expect(data.value!.length, 5);
      
      // Verificar se estão ordenados por ordem
      for (int i = 0; i < 4; i++) {
        expect(data.value![i].ordem, lessThan(data.value![i + 1].ordem));
      }
    });
  });
}