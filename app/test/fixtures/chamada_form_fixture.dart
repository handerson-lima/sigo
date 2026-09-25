import 'dart:async';

import 'package:app/src/features/authentication/data/auth_repository.dart';
import 'package:app/src/features/authentication/data/user_repository.dart';
import 'package:app/src/features/loteamentos/data/loteamento_repository.dart';
import 'package:app/src/features/loteamentos/domain/loteamento.dart';
import 'package:app/src/features/quadras/data/quadra_repository.dart';
import 'package:app/src/features/quadras/domain/quadra.dart';
import 'package:app/src/features/lotes/data/lote_repository.dart';
import 'package:app/src/features/lotes/domain/lote.dart';
import 'package:app/src/features/obras/presentation/construtora_obras_provider.dart';
import 'package:app/src/features/rh/data/chamada_repository.dart';
import 'package:app/src/features/rh/data/lote_persistido_service.dart';
import 'package:app/src/features/rh/data/rh_repository.dart';
import 'package:app/src/features/rh/domain/chamada_diaria.dart';
import 'package:app/src/features/rh/domain/equipe.dart';
import 'package:app/src/features/rh/domain/funcionario.dart';
import 'package:app/src/features/rh/presentation/chamada_form_screen.dart';
import 'package:app/src/features/rh/presentation/widgets/chamada_form_view.dart';
import 'package:app/src/sync/sync_engine.dart';
import 'package:app/src/sync/sync_indicator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

typedef CrossApontamento = ({
  String obraId,
  String date,
  ApontamentoTrabalhador apontamento,
});

class ControlledChamadaRepository implements ChamadaRepository {
  ChamadaDiaria? existing;
  Completer<ChamadaDiaria?>? loading;
  final queries = <String>[];
  final pending = <Completer<List<CrossApontamento>>>[];
  final saved = <ChamadaDiaria>[];
  bool failNextSave = false;

  @override
  Future<ChamadaDiaria?> getChamada(String c, String o, String id) async =>
      loading == null ? existing : await loading!.future;

  @override
  Future<ChamadaDiaria?> findChamadaByDate(
    String c,
    String o,
    String date,
  ) async => null;

  @override
  Future<List<CrossApontamento>> findCrossObraApontamentos({
    required String construtoraId,
    required String currentObraId,
    required String date,
  }) {
    queries.add(date);
    final completer = Completer<List<CrossApontamento>>();
    pending.add(completer);
    return completer.future;
  }

