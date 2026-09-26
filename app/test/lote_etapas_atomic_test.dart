import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:app/src/features/lotes/domain/lote.dart';
import 'package:app/src/features/lotes/data/lote_repository.dart';
import 'package:app/src/features/etapas/data/etapa_repository.dart';

void main() {
  test('createLoteComEtapas cria lote e 5 etapas atomicamente com IDs deterministicos', () async {
    final fakeFirestore = FakeFirebaseFirestore();
    final etapaRepository = EtapaRepository(fakeFirestore);
    final loteRepository = LoteRepository(fakeFirestore, etapaRepository);

    final lote = Lote(
      id: 'lo1',
      construtoraId: 'c1',
      loteamentoId: 'lt1',
      quadraId: 'qd1',
      name: 'Lote 01',
      createdAt: DateTime(2023, 1, 1),
      updatedAt: DateTime(2023, 1, 1),
    );

    await loteRepository.createLoteComEtapas(lote);

    final lotesSnapshot = await fakeFirestore.collection('lotes').get();
    expect(lotesSnapshot.docs.length, 1);
    expect(lotesSnapshot.docs.first.id, 'lo1');

    final etapasSnapshot = await fakeFirestore.collection('etapas').get();
    expect(etapasSnapshot.docs.length, 5);

    final expectedIds = {
      'lo1_muro',
      'lo1_cinza1',
      'lo1_cinza2',
      'lo1_cinza3',
      'lo1_branca',
    };

    final savedIds = etapasSnapshot.docs.map((doc) => doc.id).toSet();
    expect(savedIds, expectedIds);
  });
}
