import 'package:app/src/core/contracts.dart';
import 'dart:async';

import 'package:app/src/features/etapas/data/etapa_repository.dart';
import 'package:app/src/features/etapas/domain/etapa.dart';
import 'package:app/src/features/loteamentos/data/loteamento_repository.dart';
import 'package:app/src/features/loteamentos/domain/loteamento.dart';
import 'package:app/src/features/lotes/data/lote_repository.dart';
import 'package:app/src/features/lotes/domain/lote.dart';
import 'package:app/src/features/quadras/data/quadra_repository.dart';
import 'package:app/src/features/quadras/domain/quadra.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SpyWriteBatch implements WriteBatch {
  final WriteBatch _inner;
  final void Function(int opCount) _onBeforeCommit;
  int _ops = 0;

  _SpyWriteBatch(this._inner, this._onBeforeCommit);

  @override
  void delete(DocumentReference<Object?> document) {
    _ops++;
    _inner.delete(document);
  }

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {
    _ops++;
    _inner.set<T>(document, data, options);
  }

  @override
  void update<T>(DocumentReference<T> document, T data) {
    _ops++;
    _inner.update<T>(document, data);
  }

  @override
  Future<void> commit() async {
    _onBeforeCommit(_ops);
    await _inner.commit();
  }
}

class _SpyFirestore implements FirebaseFirestore {
  final FakeFirebaseFirestore _inner;
  final List<int> batchOpCounts = [];
  int transactionCount = 0;
  final int? failOnBatchNumber;

  _SpyFirestore(this._inner, {this.failOnBatchNumber});

