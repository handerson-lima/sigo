import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app/src/features/etapas/presentation/etapas_list_screen.dart';
import 'package:app/src/features/etapas/data/etapa_repository.dart';
import 'package:app/src/features/etapas/domain/etapa.dart';
import 'package:app/src/features/obras/presentation/current_permissions_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app/src/features/obras/domain/obra_member.dart';

class FakeEtapaRepository implements EtapaRepository {
  bool createCalled = false;
  
  @override
  Future<void> createDefaultEtapas({
    WriteBatch? batch,
    required String construtoraId,
    required String loteamentoId,
    required String quadraId,
    required String loteId,
  }) async {
    createCalled = true;
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeEtapaRepositoryTimeout implements EtapaRepository {
  @override
  Future<void> createDefaultEtapas({
    WriteBatch? batch,
    required String construtoraId,
    required String loteamentoId,
    required String quadraId,
    required String loteId,
  }) async {
    throw TimeoutException('Simulated timeout');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeEtapaRepositoryError implements EtapaRepository {
  @override
  Future<void> createDefaultEtapas({
    WriteBatch? batch,
    required String construtoraId,
    required String loteamentoId,
    required String quadraId,
    required String loteId,
  }) async {
    throw Exception('Simulated error');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}


void main() {
  Widget buildTestWidget(Widget child) {
    final router = GoRouter(
      initialLocation: '/etapas',
      routes: [GoRoute(path: '/etapas', builder: (context, state) => child)],
    );

    return MaterialApp.router(routerConfig: router);
  }

  testWidgets('Renderiza lista de etapas vazia', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchEtapasProvider.overrideWith((ref, arg) => Stream.value([])),
          currentPermissionsProvider((construtoraId: 'c1', obraId: 'l1'))
              .overrideWith((ref) => Stream.value(null)),
        ],
        child: buildTestWidget(
          const EtapasListScreen(
            construtoraId: 'c1',
            loteamentoId: 'l1',
            quadraId: 'q1',
            loteId: 'lo1',
          ),
        ),
      ),
    );

    await tester.pump(); // Resolve GoRouter
    await tester.pump(); // First frame of EtapasListScreen
    await tester.pump(
      const Duration(milliseconds: 100),
    ); // Wait for Stream.value
    await tester.pump(); // Render data

    expect(find.text('Nenhuma etapa cadastrada'), findsOneWidget);
  });

  testWidgets('Renderiza lista com etapas', (tester) async {
    final mockEtapa = Etapa(
      id: 'e1',
      construtoraId: 'c1',
      loteamentoId: 'l1',
      quadraId: 'q1',
      loteId: 'lo1',
      nome: 'Muro',
      ordem: 1,
      createdAt: DateTime(2023, 1, 1),
      updatedAt: DateTime(2023, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchEtapasProvider.overrideWith(
            (ref, arg) => Stream.value([mockEtapa]),
          ),
          currentPermissionsProvider((construtoraId: 'c1', obraId: 'l1'))
              .overrideWith((ref) => Stream.value(null)),
        ],
        child: buildTestWidget(
          const EtapasListScreen(
            construtoraId: 'c1',
            loteamentoId: 'l1',
            quadraId: 'q1',
            loteId: 'lo1',
          ),
        ),
      ),
    );

    await tester.pump(); // Resolve GoRouter
    await tester.pump(); // First frame of EtapasListScreen
    await tester.pump(
      const Duration(milliseconds: 100),
    ); // Wait for Stream.value
    await tester.pump(); // Render data

    expect(find.text('Muro'), findsOneWidget);
  });

  testWidgets('Renderiza erro e recarrega ao tentar novamente', (tester) async {
    var stream = Stream<List<Etapa>>.error(Exception('falha'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchEtapasProvider.overrideWith((ref, arg) => stream),
          currentPermissionsProvider((construtoraId: 'c1', obraId: 'l1'))
              .overrideWith((ref) => Stream.value(null)),
        ],
        child: buildTestWidget(
          const EtapasListScreen(
            construtoraId: 'c1',
            loteamentoId: 'l1',
            quadraId: 'q1',
            loteId: 'lo1',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Não foi possível carregar as etapas.'), findsOneWidget);

    stream = Stream.value([]);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma etapa cadastrada'), findsOneWidget);
  });

  testWidgets('Renderiza botao Inicializar Etapas para admin e executa', (
    tester,
  ) async {
    final fakeRepo = FakeEtapaRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchEtapasProvider.overrideWith((ref, arg) => Stream.value([])),
          currentPermissionsProvider((construtoraId: 'c1', obraId: 'l1'))
              .overrideWith((ref) => Stream.value(
                ObraMember(
                  userId: 'user',
                  isAdmin: true,
                  isActive: true,
                  modules: [],
                  joinedAt: DateTime.now(),
                ),
              )),
          etapaRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: buildTestWidget(
          const EtapasListScreen(
            construtoraId: 'c1',
            loteamentoId: 'l1',
            quadraId: 'q1',
            loteId: 'lo1',
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(find.text('Nenhuma etapa cadastrada'), findsOneWidget);
    expect(find.text('Inicializar Etapas'), findsOneWidget);

    await tester.tap(find.text('Inicializar Etapas'));
    await tester.pump();

    expect(find.text('Inicializando...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    await tester.pumpAndSettle();
    
    expect(fakeRepo.createCalled, isTrue);
  });

  testWidgets('Renderiza SnackBar com timeout ao demorar na inicializacao', (
    tester,
  ) async {
    final fakeRepo = FakeEtapaRepositoryTimeout();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchEtapasProvider.overrideWith((ref, arg) => Stream.value([])),
          currentPermissionsProvider((construtoraId: 'c1', obraId: 'l1'))
              .overrideWith((ref) => Stream.value(
                ObraMember(
                  userId: 'user',
                  isAdmin: true,
                  isActive: true,
                  modules: [],
                  joinedAt: DateTime.now(),
                ),
              )),
          etapaRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: buildTestWidget(
          const EtapasListScreen(
            construtoraId: 'c1',
            loteamentoId: 'l1',
            quadraId: 'q1',
            loteId: 'lo1',
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    await tester.tap(find.text('Inicializar Etapas'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('A inicialização está demorando muito. Os dados estão sendo processados.'), findsOneWidget);
  });

  testWidgets('Renderiza SnackBar de erro genérico ao falhar inicializacao', (
    tester,
  ) async {
    final fakeRepo = FakeEtapaRepositoryError();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchEtapasProvider.overrideWith((ref, arg) => Stream.value([])),
          currentPermissionsProvider((construtoraId: 'c1', obraId: 'l1'))
              .overrideWith((ref) => Stream.value(
                ObraMember(
                  userId: 'user',
                  isAdmin: true,
                  isActive: true,
                  modules: [],
                  joinedAt: DateTime.now(),
                ),
              )),
          etapaRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: buildTestWidget(
          const EtapasListScreen(
            construtoraId: 'c1',
            loteamentoId: 'l1',
            quadraId: 'q1',
            loteId: 'lo1',
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    await tester.tap(find.text('Inicializar Etapas'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Erro ao inicializar etapas. Tente novamente.'), findsOneWidget);
  });
}