  @override
  Future<void> saveChamada(ChamadaDiaria chamada) async {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('falha simulada');
    }
    saved.add(chamada);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestUser implements User {
  @override
  final String uid;
  @override
  final String? displayName;
  @override
  final String? email;
  TestUser(this.uid, this.displayName, [this.email]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestAuthRepository implements AuthRepository {
  @override
  User? currentUser = TestUser('autor', 'Autora Original');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestLoteRepository implements LoteRepository {
  final calls = <(String, String, String)>[];
  final lotes = [
    for (final id in ['l1', 'l2'])
      Lote(
        id: id,
        construtoraId: 'c1',
        loteamentoId: 'lt1',
        quadraId: 'qd1',
        name: id,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
  ];
  late final stream = Stream.value(lotes).asBroadcastStream();
  @override
  Stream<List<Lote>> watchLotes(
    String construtoraId,
    String loteamentoId,
    String quadraId,
  ) {
    calls.add((construtoraId, loteamentoId, quadraId));
    return stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestLoteamentoRepository implements LoteamentoRepository {
  final loteamentos = [
    Loteamento(
      id: 'lt1',
      construtoraId: 'c1',
      name: 'Loteamento Teste',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  ];
  @override
  Stream<List<Loteamento>> watchLoteamentos(String construtoraId) =>
      Stream.value(loteamentos);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestQuadraRepository implements QuadraRepository {
  final quadras = [
    Quadra(
      id: 'qd1',
      construtoraId: 'c1',
      loteamentoId: 'lt1',
      name: 'Quadra Teste',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  ];
  @override
  Stream<List<Quadra>> watchQuadras(
    String construtoraId,
    String loteamentoId,
  ) => Stream.value(quadras);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestDefaultLot extends LotePersistidoService {
  Completer<String?>? loading;
  @override
  Future<String?> getDefaultLot({
    required String obraId,
    required String teamId,
  }) async => loading == null ? null : await loading!.future;
  @override
  Future<void> saveDefaultLot({
    required String obraId,
    required String teamId,
    required String lotId,
  }) async {}
}

class TestRhRepository implements RhRepository {
  final funcionarios = [
    for (final n in [1, 2])
      Funcionario(
        id: 'f$n',
        construtoraId: 'c1',
        name: 'Operário $n',
        cpf: '',
        role: 'Pedreiro',
        teamId: 'e$n',
        employmentType: 'avulso',
        salaryBasis: 'diaria',
        baseSalaryCents: n * 10000,
      ),
  ];
  final equipes = [
    for (final n in [1, 2])
      Equipe(id: 'e$n', construtoraId: 'c1', name: 'Equipe $n'),
  ];
  final updates = StreamController<List<Funcionario>>.broadcast();
  @override
  Stream<List<Funcionario>> watchFuncionarios(String c) async* {
    yield funcionarios;
    yield* updates.stream;
  }

  @override
  Stream<List<Equipe>> watchEquipes(String c) => Stream.value(equipes);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ChamadaFormFixture {
  final repo = ControlledChamadaRepository();
  final auth = TestAuthRepository();
  final rh = TestRhRepository();
  final lotes = TestLoteRepository();
  final loteamentos = TestLoteamentoRepository();
  final quadras = TestQuadraRepository();
  final defaultLot = TestDefaultLot();
  late GoRouter router;

  ChamadaFormView view(WidgetTester tester) =>
      tester.widget<ChamadaFormView>(find.byType(ChamadaFormView));

  Future<void> selecionarHierarquia(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('loteamento-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Loteamento Teste').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quadra-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quadra Teste').last);
    await tester.pumpAndSettle();
  }

  Future<void> mount(WidgetTester tester, {String? chamadaId}) async {
    tester.view.physicalSize = const Size(1500, 1100);
    tester.view.devicePixelRatio = 1;
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Lista de chamadas')),
        ),
        GoRoute(
          path: '/form',
          builder: (_, _) => ChamadaFormScreen(
            construtoraId: 'c1',
            obraId: 'o1',
            chamadaId: chamadaId,
          ),
        ),
      ],
    );
    addTearDown(() {
      router.dispose();
      rh.updates.close();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chamadaRepositoryProvider.overrideWithValue(repo),
          authRepositoryProvider.overrideWithValue(auth),
          rhRepositoryProvider.overrideWithValue(rh),
          loteRepositoryProvider.overrideWithValue(lotes),
          loteamentoRepositoryProvider.overrideWithValue(loteamentos),
          quadraRepositoryProvider.overrideWithValue(quadras),
          lotePersistidoServiceProvider.overrideWithValue(defaultLot),
          authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
          trustedDevProvider.overrideWith((ref) => Stream.value(true)),
          construtoraObrasProvider('c1').overrideWith((ref) async => []),
          syncSummaryProvider.overrideWithValue(
            const SyncSummary(
              isOnline: true,
              engineStatus: SyncEngineStatus.idle,
              pendingCount: 0,
              failedCount: 0,
              alertCount: 0,
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.push('/form');
    await tester.pumpAndSettle();
    await selecionarHierarquia(tester);
    if (chamadaId == null) {
      view(tester).onDefaultLotChanged('l1');
      view(tester).onTeamChanged('e1');
      await tester.pumpAndSettle();
      view(tester).onMarkAllPresent();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
    }
  }

  Future<void> disposeScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }
}