  @override
  WriteBatch batch() {
    return _SpyWriteBatch(_inner.batch(), (opCount) {
      batchOpCounts.add(opCount);
      if (failOnBatchNumber != null &&
          batchOpCounts.length == failOnBatchNumber) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'aborted',
          message: 'Simulated batch commit failure',
        );
      }
    });
  }

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      _inner.collection(collectionPath);

  @override
  DocumentReference<Map<String, dynamic>> doc(String documentPath) =>
      _inner.doc(documentPath);

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) {
    transactionCount++;
    return _inner.runTransaction<T>(
      transactionHandler,
      timeout: timeout,
      maxAttempts: maxAttempts,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Lote _makeLote(String id, {String quadraId = 'qd1', String loteamentoId = 'lt1'}) {
  final now = DateTime(2026, 1, 1);
  return Lote(
    id: id,
    construtoraId: 'c1',
    loteamentoId: loteamentoId,
    quadraId: quadraId,
    name: 'Lote $id',
    frenteM: 10.0,
    profundidadeM: 20.0,
    areaTerrenoM2: Lote.calcularAreaTerreno(10.0, 20.0),
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('Modelos de domínio sem geometria e retrocompatibilidade JSON', () {
    test('Loteamento desserializa JSON legado e suporta novos campos + copyWith', () {
      final legacyJson = <String, dynamic>{
        'id': 'lt1',
        'construtoraId': 'c1',
        'name': 'Loteamento Legado',
        'createdAt': '2026-01-01T10:00:00.000',
        'updatedAt': '2026-01-02T10:00:00.000',
      };

      final legacy = Loteamento.fromJson(legacyJson);
      expect(legacy.id, 'lt1');
      expect(legacy.name, 'Loteamento Legado');
      expect(legacy.bairro, isNull);
      expect(legacy.cidade, isNull);
      expect(legacy.uf, isNull);
      expect(legacy.proprietarioNome, isNull);
      expect(legacy.proprietarioDocumento, isNull);
      expect(legacy.responsavelTecnicoNome, isNull);
      expect(legacy.responsavelTecnicoRegistro, isNull);

      final updated = legacy.copyWith(
        bairro: 'Estivas',
        cidade: 'Extremoz',
        uf: 'RN',
        proprietarioNome: 'CARNEIRO E OLIVEIRA EMPREENDIMENTOS LTDA',
        proprietarioDocumento: '69.307.863/0001-02',
        responsavelTecnicoNome: 'JOCSA RAMOS VARELA',
        responsavelTecnicoRegistro: '2116022975',
      );
      final json = updated.toJson();
      expect(json.containsKey('geometry'), isFalse);
      final roundTrip = Loteamento.fromJson(json);
      expect(roundTrip.bairro, 'Estivas');
      expect(roundTrip.cidade, 'Extremoz');
      expect(roundTrip.uf, 'RN');
      expect(roundTrip.proprietarioNome, 'CARNEIRO E OLIVEIRA EMPREENDIMENTOS LTDA');
      expect(roundTrip.proprietarioDocumento, '69.307.863/0001-02');
      expect(roundTrip.responsavelTecnicoNome, 'JOCSA RAMOS VARELA');
      expect(roundTrip.responsavelTecnicoRegistro, '2116022975');
    });

    test('Quadra desserializa JSON legado (inclusive ignorando geometry antiga) e suporta logradouroPadrao + copyWith', () {
      final legacyJson = <String, dynamic>{
        'id': 'qd1',
        'construtoraId': 'c1',
        'loteamentoId': 'lt1',
        'name': 'Quadra 28',
        'geometry': '{"type":"Polygon","coordinates":[]}',
        'createdAt': '2026-01-01T10:00:00.000',
        'updatedAt': '2026-01-02T10:00:00.000',
      };

      final legacy = Quadra.fromJson(legacyJson);
      expect(legacy.logradouroPadrao, isNull);
      expect(legacy.toJson().containsKey('geometry'), isFalse);

      final updated = legacy.copyWith(logradouroPadrao: 'Rua Sandoval Wanderley');
      final roundTrip = Quadra.fromJson(updated.toJson());
      expect(roundTrip.logradouroPadrao, 'Rua Sandoval Wanderley');
    });

    test('Lote desserializa JSON legado com campos ausentes ou null e suporta medidas, quadro de áreas, recuos e resumos', () {
      final legacyJson = <String, dynamic>{
        'id': 'lo1',
        'construtoraId': 'c1',
        'loteamentoId': 'lt1',
        'quadraId': 'qd1',
        'name': 'Lote 31',
        'geometry': '{"type":"Polygon","coordinates":[]}',
        'progressoPercentual': null,
        'etapasConcluidasCount': null,
        'etapasTotalCount': null,
        'statusEtapasMap': null,
        'equipesVinculadas': null,
        'funcionariosVinculados': null,
        'createdAt': '2026-01-01T10:00:00.000',
        'updatedAt': '2026-01-02T10:00:00.000',
      };

      final legacy = Lote.fromJson(legacyJson);
      expect(legacy.frenteM, isNull);
      expect(legacy.profundidadeM, isNull);
      expect(legacy.areaTerrenoM2, isNull);
      expect(legacy.areaConstruidaM2, isNull);
      expect(legacy.logradouro, isNull);
      expect(legacy.taxaOcupacaoPercent, isNull);
      expect(legacy.coeficienteAproveitamento, isNull);
      expect(legacy.areaPermeavelM2, isNull);
      expect(legacy.taxaPermeabilidadePercent, isNull);
      expect(legacy.areaImpermeavelM2, isNull);
      expect(legacy.recuoFrontalM, isNull);
      expect(legacy.recuoFundoM, isNull);
      expect(legacy.recuoLateralEsquerdoM, isNull);
      expect(legacy.recuoLateralDireitoM, isNull);
      expect(legacy.proprietarioNome, isNull);
      expect(legacy.proprietarioDocumento, isNull);
      expect(legacy.responsavelTecnicoNome, isNull);
      expect(legacy.responsavelTecnicoRegistro, isNull);
      expect(legacy.dataProjeto, isNull);
      expect(legacy.progressoPercentual, 0);
      expect(legacy.etapasConcluidasCount, 0);
      expect(legacy.etapasTotalCount, 5);
      expect(legacy.statusEtapasMap, {
        'muro': 'pendente',
        'cinza1': 'pendente',
        'cinza2': 'pendente',
        'cinza3': 'pendente',
        'branca': 'pendente',
      });
      expect(legacy.equipesVinculadas, isEmpty);
      expect(legacy.funcionariosVinculados, isEmpty);
      expect(legacy.toJson().containsKey('geometry'), isFalse);

      expect(Lote.calcularAreaTerreno(10.0, 20.0), 200.0);
      expect(Lote.calcularAreaTerreno(null, 20.0), isNull);
      expect(Lote.calcularAreaTerreno(10.0, 0), isNull);
      expect(Lote.calcularAreaTerreno(-5.0, 20.0), isNull);

      final completo = legacy.copyWith(
        frenteM: 10.0,
        profundidadeM: 20.0,
        areaTerrenoM2: Lote.calcularAreaTerreno(10.0, 20.0),
        areaConstruidaM2: 49.96,
        logradouro: 'Rua Sandoval Wanderley, s/n',
        taxaOcupacaoPercent: 24.98,
        coeficienteAproveitamento: 0.24,
        areaPermeavelM2: 112.46,
        taxaPermeabilidadePercent: 56.23,
        areaImpermeavelM2: 37.58,
        recuoFrontalM: 5.05,
        recuoFundoM: 5.94,
        recuoLateralEsquerdoM: 1.43,
        recuoLateralDireitoM: 1.43,
        proprietarioNome: 'Proprietário X',
        proprietarioDocumento: '000.000.000-00',
        responsavelTecnicoNome: 'Engenheiro Y',
        responsavelTecnicoRegistro: 'CREA-RN 123',
        dataProjeto: 'outubro/26',
        progressoPercentual: 60,
        etapasConcluidasCount: 3,
      );
      final roundTrip = Lote.fromJson(completo.toJson());
      expect(roundTrip.frenteM, 10.0);
      expect(roundTrip.profundidadeM, 20.0);
      expect(roundTrip.areaTerrenoM2, 200.0);
      expect(roundTrip.areaConstruidaM2, 49.96);
      expect(roundTrip.taxaOcupacaoPercent, 24.98);
      expect(roundTrip.coeficienteAproveitamento, 0.24);
      expect(roundTrip.areaPermeavelM2, 112.46);
      expect(roundTrip.taxaPermeabilidadePercent, 56.23);
      expect(roundTrip.areaImpermeavelM2, 37.58);
      expect(roundTrip.recuoFrontalM, 5.05);
      expect(roundTrip.recuoFundoM, 5.94);
      expect(roundTrip.recuoLateralEsquerdoM, 1.43);
      expect(roundTrip.recuoLateralDireitoM, 1.43);
      expect(roundTrip.dataProjeto, 'outubro/26');
      expect(roundTrip.progressoPercentual, 60);
      expect(roundTrip.etapasConcluidasCount, 3);
    });

    test('Etapa desserializa JSON legado e resolve EtapaTipo corretamente', () {
      final legacyJson = <String, dynamic>{
        'id': 'lo1_cinza1',
        'construtoraId': 'c1',
        'loteamentoId': 'lt1',
        'quadraId': 'qd1',
        'loteId': 'lo1',
        'nome': 'Cinza/1ª',
        'ordem': 2,
        'responsavelId': null,
        'createdAt': '2026-01-01T10:00:00.000',
        'updatedAt': '2026-01-02T10:00:00.000',
      };

      final legacy = Etapa.fromJson(legacyJson);
      expect(legacy.status, 'pendente');
      expect(legacy.percentual, 0);
      expect(legacy.equipeId, isNull);
      expect(legacy.equipeNome, isNull);
      expect(legacy.funcionarioId, isNull);
      expect(legacy.funcionarioNome, isNull);
      expect(legacy.tipo, EtapaTipo.cinza1);

      expect(
        resolveEtapaTipo(id: 'custom', ordem: 5, nome: 'Qualquer'),
        EtapaTipo.branca,
      );
      expect(
        resolveEtapaTipo(id: 'custom', nome: 'Branca/Acabamento'),
        EtapaTipo.branca,
      );

      final updated = legacy.copyWith(
        status: 'em_andamento',
        percentual: 50,
        equipeId: 'eq1',
        equipeNome: 'Equipe A',
        funcionarioId: 'f1',
        funcionarioNome: 'João',
      );
      final roundTrip = Etapa.fromJson(updated.toJson());
      expect(roundTrip.status, 'em_andamento');
      expect(roundTrip.percentual, 50);
      expect(roundTrip.equipeId, 'eq1');
      expect(roundTrip.equipeNome, 'Equipe A');
      expect(roundTrip.funcionarioId, 'f1');
      expect(roundTrip.funcionarioNome, 'João');
    });
  });

  group('Repositórios — criação atômica, batches <= 500, progresso e lotação', () {
    test('createLoteComEtapas cria lote e 5 etapas atomicamente com status pendente e 0%', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final etapaRepository = EtapaRepository(fakeFirestore);
      final loteRepository = LoteRepository(fakeFirestore, etapaRepository);

      final lote = _makeLote('lo1');
      await loteRepository.createLoteComEtapas(lote);

      final lotesSnapshot = await fakeFirestore.collection('lotes').get();
      expect(lotesSnapshot.docs.length, 1);
      final savedLote = Lote.fromJson(lotesSnapshot.docs.first.data());
      expect(savedLote.progressoPercentual, 0);
      expect(savedLote.etapasConcluidasCount, 0);
      expect(savedLote.etapasTotalCount, 5);

      final etapasSnapshot = await fakeFirestore.collection('etapas').get();
      expect(etapasSnapshot.docs.length, 5);
      expect(
        etapasSnapshot.docs.map((doc) => doc.id).toSet(),
        {
          'lo1_muro',
          'lo1_cinza1',
          'lo1_cinza2',
          'lo1_cinza3',
          'lo1_branca',
        },
      );
      for (final doc in etapasSnapshot.docs) {
        final etapa = Etapa.fromJson(doc.data());
        expect(etapa.status, 'pendente');
        expect(etapa.percentual, 0);
      }
    });

    test('createLotesEmMassa com 90 lotes executa em 2 batches (500 + 40 ops) e persiste 90 lotes + 450 etapas', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final spyFirestore = _SpyFirestore(fakeFirestore);
      final etapaRepository = EtapaRepository(spyFirestore);
      final loteRepository = LoteRepository(spyFirestore, etapaRepository);

      final lotes = List.generate(90, (i) => _makeLote('l_${i + 1}'));
      await loteRepository.createLotesEmMassa(lotes);

      expect(spyFirestore.batchOpCounts, [500, 40]);
      expect((await fakeFirestore.collection('lotes').get()).docs.length, 90);
      expect((await fakeFirestore.collection('etapas').get()).docs.length, 450);
    });

    test('createLotesEmMassa propaga erro se algum commit falhar', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final spyFirestore = _SpyFirestore(fakeFirestore, failOnBatchNumber: 2);
      final etapaRepository = EtapaRepository(spyFirestore);
      final loteRepository = LoteRepository(spyFirestore, etapaRepository);

      final lotes = List.generate(90, (i) => _makeLote('l_${i + 1}'));
      await expectLater(
        loteRepository.createLotesEmMassa(lotes),
        throwsA(isA<FirebaseException>()),
      );
    });

    test('createQuadraComLotes respeita teto de 500 ops por batch', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final spyFirestore = _SpyFirestore(fakeFirestore);
      final quadraRepository = QuadraRepository(spyFirestore);

      final now = DateTime(2026, 1, 1);
      final quadra = Quadra(
        id: 'qd1',
        construtoraId: 'c1',
        loteamentoId: 'lt1',
        name: 'Quadra 1',
        logradouroPadrao: 'Rua A',
        createdAt: now,
        updatedAt: now,
      );
      final lotes = List.generate(90, (i) => _makeLote('ql_${i + 1}'));

      await quadraRepository.createQuadraComLotes(quadra: quadra, lotes: lotes);

      expect(spyFirestore.batchOpCounts, [500, 41]);
      expect((await fakeFirestore.collection('quadras').get()).docs.length, 1);
      expect((await fakeFirestore.collection('lotes').get()).docs.length, 90);
      expect((await fakeFirestore.collection('etapas').get()).docs.length, 450);
    });

    test('createLoteamentoEmMassa com 1 loteamento, 2 quadras e 90 lotes (543 ops) executa em 2 batches <= 500', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final spyFirestore = _SpyFirestore(fakeFirestore);
      final loteamentoRepository = LoteamentoRepository(spyFirestore);

      final now = DateTime(2026, 1, 1);
      final loteamento = Loteamento(
        id: 'lt1',
        construtoraId: 'c1',
        name: 'Jardim Botanico',
        bairro: 'Estivas',
        cidade: 'Extremoz',
        uf: 'RN',
        createdAt: now,
        updatedAt: now,
      );
      final quadras = [
        Quadra(
          id: 'qd1',
          construtoraId: 'c1',
          loteamentoId: 'lt1',
          name: 'Quadra 1',
          createdAt: now,
          updatedAt: now,
        ),
        Quadra(
          id: 'qd2',
          construtoraId: 'c1',
          loteamentoId: 'lt1',
          name: 'Quadra 2',
          createdAt: now,
          updatedAt: now,
        ),
      ];
      final lotes = List.generate(
        90,
        (i) => _makeLote('lm_${i + 1}', quadraId: i < 45 ? 'qd1' : 'qd2'),
      );

      await loteamentoRepository.createLoteamentoEmMassa(
        loteamento: loteamento,
        quadras: quadras,
        lotes: lotes,
      );

      expect(spyFirestore.batchOpCounts, [500, 44]);
      expect(
        (await fakeFirestore.collection('loteamentos').get()).docs.length,
        1,
      );
      final mirrorObra = await fakeFirestore
          .collection('construtoras')
          .doc('c1')
          .collection('obras')
          .doc('lt1')
          .get();
      expect(mirrorObra.exists, isTrue);
      expect(mirrorObra.data()?['name'], 'Jardim Botanico');
      expect(mirrorObra.data()?['isActive'], isTrue);
      expect((await fakeFirestore.collection('quadras').get()).docs.length, 2);
      expect((await fakeFirestore.collection('lotes').get()).docs.length, 90);
      expect((await fakeFirestore.collection('etapas').get()).docs.length, 450);
    });

    test('updateLoteamento e updateLote atualizam campos no Firestore', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final loteamentoRepo = LoteamentoRepository(fakeFirestore);
      final etapaRepo = EtapaRepository(fakeFirestore);
      final loteRepo = LoteRepository(fakeFirestore, etapaRepo);

      final now = DateTime(2026, 1, 1);
      final lt = Loteamento(
        id: 'lt1',
        construtoraId: 'c1',
        name: 'Original',
        createdAt: now,
        updatedAt: now,
      );
      await loteamentoRepo.createLoteamento(lt);
      await loteamentoRepo.updateLoteamento(
        lt.copyWith(name: 'Atualizado', cidade: 'Natal', uf: 'RN'),
      );

      final savedLt = Loteamento.fromJson(
        (await fakeFirestore.collection('loteamentos').doc('lt1').get()).data()!,
      );
      expect(savedLt.name, 'Atualizado');
      expect(savedLt.cidade, 'Natal');
      expect(savedLt.uf, 'RN');

      final lote = _makeLote('lo1');
      await loteRepo.createLoteComEtapas(lote);
      await loteRepo.updateLote(
        lote.copyWith(areaConstruidaM2: 52.5, logradouro: 'Rua Nova'),
      );

      final savedLote = Lote.fromJson(
        (await fakeFirestore.collection('lotes').doc('lo1').get()).data()!,
      );
      expect(savedLote.areaConstruidaM2, 52.5);
      expect(savedLote.logradouro, 'Rua Nova');
    });

    test('watchLote e watchLoteProvider emitem lote e atualizações em tempo real', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final etapaRepo = EtapaRepository(fakeFirestore);
      final loteRepo = LoteRepository(fakeFirestore, etapaRepo);

      final container = ProviderContainer(
        overrides: [loteRepositoryProvider.overrideWithValue(loteRepo)],
      );
      addTearDown(container.dispose);

      expect(await loteRepo.watchLote('lo1').first, isNull);

      final sub = container.listen(watchLoteProvider('lo1'), (_, _) {});
      addTearDown(sub.close);

      await loteRepo.createLoteComEtapas(_makeLote('lo1'));
      final emitted = await container.read(watchLoteProvider('lo1').future);
      expect(emitted, isNotNull);
      expect(emitted!.id, 'lo1');

      final updatedCompleter = Completer<Lote?>();
      final updateSub = container.listen<AsyncValue<Lote?>>(
        watchLoteProvider('lo1'),
        (_, next) {
          if (next.value?.areaConstruidaM2 == 65.0 &&
              !updatedCompleter.isCompleted) {
            updatedCompleter.complete(next.value);
          }
        },
      );
      addTearDown(updateSub.close);

      await loteRepo.updateLote(emitted.copyWith(areaConstruidaM2: 65.0));
      final updated = await updatedCompleter.future.timeout(
        const Duration(seconds: 5),
      );
      expect(updated?.areaConstruidaM2, 65.0);
    });

    test('updateEtapaProgresso recalcula progressoPercentual, etapasConcluidasCount e statusEtapasMap atomicamente', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final etapaRepo = EtapaRepository(fakeFirestore);
      final loteRepo = LoteRepository(fakeFirestore, etapaRepo);

      await loteRepo.createLoteComEtapas(_makeLote('lo1'));

      await etapaRepo.updateEtapaProgresso(
        loteId: 'lo1',
        etapaId: 'lo1_muro',
        status: 'concluida',
      );
      await etapaRepo.updateEtapaProgresso(
        loteId: 'lo1',
        etapaId: 'lo1_cinza1',
        status: 'em_andamento',
      );

      final muro = Etapa.fromJson(
        (await fakeFirestore.collection('etapas').doc('lo1_muro').get()).data()!,
      );
      final cinza1 = Etapa.fromJson(
        (await fakeFirestore.collection('etapas').doc('lo1_cinza1').get())
            .data()!,
      );
      expect(muro.status, 'concluida');
      expect(muro.percentual, 100);
      expect(cinza1.status, 'em_andamento');
      expect(cinza1.percentual, 50);

      var lote = Lote.fromJson(
        (await fakeFirestore.collection('lotes').doc('lo1').get()).data()!,
      );
      expect(lote.progressoPercentual, 30);
      expect(lote.etapasConcluidasCount, 1);
      expect(lote.etapasTotalCount, 5);
      expect(lote.statusEtapasMap, {
        'muro': 'concluida',
        'cinza1': 'em_andamento',
        'cinza2': 'pendente',
        'cinza3': 'pendente',
        'branca': 'pendente',
      });

      await etapaRepo.updateEtapaProgresso(
        loteId: 'lo1',
        etapaId: 'lo1_muro',
        status: 'pendente',
      );
      final muroReset = Etapa.fromJson(
        (await fakeFirestore.collection('etapas').doc('lo1_muro').get()).data()!,
      );
      expect(muroReset.percentual, 0);
      lote = Lote.fromJson(
        (await fakeFirestore.collection('lotes').doc('lo1').get()).data()!,
      );
      expect(lote.progressoPercentual, 10);
      expect(lote.etapasConcluidasCount, 0);
    });

    test('updateEtapaProgresso cria etapas padrão faltantes na base de cálculo', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final etapaRepo = EtapaRepository(fakeFirestore);

      await fakeFirestore.collection('lotes').doc('lo_legado').set(
        _makeLote('lo_legado').toJson(),
      );

      await etapaRepo.updateEtapaProgresso(
        loteId: 'lo_legado',
        etapaId: 'lo_legado_muro',
        status: 'concluida',
      );

      final etapasSnap = await fakeFirestore
          .collection('etapas')
          .where('loteId', isEqualTo: 'lo_legado')
          .get();
      expect(etapasSnap.docs.length, 5);

      final lote = Lote.fromJson(
        (await fakeFirestore.collection('lotes').doc('lo_legado').get())
            .data()!,
      );
      expect(lote.progressoPercentual, 20);
      expect(lote.etapasConcluidasCount, 1);
      expect(lote.statusEtapasMap['muro'], 'concluida');
      expect(lote.statusEtapasMap['cinza1'], 'pendente');
    });

    test('atribuir/removerEquipe e atribuir/removerFuncionario evitam duplicação, sincronizam etapa e ignoram remoção inexistente', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final etapaRepo = EtapaRepository(fakeFirestore);
      final loteRepo = LoteRepository(fakeFirestore, etapaRepo);

      await loteRepo.createLoteComEtapas(_makeLote('lo1'));

      // Atribuição geral + por etapa sem duplicação do mesmo vínculo+etapa
      await loteRepo.atribuirEquipe(
        loteId: 'lo1',
        equipeId: 'eq1',
        equipeNome: 'Equipe Alvenaria A',
        leaderName: 'Carlos',
      );
      await loteRepo.atribuirEquipe(
        loteId: 'lo1',
        equipeId: 'eq1',
        equipeNome: 'Equipe Alvenaria A',
        leaderName: 'Carlos',
      );
      await loteRepo.atribuirEquipe(
        loteId: 'lo1',
        equipeId: 'eq1',
        equipeNome: 'Equipe Alvenaria A',
        leaderName: 'Carlos',
        etapaId: 'lo1_muro',
      );
      await loteRepo.atribuirEquipe(
        loteId: 'lo1',
        equipeId: 'eq1',
        equipeNome: 'Equipe Alvenaria A2',
        leaderName: 'Carlos',
        etapaId: 'lo1_muro',
      );

      await loteRepo.atribuirFuncionario(
        loteId: 'lo1',
        funcionarioId: 'f1',
        funcionarioNome: 'João Silva',
        role: 'Pedreiro',
        etapaId: 'lo1_cinza1',
      );
      await loteRepo.atribuirFuncionario(
        loteId: 'lo1',
        funcionarioId: 'f1',
        funcionarioNome: 'João Silva',
        role: 'Pedreiro',
        etapaId: 'lo1_cinza1',
      );

      var lote = Lote.fromJson(
        (await fakeFirestore.collection('lotes').doc('lo1').get()).data()!,
      );
      expect(lote.equipesVinculadas.length, 2);
      expect(
        lote.equipesVinculadas
            .firstWhere((e) => e['etapaId'] == 'lo1_muro')['name'],
        'Equipe Alvenaria A2',
      );
      expect(lote.funcionariosVinculados.length, 1);

      var muro = Etapa.fromJson(
        (await fakeFirestore.collection('etapas').doc('lo1_muro').get()).data()!,
      );
      var cinza1 = Etapa.fromJson(
        (await fakeFirestore.collection('etapas').doc('lo1_cinza1').get())
            .data()!,
      );
      expect(muro.equipeId, 'eq1');
      expect(muro.equipeNome, 'Equipe Alvenaria A2');
      expect(cinza1.funcionarioId, 'f1');
      expect(cinza1.funcionarioNome, 'João Silva');

      // Remoção por etapa limpa etapa e mantém vínculo geral
      await loteRepo.removerEquipe(
        loteId: 'lo1',
        equipeId: 'eq1',
        etapaId: 'lo1_muro',
      );
      await loteRepo.removerFuncionario(
        loteId: 'lo1',
        funcionarioId: 'f1',
        etapaId: 'lo1_cinza1',
      );

      // Remoções inexistentes não falham
      await loteRepo.removerEquipe(
        loteId: 'lo1',
        equipeId: 'eq_inexistente',
        etapaId: 'lo1_muro',
      );
      await loteRepo.removerFuncionario(
        loteId: 'lo1',
        funcionarioId: 'f_inexistente',
      );

      lote = Lote.fromJson(
        (await fakeFirestore.collection('lotes').doc('lo1').get()).data()!,
      );
      expect(lote.equipesVinculadas.length, 1);
      expect(lote.equipesVinculadas.first['etapaId'], isNull);
      expect(lote.funcionariosVinculados, isEmpty);

      muro = Etapa.fromJson(
        (await fakeFirestore.collection('etapas').doc('lo1_muro').get()).data()!,
      );
      cinza1 = Etapa.fromJson(
        (await fakeFirestore.collection('etapas').doc('lo1_cinza1').get())
            .data()!,
      );
      expect(muro.equipeId, isNull);
      expect(muro.equipeNome, isNull);
      expect(cinza1.funcionarioId, isNull);
      expect(cinza1.funcionarioNome, isNull);
    });
  });

  group('Hardening e cobertura de lacunas — contratos, domínio, transações e validações', () {
    test('commitFirestoreBatches valida maxOpsPerBatch no intervalo [1, 500]', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      await expectLater(
        commitFirestoreBatches(fakeFirestore, const [], maxOpsPerBatch: 0),
        throwsA(isA<RangeError>()),
      );
      await expectLater(
        commitFirestoreBatches(fakeFirestore, const [], maxOpsPerBatch: -1),
        throwsA(isA<RangeError>()),
      );
      await expectLater(
        commitFirestoreBatches(fakeFirestore, const [], maxOpsPerBatch: 501),
        throwsA(isA<RangeError>()),
      );
      expect(await commitFirestoreBatches(fakeFirestore, const []), 0);
    });

    test('Timestamp.fromDate é desserializado por Loteamento, Quadra, Lote, Etapa e FakeFirebaseFirestore', () async {
      final createdAt = DateTime(2026, 3, 10, 9, 30);
      final updatedAt = DateTime(2026, 3, 11, 14, 45);
      final tsCreated = Timestamp.fromDate(createdAt);
      final tsUpdated = Timestamp.fromDate(updatedAt);

      final lt = Loteamento.fromJson({
        'id': 'lt1',
        'construtoraId': 'c1',
        'name': 'Loteamento TS',
        'createdAt': tsCreated,
        'updatedAt': tsUpdated,
      });
      final qd = Quadra.fromJson({
        'id': 'qd1',
        'construtoraId': 'c1',
        'loteamentoId': 'lt1',
        'name': 'Quadra TS',
        'createdAt': tsCreated,
        'updatedAt': tsUpdated,
      });
      final lo = Lote.fromJson({
        'id': 'lo1',
        'construtoraId': 'c1',
        'loteamentoId': 'lt1',
        'quadraId': 'qd1',
        'name': 'Lote TS',
        'createdAt': tsCreated,
        'updatedAt': tsUpdated,
      });
      final et = Etapa.fromJson({
        'id': 'lo1_muro',
        'construtoraId': 'c1',
        'loteamentoId': 'lt1',
        'quadraId': 'qd1',
        'loteId': 'lo1',
        'nome': 'Muro',
        'ordem': 1,
        'createdAt': tsCreated,
        'updatedAt': tsUpdated,
      });

      expect(lt.createdAt, createdAt);
      expect(lt.updatedAt, updatedAt);
      expect(qd.createdAt, createdAt);
      expect(qd.updatedAt, updatedAt);
      expect(lo.createdAt, createdAt);
      expect(lo.updatedAt, updatedAt);
      expect(et.createdAt, createdAt);
      expect(et.updatedAt, updatedAt);

      final fakeFirestore = FakeFirebaseFirestore();
      await fakeFirestore.collection('loteamentos').doc('lt1').set({
        'construtoraId': 'c1',
        'name': 'Loteamento TS',
        'createdAt': tsCreated,
        'updatedAt': tsUpdated,
      });
      await fakeFirestore.collection('quadras').doc('qd1').set({
        'construtoraId': 'c1',
        'loteamentoId': 'lt1',
        'name': 'Quadra TS',
        'createdAt': tsCreated,
        'updatedAt': tsUpdated,
      });
      await fakeFirestore.collection('lotes').doc('lo1').set({
        'construtoraId': 'c1',
        'loteamentoId': 'lt1',
        'quadraId': 'qd1',
        'name': 'Lote TS',
        'createdAt': tsCreated,
        'updatedAt': tsUpdated,
      });
      await fakeFirestore.collection('etapas').doc('lo1_muro').set({
        'construtoraId': 'c1',
        'loteamentoId': 'lt1',
        'quadraId': 'qd1',
        'loteId': 'lo1',
        'nome': 'Muro',
        'ordem': 1,
        'createdAt': tsCreated,
        'updatedAt': tsUpdated,
      });

      final ltRepo = LoteamentoRepository(fakeFirestore);
      final qdRepo = QuadraRepository(fakeFirestore);
      final etRepo = EtapaRepository(fakeFirestore);
      final loRepo = LoteRepository(fakeFirestore, etRepo);

      final watchedLt = await ltRepo.watchLoteamentos('c1').first;
      expect(watchedLt.single.id, 'lt1');
      expect(watchedLt.single.createdAt, createdAt);

      final watchedQd = await qdRepo.watchQuadras('c1', 'lt1').first;
      expect(watchedQd.single.id, 'qd1');
      expect(watchedQd.single.createdAt, createdAt);

      final watchedLo = await loRepo.watchLote('lo1').first;
      expect(watchedLo, isNotNull);
      expect(watchedLo!.id, 'lo1');
      expect(watchedLo.createdAt, createdAt);

      final watchedEt = await etRepo.watchEtapas('c1', 'lt1', 'qd1', 'lo1').first;
      expect(watchedEt.single.id, 'lo1_muro');
      expect(watchedEt.single.createdAt, createdAt);
    });

    test('Lote.fromJson e Etapa.fromJson sanitizam statusEtapasMap parcial, chaves inválidas, NaN/Infinity, limites e calcularAreaTerreno', () {
      final lote = Lote.fromJson({
        'id': 'lo1',
        'construtoraId': 'c1',
        'loteamentoId': 'lt1',
        'quadraId': 'qd1',
        'name': 'Lote Sanitizado',
        'progressoPercentual': double.nan,
        'etapasConcluidasCount': double.infinity,
        'etapasTotalCount': double.negativeInfinity,
        'statusEtapasMap': {
          'muro': 'concluida',
          'cinza1': 'em_andamento',
          'cinza2': 'status_invalido',
          'cinza3': '   ',
          '': 'concluida',
          '   ': 'concluida',
          'desconhecida': 'concluida',
        },
        'equipesVinculadas': [
          {1: 'valor_num_key', 'id': 'eq1', 'name': 'Equipe 1'},
        ],
        'funcionariosVinculados': [
          {2: 'outro', 'id': 'f1', 'name': 'João'},
        ],
        'createdAt': '2026-01-01T10:00:00.000',
        'updatedAt': '2026-01-02T10:00:00.000',
      });

      expect(lote.progressoPercentual, 0);
      expect(lote.etapasConcluidasCount, 0);
      expect(lote.etapasTotalCount, 5);
      expect(lote.statusEtapasMap, {
        'muro': 'concluida',
        'cinza1': 'em_andamento',
        'cinza2': 'pendente',
        'cinza3': 'pendente',
        'branca': 'pendente',
      });
      expect(lote.equipesVinculadas.single['1'], 'valor_num_key');
      expect(lote.funcionariosVinculados.single['2'], 'outro');

      final clampedLote = Lote.fromJson({
        'id': 'lo2',
        'construtoraId': 'c1',
        'loteamentoId': 'lt1',
        'quadraId': 'qd1',
        'name': 'Lote Clamp',
        'progressoPercentual': 150,
        'etapasConcluidasCount': 99,
        'etapasTotalCount': 0,
        'createdAt': '2026-01-01T10:00:00.000',
        'updatedAt': '2026-01-02T10:00:00.000',
      });
      expect(clampedLote.progressoPercentual, 100);
      expect(clampedLote.etapasConcluidasCount, 5);
      expect(clampedLote.etapasTotalCount, 5);

      expect(Lote.calcularAreaTerreno(1e200, 1e200), isNull);
      expect(Lote.calcularAreaTerreno(double.infinity, 10.0), isNull);
      expect(Lote.calcularAreaTerreno(double.nan, 10.0), isNull);

      final etapaInvalid = Etapa.fromJson({
        'id': 'lo1_muro',
        'construtoraId': 'c1',
        'loteamentoId': 'lt1',
        'quadraId': 'qd1',
        'loteId': 'lo1',
        'nome': 'Muro',
        'ordem': 1,
        'status': 'qualquer_coisa',
        'percentual': double.nan,
        'createdAt': '2026-01-01T10:00:00.000',
        'updatedAt': '2026-01-02T10:00:00.000',
      });
      expect(etapaInvalid.status, EtapaStatus.pendente);
      expect(etapaInvalid.percentual, 0);

      final etapaBlank = Etapa.fromJson({
        'id': 'lo1_muro',
        'construtoraId': 'c1',
        'loteamentoId': 'lt1',
        'quadraId': 'qd1',
        'loteId': 'lo1',
        'nome': 'Muro',
        'ordem': 1,
        'status': '   ',
        'percentual': 29.6,
        'createdAt': '2026-01-01T10:00:00.000',
        'updatedAt': '2026-01-02T10:00:00.000',
      });
      expect(etapaBlank.status, EtapaStatus.pendente);
      expect(etapaBlank.percentual, 30);

      final etapaClamp = Etapa.fromJson({
        'id': 'lo1_muro',
        'construtoraId': 'c1',
        'loteamentoId': 'lt1',
        'quadraId': 'qd1',
        'loteId': 'lo1',
        'nome': 'Muro',
        'ordem': 1,
        'status': ' em_andamento ',
        'percentual': 180,
        'createdAt': '2026-01-01T10:00:00.000',
        'updatedAt': '2026-01-02T10:00:00.000',
      });
      expect(etapaClamp.status, EtapaStatus.emAndamento);
      expect(etapaClamp.percentual, 100);
    });

    test('copyWith(clear...) limpa campos opcionais para null em Loteamento, Quadra e Lote', () {
      final now = DateTime(2026, 1, 1);
      final lt = Loteamento(
        id: 'lt1',
        construtoraId: 'c1',
        name: 'LT',
        bairro: 'Centro',
        cidade: 'Natal',
        uf: 'RN',
        proprietarioNome: 'Prop',
        proprietarioDocumento: '123',
        responsavelTecnicoNome: 'Resp',
        responsavelTecnicoRegistro: 'CREA',
        createdAt: now,
        updatedAt: now,
      );
      final ltCleared = lt.copyWith(
        clearBairro: true,
        clearCidade: true,
        clearUf: true,
        clearProprietarioNome: true,
        clearProprietarioDocumento: true,
        clearResponsavelTecnicoNome: true,
        clearResponsavelTecnicoRegistro: true,
      );
      expect(ltCleared.bairro, isNull);
      expect(ltCleared.cidade, isNull);
      expect(ltCleared.uf, isNull);
      expect(ltCleared.proprietarioNome, isNull);
      expect(ltCleared.proprietarioDocumento, isNull);
      expect(ltCleared.responsavelTecnicoNome, isNull);
      expect(ltCleared.responsavelTecnicoRegistro, isNull);

      final qd = Quadra(
        id: 'qd1',
        construtoraId: 'c1',
        loteamentoId: 'lt1',
        name: 'Q1',
        logradouroPadrao: 'Rua A',
        createdAt: now,
        updatedAt: now,
      );
      expect(qd.copyWith(clearLogradouroPadrao: true).logradouroPadrao, isNull);

      final lo = _makeLote('lo1').copyWith(
        areaConstruidaM2: 50,
        logradouro: 'Rua B',
        taxaOcupacaoPercent: 25,
        coeficienteAproveitamento: 0.25,
        areaPermeavelM2: 100,
        taxaPermeabilidadePercent: 50,
        areaImpermeavelM2: 50,
        recuoFrontalM: 5,
        recuoFundoM: 5,
        recuoLateralEsquerdoM: 1.5,
        recuoLateralDireitoM: 1.5,
        proprietarioNome: 'Prop',
        proprietarioDocumento: '123',
        responsavelTecnicoNome: 'Resp',
        responsavelTecnicoRegistro: 'CREA',
        dataProjeto: 'outubro/26',
      );
      final loCleared = lo.copyWith(
        clearFrenteM: true,
        clearProfundidadeM: true,
        clearAreaTerrenoM2: true,
        clearAreaConstruidaM2: true,
        clearLogradouro: true,
        clearTaxaOcupacaoPercent: true,
        clearCoeficienteAproveitamento: true,
        clearAreaPermeavelM2: true,
        clearTaxaPermeabilidadePercent: true,
        clearAreaImpermeavelM2: true,
        clearRecuoFrontalM: true,
        clearRecuoFundoM: true,
        clearRecuoLateralEsquerdoM: true,
        clearRecuoLateralDireitoM: true,
        clearProprietarioNome: true,
        clearProprietarioDocumento: true,
        clearResponsavelTecnicoNome: true,
        clearResponsavelTecnicoRegistro: true,
        clearDataProjeto: true,
      );
      expect(loCleared.frenteM, isNull);
      expect(loCleared.profundidadeM, isNull);
      expect(loCleared.areaTerrenoM2, isNull);
      expect(loCleared.areaConstruidaM2, isNull);
      expect(loCleared.logradouro, isNull);
      expect(loCleared.taxaOcupacaoPercent, isNull);
      expect(loCleared.coeficienteAproveitamento, isNull);
      expect(loCleared.areaPermeavelM2, isNull);
      expect(loCleared.taxaPermeabilidadePercent, isNull);
      expect(loCleared.areaImpermeavelM2, isNull);
      expect(loCleared.recuoFrontalM, isNull);
      expect(loCleared.recuoFundoM, isNull);
      expect(loCleared.recuoLateralEsquerdoM, isNull);
      expect(loCleared.recuoLateralDireitoM, isNull);
      expect(loCleared.proprietarioNome, isNull);
      expect(loCleared.proprietarioDocumento, isNull);
      expect(loCleared.responsavelTecnicoNome, isNull);
      expect(loCleared.responsavelTecnicoRegistro, isNull);
      expect(loCleared.dataProjeto, isNull);
    });

    test('updateEtapaProgresso valida percentual explícito, clamping, FKs, lote ausente, status e etapaId', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final spyFirestore = _SpyFirestore(fakeFirestore);
      final etapaRepo = EtapaRepository(spyFirestore);
      final loteRepo = LoteRepository(spyFirestore, etapaRepo);

      await loteRepo.createLoteComEtapas(_makeLote('lo1'));
      await loteRepo.createLoteComEtapas(_makeLote('lo2'));

      await etapaRepo.updateEtapaProgresso(
        loteId: 'lo1',
        etapaId: 'lo1_muro',
        status: 'em_andamento',
        percentual: 25,
      );
      expect(spyFirestore.transactionCount, 1);
      var muro = Etapa.fromJson(
        (await fakeFirestore.collection('etapas').doc('lo1_muro').get()).data()!,
      );
      expect(muro.percentual, 25);
      var lo1 = Lote.fromJson(
        (await fakeFirestore.collection('lotes').doc('lo1').get()).data()!,
      );
      expect(lo1.progressoPercentual, 5);

      await etapaRepo.updateEtapaProgresso(
        loteId: 'lo1',
        etapaId: 'lo1_muro',
        status: 'em_andamento',
        percentual: -10,
      );
      muro = Etapa.fromJson(
        (await fakeFirestore.collection('etapas').doc('lo1_muro').get()).data()!,
      );
      expect(muro.percentual, 0);

      await etapaRepo.updateEtapaProgresso(
        loteId: 'lo1',
        etapaId: 'lo1_muro',
        status: 'em_andamento',
        percentual: 150,
      );
      muro = Etapa.fromJson(
        (await fakeFirestore.collection('etapas').doc('lo1_muro').get()).data()!,
      );
      expect(muro.percentual, 100);

      await etapaRepo.updateEtapaProgresso(
        loteId: 'lo1',
        etapaId: 'lo1_cinza1',
        status: 'concluida',
      );
      await etapaRepo.updateEtapaProgresso(
        loteId: 'lo1',
        etapaId: 'lo1_cinza2',
        status: 'em_andamento',
        percentual: 50,
      );
      expect(spyFirestore.transactionCount, 5);
      lo1 = Lote.fromJson(
        (await fakeFirestore.collection('lotes').doc('lo1').get()).data()!,
      );
      expect(lo1.progressoPercentual, 50);
      expect(lo1.etapasConcluidasCount, 1);

      // Rejeições de validação
      await expectLater(
        etapaRepo.updateEtapaProgresso(
          loteId: 'lo1',
          etapaId: 'lo1_muro',
          status: 'invalido',
        ),
        throwsArgumentError,
      );
      await expectLater(
        etapaRepo.updateEtapaProgresso(
          loteId: 'lote_inexistente',
          etapaId: 'lo1_muro',
          status: 'concluida',
        ),
        throwsStateError,
      );
      await expectLater(
        etapaRepo.updateEtapaProgresso(
          loteId: 'lo1',
          etapaId: 'lo1_muro',
          status: 'concluida',
          construtoraId: 'outra_c',
        ),
        throwsArgumentError,
      );
      await expectLater(
        etapaRepo.updateEtapaProgresso(
          loteId: 'lo1',
          etapaId: 'lo1_muro',
          status: 'concluida',
          loteamentoId: 'outro_lt',
        ),
        throwsArgumentError,
      );
      await expectLater(
        etapaRepo.updateEtapaProgresso(
          loteId: 'lo1',
          etapaId: 'lo1_muro',
          status: 'concluida',
          quadraId: 'outra_qd',
        ),
        throwsArgumentError,
      );
      await expectLater(
        etapaRepo.updateEtapaProgresso(
          loteId: 'lo1',
          etapaId: 'etapa_desconhecida',
          status: 'concluida',
        ),
        throwsArgumentError,
      );
      await expectLater(
        etapaRepo.updateEtapaProgresso(
          loteId: 'lo1',
          etapaId: 'lo2_muro',
          status: 'concluida',
        ),
        throwsArgumentError,
      );
      await expectLater(
        etapaRepo.updateEtapaProgresso(
          loteId: 'lo1',
          etapaId: 'lo1_muro',
          status: 'concluida',
          tipo: EtapaTipo.cinza1,
        ),
        throwsArgumentError,
      );
    });

    test('createDefaultEtapas com batch == null preserva etapas existentes e cria apenas faltantes', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final etapaRepo = EtapaRepository(fakeFirestore);

      final now = DateTime(2026, 2, 1);
      await fakeFirestore.collection('etapas').doc('lo1_muro').set(
        Etapa(
          id: 'lo1_muro',
          construtoraId: 'c1',
          loteamentoId: 'lt1',
          quadraId: 'qd1',
          loteId: 'lo1',
          nome: 'Muro',
          ordem: 1,
          status: EtapaStatus.concluida,
          percentual: 100,
          equipeId: 'eq1',
          equipeNome: 'Equipe 1',
          createdAt: now,
          updatedAt: now,
        ).toJson(),
      );

      await etapaRepo.createDefaultEtapas(
        construtoraId: 'c1',
        loteamentoId: 'lt1',
        quadraId: 'qd1',
        loteId: 'lo1',
      );

      final snap = await fakeFirestore
          .collection('etapas')
          .where('loteId', isEqualTo: 'lo1')
          .get();
      expect(snap.docs.length, 5);
      final muro = Etapa.fromJson(
        (await fakeFirestore.collection('etapas').doc('lo1_muro').get()).data()!,
      );
      expect(muro.status, EtapaStatus.concluida);
      expect(muro.percentual, 100);
      expect(muro.equipeId, 'eq1');
    });

    test('regras transacionais de lotação: substituição na mesma etapa, proteção de dono, remoção geral, rejeição de etapa estrangeira/desconhecida e seeding completo', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final etapaRepo = EtapaRepository(fakeFirestore);
      final loteRepo = LoteRepository(fakeFirestore, etapaRepo);

      await loteRepo.createLoteComEtapas(_makeLote('lo1'));
      await loteRepo.createLoteComEtapas(_makeLote('lo2'));

      // Vínculo geral + substituição de equipe/funcionário distintos na mesma etapa
      await loteRepo.atribuirEquipe(
        loteId: 'lo1',
        equipeId: 'eq1',
        equipeNome: 'Equipe A',
      );
      await loteRepo.atribuirEquipe(
        loteId: 'lo1',
        equipeId: 'eq1',
        equipeNome: 'Equipe A',
        etapaId: 'lo1_muro',
      );
      await loteRepo.atribuirEquipe(
        loteId: 'lo1',
        equipeId: 'eq2',
        equipeNome: 'Equipe B',
        etapaId: 'lo1_muro',
      );

      await loteRepo.atribuirFuncionario(
        loteId: 'lo1',
        funcionarioId: 'f1',
        funcionarioNome: 'João',
        role: 'Pedreiro',
        etapaId: 'lo1_cinza1',
      );
      await loteRepo.atribuirFuncionario(
        loteId: 'lo1',
        funcionarioId: 'f2',
        funcionarioNome: 'Maria',
        role: 'Mestre',
        etapaId: 'lo1_cinza1',
      );

      var lo1 = Lote.fromJson(
        (await fakeFirestore.collection('lotes').doc('lo1').get()).data()!,
      );
      expect(
        lo1.equipesVinculadas.where((e) => e['etapaId'] == 'lo1_muro').length,
        1,
      );
      expect(
        lo1.equipesVinculadas
            .firstWhere((e) => e['etapaId'] == 'lo1_muro')['id'],
        'eq2',
      );
      expect(
        lo1.equipesVinculadas
            .any((e) => e['id'] == 'eq1' && e['etapaId'] == null),
        isTrue,
      );
      expect(lo1.funcionariosVinculados.length, 1);
      expect(lo1.funcionariosVinculados.single['id'], 'f2');

      var muro = Etapa.fromJson(
        (await fakeFirestore.collection('etapas').doc('lo1_muro').get()).data()!,
      );
      var cinza1 = Etapa.fromJson(
        (await fakeFirestore.collection('etapas').doc('lo1_cinza1').get())
            .data()!,
      );
      expect(muro.equipeId, 'eq2');
      expect(cinza1.funcionarioId, 'f2');

      // Protege etapa cujo dono atual é outro id
      await loteRepo.removerEquipe(
        loteId: 'lo1',
        equipeId: 'eq1',
        etapaId: 'lo1_muro',
      );
      await loteRepo.removerFuncionario(
        loteId: 'lo1',
        funcionarioId: 'f1',
        etapaId: 'lo1_cinza1',
      );
      muro = Etapa.fromJson(
        (await fakeFirestore.collection('etapas').doc('lo1_muro').get()).data()!,
      );
      cinza1 = Etapa.fromJson(
        (await fakeFirestore.collection('etapas').doc('lo1_cinza1').get())
            .data()!,
      );
      expect(muro.equipeId, 'eq2');
      expect(cinza1.funcionarioId, 'f2');

      // Remove apenas o vínculo geral (etapaId: null) preservando vínculo por etapa
      await loteRepo.atribuirEquipe(
        loteId: 'lo1',
        equipeId: 'eq2',
        equipeNome: 'Equipe B',
      );
      await loteRepo.removerEquipe(
        loteId: 'lo1',
        equipeId: 'eq2',
      );
      lo1 = Lote.fromJson(
        (await fakeFirestore.collection('lotes').doc('lo1').get()).data()!,
      );
      expect(
        lo1.equipesVinculadas
            .any((e) => e['id'] == 'eq2' && e['etapaId'] == null),
        isFalse,
      );
      expect(
        lo1.equipesVinculadas
            .any((e) => e['id'] == 'eq2' && e['etapaId'] == 'lo1_muro'),
        isTrue,
      );
      muro = Etapa.fromJson(
        (await fakeFirestore.collection('etapas').doc('lo1_muro').get()).data()!,
      );
      expect(muro.equipeId, 'eq2');

      // Rejeita etapa estrangeira, desconhecida ou strings vazias
      await expectLater(
        loteRepo.atribuirEquipe(
          loteId: 'lo1',
          equipeId: 'eq1',
          equipeNome: 'Equipe A',
          etapaId: 'lo2_muro',
        ),
        throwsArgumentError,
      );
      await expectLater(
        loteRepo.atribuirEquipe(
          loteId: 'lo1',
          equipeId: 'eq1',
          equipeNome: 'Equipe A',
          etapaId: 'desconhecida',
        ),
        throwsArgumentError,
      );
      await expectLater(
        loteRepo.atribuirFuncionario(
          loteId: 'lo1',
          funcionarioId: 'f1',
          funcionarioNome: 'João',
          role: 'Pedreiro',
          etapaId: 'lo2_cinza1',
        ),
        throwsArgumentError,
      );
      await expectLater(
        loteRepo.atribuirEquipe(
          loteId: 'lo1',
          equipeId: '   ',
          equipeNome: 'Equipe A',
        ),
        throwsArgumentError,
      );
      await expectLater(
        loteRepo.removerEquipe(
          loteId: 'lo1',
          equipeId: 'eq2',
          etapaId: 'lo2_muro',
        ),
        throwsArgumentError,
      );
      await expectLater(
        loteRepo.removerFuncionario(
          loteId: 'lo1',
          funcionarioId: 'f2',
          etapaId: 'desconhecida',
        ),
        throwsArgumentError,
      );

      // Seeding completo das 5 etapas ao vincular etapa de lote legado sem etapas
      await fakeFirestore.collection('lotes').doc('lo_leg').set(
        _makeLote('lo_leg').toJson(),
      );
      await loteRepo.atribuirEquipe(
        loteId: 'lo_leg',
        equipeId: 'eq1',
        equipeNome: 'Equipe Legado',
        etapaId: 'lo_leg_muro',
      );
      final legEtapas = await fakeFirestore
          .collection('etapas')
          .where('loteId', isEqualTo: 'lo_leg')
          .get();
      expect(legEtapas.docs.length, 5);
      final legMuro = Etapa.fromJson(
        (await fakeFirestore.collection('etapas').doc('lo_leg_muro').get())
            .data()!,
      );
      expect(legMuro.equipeId, 'eq1');
    });

    test('updateLote preserva progresso e vínculos derivados; updateQuadra atualiza quadra', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final etapaRepo = EtapaRepository(fakeFirestore);
      final loteRepo = LoteRepository(fakeFirestore, etapaRepo);
      final quadraRepo = QuadraRepository(fakeFirestore);

      final now = DateTime(2026, 1, 1);
      final quadra = Quadra(
        id: 'qd1',
        construtoraId: 'c1',
        loteamentoId: 'lt1',
        name: 'Quadra 1',
        logradouroPadrao: 'Rua A',
        createdAt: now,
        updatedAt: now,
      );
      await quadraRepo.createQuadra(quadra);
      await quadraRepo.updateQuadra(
        quadra.copyWith(name: 'Quadra 1 Rev', logradouroPadrao: 'Rua B'),
      );
      final savedQd = Quadra.fromJson(
        (await fakeFirestore.collection('quadras').doc('qd1').get()).data()!,
      );
      expect(savedQd.name, 'Quadra 1 Rev');
      expect(savedQd.logradouroPadrao, 'Rua B');

      final initialLote = _makeLote('lo1');
      await loteRepo.createLoteComEtapas(initialLote);
      await etapaRepo.updateEtapaProgresso(
        loteId: 'lo1',
        etapaId: 'lo1_muro',
        status: 'concluida',
      );
      await loteRepo.atribuirEquipe(
        loteId: 'lo1',
        equipeId: 'eq1',
        equipeNome: 'Equipe A',
        etapaId: 'lo1_muro',
      );
      await loteRepo.atribuirFuncionario(
        loteId: 'lo1',
        funcionarioId: 'f1',
        funcionarioNome: 'João',
        role: 'Pedreiro',
      );

      // Passa snapshot desatualizado (progresso 0 e listas vazias) para updateLote
      await loteRepo.updateLote(
        initialLote.copyWith(areaConstruidaM2: 72.5, logradouro: 'Rua B'),
      );

      final savedLote = Lote.fromJson(
        (await fakeFirestore.collection('lotes').doc('lo1').get()).data()!,
      );
      expect(savedLote.areaConstruidaM2, 72.5);
      expect(savedLote.logradouro, 'Rua B');
      expect(savedLote.progressoPercentual, 20);
      expect(savedLote.etapasConcluidasCount, 1);
      expect(savedLote.statusEtapasMap['muro'], 'concluida');
      expect(savedLote.equipesVinculadas.length, 1);
      expect(savedLote.funcionariosVinculados.length, 1);
    });

    test('createLoteComEtapas alinha createdAt das etapas com lote.createdAt e escrita em massa intercala lote + 5 etapas e valida FKs/duplicidades', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final etapaRepo = EtapaRepository(fakeFirestore);
      final loteRepo = LoteRepository(fakeFirestore, etapaRepo);
      final quadraRepo = QuadraRepository(fakeFirestore);
      final ltRepo = LoteamentoRepository(fakeFirestore);

      final customCreatedAt = DateTime(2025, 12, 1, 8, 0);
      final lote = _makeLote('lo_ts').copyWith(createdAt: customCreatedAt);
      await loteRepo.createLoteComEtapas(lote);
      final etapaMuro = Etapa.fromJson(
        (await fakeFirestore.collection('etapas').doc('lo_ts_muro').get())
            .data()!,
      );
      expect(etapaMuro.createdAt, customCreatedAt);
      expect(etapaMuro.updatedAt, customCreatedAt);

      // Interleaving: 2 lotes = 12 ops => [l1, 5 etapas de l1, l2, 5 etapas de l2]
      final operations = <FirestoreBatchWrite>[];
      LoteRepository.appendLotesComEtapasWrites(
        firestore: fakeFirestore,
        operations: operations,
        lotes: [_makeLote('a1'), _makeLote('a2')],
      );
      expect(operations.length, 12);
      final batch1 = fakeFirestore.batch();
      for (var i = 0; i < 6; i++) {
        operations[i](batch1);
      }
      await batch1.commit();
      expect((await fakeFirestore.collection('lotes').get()).docs.map((d) => d.id), contains('a1'));
      expect((await fakeFirestore.collection('etapas').where('loteId', isEqualTo: 'a1').get()).docs.length, 5);
      expect((await fakeFirestore.collection('etapas').where('loteId', isEqualTo: 'a2').get()).docs.length, 0);

      // Validação de FKs divergentes e IDs duplicados
      await expectLater(
        loteRepo.createLotesEmMassa([_makeLote('dup'), _makeLote('dup')]),
        throwsArgumentError,
      );
      await expectLater(
        loteRepo.createLotesEmMassa([
          _makeLote('x1', quadraId: 'qd1'),
          _makeLote('x2', quadraId: 'qd2'),
        ]),
        throwsArgumentError,
      );

      final now = DateTime(2026, 1, 1);
      await expectLater(
        quadraRepo.createQuadraComLotes(
          quadra: Quadra(
            id: 'qd1',
            construtoraId: 'c1',
            loteamentoId: 'lt1',
            name: 'Q1',
            createdAt: now,
            updatedAt: now,
          ),
          lotes: [_makeLote('bad', quadraId: 'qd_outra')],
        ),
        throwsArgumentError,
      );

      await expectLater(
        ltRepo.createLoteamentoEmMassa(
          loteamento: Loteamento(
            id: 'lt1',
            construtoraId: 'c1',
            name: 'LT1',
            createdAt: now,
            updatedAt: now,
          ),
          quadras: [
            Quadra(
              id: 'qd1',
              construtoraId: 'c1',
              loteamentoId: 'lt1',
              name: 'Q1',
              createdAt: now,
              updatedAt: now,
            ),
          ],
          lotes: [_makeLote('bad2', quadraId: 'qd_inexistente')],
        ),
        throwsArgumentError,
      );
    });
  });
}
