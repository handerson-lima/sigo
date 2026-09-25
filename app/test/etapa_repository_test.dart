import 'package:app/src/features/etapas/data/etapa_repository.dart';
import 'package:app/src/features/etapas/domain/etapa.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EtapaTipo', () {
    test('define exatamente as 5 etapas fixas na ordem do domínio', () {
      expect(EtapaTipo.values, hasLength(5));
      expect(EtapaTipo.values.map((t) => t.ordem).toList(), [1, 2, 3, 4, 5]);
      expect(EtapaTipo.values.map((t) => t.label).toList(), [
        'Muro',
        'Cinza/1ª',
        'Cinza/2ª',
        'Cinza/3ª',
        'Branca/Acabamento',
      ]);
    });
  });

  group('EtapaRepository.buildDefaultEtapas', () {
    test('cria 5 etapas com nomes, ordens e foreign keys corretas', () {
      var counter = 0;
      final now = DateTime(2026, 9, 25, 10);

      final etapas = EtapaRepository.buildDefaultEtapas(
        construtoraId: 'c1',
        loteamentoId: 'lt1',
        quadraId: 'qd1',
        loteId: 'lo1',
        newId: (_) => 'et${++counter}',
        now: now,
      );

      expect(etapas, hasLength(5));

      const esperado = [
        ('Muro', 1),
        ('Cinza/1ª', 2),
        ('Cinza/2ª', 3),
        ('Cinza/3ª', 4),
        ('Branca/Acabamento', 5),
      ];

      for (var i = 0; i < esperado.length; i++) {
        final etapa = etapas[i];
        expect(etapa.nome, esperado[i].$1);
        expect(etapa.ordem, esperado[i].$2);
        expect(etapa.construtoraId, 'c1');
        expect(etapa.loteamentoId, 'lt1');
        expect(etapa.quadraId, 'qd1');
        expect(etapa.loteId, 'lo1');
        expect(etapa.createdAt, now);
        expect(etapa.updatedAt, now);
      }

      expect(etapas.map((e) => e.id).toSet(), {
        'et1',
        'et2',
        'et3',
        'et4',
        'et5',
      });
    });

    test('ordens são estritamente crescentes', () {
      var counter = 0;
      final etapas = EtapaRepository.buildDefaultEtapas(
        construtoraId: 'c1',
        loteamentoId: 'lt1',
        quadraId: 'qd1',
        loteId: 'lo1',
        newId: (_) => 'et${++counter}',
        now: DateTime(2026),
      );

      for (var i = 0; i < etapas.length - 1; i++) {
        expect(etapas[i].ordem, lessThan(etapas[i + 1].ordem));
      }
    });
  });
}
