import 'package:app/src/features/etapas/data/etapa_repository.dart';
import 'package:app/src/features/etapas/domain/etapa.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
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

  group('EtapaRepository.vincularEquipe / desvincularEquipe', () {
    test('vincula e desvincula equipe preservando FKs e atualizando updatedAt', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = EtapaRepository(firestore);
      final createdAt = DateTime(2026, 1, 1);

      await firestore.collection('etapas').doc('lo1_muro').set(
            Etapa(
              id: 'lo1_muro',
              construtoraId: 'c1',
              loteamentoId: 'lt1',
              quadraId: 'qd1',
              loteId: 'lo1',
              nome: 'Muro',
              ordem: 1,
              createdAt: createdAt,
              updatedAt: createdAt,
            ).toJson(),
          );

      await repo.vincularEquipe(
        etapaId: 'lo1_muro',
        equipeId: 'eq-rh-1',
        equipeNome: 'Equipe Alpha',
        construtoraId: 'c1',
        loteId: 'lo1',
      );

      final linkedSnap =
          await firestore.collection('etapas').doc('lo1_muro').get();
      final linkedData = linkedSnap.data()!;
      expect(linkedData['equipeId'], 'eq-rh-1');
      expect(linkedData['equipeNome'], 'Equipe Alpha');
      expect(linkedData['construtoraId'], 'c1');
      expect(linkedData['loteamentoId'], 'lt1');
      expect(linkedData['quadraId'], 'qd1');
      expect(linkedData['loteId'], 'lo1');
      expect(linkedData['updatedAt'], isNot(createdAt.toIso8601String()));

      await repo.desvincularEquipe(
        etapaId: 'lo1_muro',
        construtoraId: 'c1',
        loteId: 'lo1',
      );

      final unlinkedSnap =
          await firestore.collection('etapas').doc('lo1_muro').get();
      final unlinkedData = unlinkedSnap.data()!;
      expect(unlinkedData['equipeId'], isNull);
      expect(unlinkedData['equipeNome'], isNull);
      expect(unlinkedData['construtoraId'], 'c1');
      expect(unlinkedData['loteId'], 'lo1');
    });

    test('rejeita FK incompatível ao vincular equipe', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = EtapaRepository(firestore);
      final now = DateTime(2026, 1, 1);

      await firestore.collection('etapas').doc('lo1_muro').set(
            Etapa(
              id: 'lo1_muro',
              construtoraId: 'c1',
              loteamentoId: 'lt1',
              quadraId: 'qd1',
              loteId: 'lo1',
              nome: 'Muro',
              ordem: 1,
              createdAt: now,
              updatedAt: now,
            ).toJson(),
          );

      expect(
        () => repo.vincularEquipe(
          etapaId: 'lo1_muro',
          equipeId: 'eq-1',
          equipeNome: 'Equipe A',
          construtoraId: 'outra-construtora',
          loteId: 'lo1',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
