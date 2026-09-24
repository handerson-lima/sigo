import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/src/features/lotes/domain/lote.dart';
import 'package:app/src/features/lotes/presentation/add_lote_screen.dart';
import 'package:app/src/features/lotes/presentation/lotes_list_screen.dart';
import 'package:app/src/features/lotes/data/lote_repository.dart';
import 'package:app/src/features/obras/domain/obra.dart';
import 'package:app/src/features/obras/presentation/obras_list_screen.dart';
import 'package:app/src/features/obras/presentation/construtora_obras_provider.dart';
import 'package:app/src/features/obras/presentation/current_permissions_provider.dart';
import 'package:app/src/features/obras/data/obra_repository.dart';
import 'package:app/src/features/authentication/data/user_repository.dart';

class FakeLoteRepository implements LoteRepository {
  final List<Lote> lotes = [];

  @override
  Stream<List<Lote>> watchLotes(String construtoraId, String loteamentoId, String quadraId) {
    return Stream.value(lotes);
  }

  @override
  Future<void> createLote(Lote lote) async {
    lotes.add(lote);
  }
}

class FakeObraRepository implements ObraRepository {
  final List<Obra> obras = [];

  @override
  Future<void> createObra(Obra obra) async {
    obras.add(obra);
  }

  @override
  Future<void> updateObra(Obra obra) async {
    final idx = obras.indexWhere((o) => o.id == obra.id);
    if (idx != -1) obras[idx] = obra;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Story 3.1 — CRUD de Projetos e Lotes (Testes de Domínio e Validações)', () {
    test('Lote domain model serialization e deserialization', () {
      final now = DateTime(2026, 9, 17, 10, 0, 0);
      final lote = Lote(
        id: 'l1',
        construtoraId: 'c1',
        loteamentoId: 'lt1',
        quadraId: 'qd1',
        name: 'Casa 101',
        phase: 'Fundação',
        status: LoteStatus.atrasado,
        createdAt: now,
      );

      final json = lote.toJson();
      expect(json['id'], 'l1');
      expect(json['name'], 'Casa 101');
      expect(json['status'], 'atrasado');

      final deserialized = Lote.fromJson(json);
      expect(deserialized.id, 'l1');
      expect(deserialized.phase, 'Fundação');
      expect(deserialized.status, LoteStatus.atrasado);
    });

    test('Obra domain model serialization e deserialization', () {
      final now = DateTime(2026, 9, 17, 10, 0, 0);
      final obra = Obra(
        id: 'o1',
        construtoraId: 'c1',
        name: 'Residencial Alfa',
        description: 'Obra de 50 lotes',
        createdAt: now,
        isActive: true,
      );

      final json = obra.toJson();
      expect(json['name'], 'Residencial Alfa');
      expect(json['description'], 'Obra de 50 lotes');

      final deserialized = Obra.fromJson(json);
      expect(deserialized.id, 'o1');
      expect(deserialized.name, 'Residencial Alfa');
      expect(deserialized.isActive, true);
    });

    testWidgets('AddLoteScreen valida whitespace e bloqueia submissao de nome vazio', (tester) async {
      final fakeRepo = FakeLoteRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loteRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: AddLoteScreen(construtoraId: 'c1', loteamentoId: 'lt1', quadraId: 'qd1'),
          ),
        ),
      );

      // Tenta submeter vazio
      await tester.tap(find.text('Criar Lote'));
      await tester.pump();
      expect(find.text('Campo obrigatório'), findsOneWidget);

      // Tenta submeter com apenas espaços
      await tester.enterText(find.byType(TextFormField).first, '     ');
      await tester.tap(find.text('Criar Lote'));
      await tester.pump();
      expect(find.text('Campo obrigatório'), findsOneWidget);
      expect(fakeRepo.lotes, isEmpty);

      // Preenche nome válido
      await tester.enterText(find.byType(TextFormField).first, 'Casa 05');
      await tester.tap(find.text('Criar Lote'));
      await tester.pump();

      expect(fakeRepo.lotes.length, 1);
      expect(fakeRepo.lotes.first.name, 'Casa 05');
      expect(fakeRepo.lotes.first.phase, 'Plantas');
      expect(fakeRepo.lotes.first.status, LoteStatus.noPrazo);
    });

    testWidgets('LotesListScreen exibe a lista de lotes com status e fase', (tester) async {
      final fakeRepo = FakeLoteRepository();
      fakeRepo.lotes.add(
        Lote(
          id: 'lote-1',
          construtoraId: 'c1',
          loteamentoId: 'lt1',
          quadraId: 'qd1',
          name: 'Lote 01',
          phase: 'Fundação',
          status: LoteStatus.noPrazo,
          createdAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loteRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: LotesListScreen(construtoraId: 'c1', loteamentoId: 'lt1', quadraId: 'qd1'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Lote 01'), findsOneWidget);
      expect(find.textContaining('Phase: Fundação'), findsOneWidget);
    });

    testWidgets('ObrasListScreen exibe botao de Nova Obra para Administrador', (tester) async {
      final fakeRepo = FakeObraRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            obraRepositoryProvider.overrideWithValue(fakeRepo),
            trustedDevProvider.overrideWith((ref) => Stream.value(true)),
            construtoraPermissionProvider('c1').overrideWith(
              (ref) => Stream.value({'isActive': true, 'isAdmin': true}),
            ),
            construtoraObrasProvider('c1').overrideWith(
              (ref) => Future.value([]),
            ),
          ],
          child: const MaterialApp(
            home: ObrasListScreen(construtoraId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Encontra o botão de criar obra na AppBar e no centro do estado vazio
      expect(find.byTooltip('Nova Obra'), findsOneWidget);
      expect(find.text('Criar Nova Obra'), findsOneWidget);

      // Clica em Nova Obra e abre diálogo
      await tester.tap(find.byTooltip('Nova Obra'));
      await tester.pumpAndSettle();

      expect(find.text('Nova Obra'), findsOneWidget);
      expect(find.text('Nome da Obra *'), findsOneWidget);

      // Preenche e submete
      await tester.enterText(find.byType(TextFormField).first, 'Residencial Bela Vista');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(fakeRepo.obras.length, 1);
      expect(fakeRepo.obras.first.name, 'Residencial Bela Vista');
      expect(fakeRepo.obras.first.construtoraId, 'c1');
    });

    testWidgets('ObrasListScreen oculta botao de Nova Obra para membro comum nao-admin', (tester) async {
      final fakeRepo = FakeObraRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            obraRepositoryProvider.overrideWithValue(fakeRepo),
            trustedDevProvider.overrideWith((ref) => Stream.value(false)),
            construtoraPermissionProvider('c1').overrideWith(
              (ref) => Stream.value({'isActive': true, 'isAdmin': false, 'isOwner': false}),
            ),
            construtoraObrasProvider('c1').overrideWith(
              (ref) => Future.value([]),
            ),
          ],
          child: const MaterialApp(
            home: ObrasListScreen(construtoraId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Membro comum não vê ações administrativas de criação de obra
      expect(find.byTooltip('Nova Obra'), findsNothing);
      expect(find.text('Criar Nova Obra'), findsNothing);
    });
  });
}
