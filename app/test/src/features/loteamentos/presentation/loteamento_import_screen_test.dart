import 'dart:typed_data';

import 'package:app/src/features/authentication/data/auth_repository.dart';
import 'package:app/src/features/loteamentos/data/loteamento_repository.dart';
import 'package:app/src/features/loteamentos/data/loteamentos_import_repository.dart';
import 'package:app/src/features/loteamentos/domain/loteamento.dart';
import 'package:app/src/features/loteamentos/presentation/loteamento_import_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'user-1';
}

class _FakeAuthRepository extends Fake implements AuthRepository {
  @override
  User? get currentUser => _FakeUser();
}

class _SpyImportRepository extends Fake implements LoteamentosImportRepository {
  List<ImportUploadFile>? lastFiles;
  String? lastTargetLoteamentoId;
  String? lastLoteamentoNameOverride;
  String? lastConstrutoraId;
  String draftIdToReturn = 'draft_multi_123';

  @override
  Future<String> uploadFiles({
    required String userId,
    required String construtoraId,
    required List<ImportUploadFile> files,
    String? targetLoteamentoId,
    String? loteamentoNameOverride,
  }) async {
    lastConstrutoraId = construtoraId;
    lastFiles = files;
    lastTargetLoteamentoId = targetLoteamentoId;
    lastLoteamentoNameOverride = loteamentoNameOverride;
    return draftIdToReturn;
  }
}

void main() {
  final sampleLoteamento = Loteamento(
    id: 'lot-existente-1',
    construtoraId: 'c1',
    name: 'Loteamento Jardim Botanico',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  GoRouter buildRouter(
    Widget screen, {
    required void Function(String draftId) onNavigatedToProcessing,
  }) {
    return GoRouter(
      initialLocation: '/construtoras/c1/loteamentos/import',
      routes: [
        GoRoute(
          path: '/construtoras/c1/loteamentos/import',
          builder: (_, _) => screen,
        ),
        GoRoute(
          path: '/construtoras/c1/loteamentos/import/processing/:draftId',
          builder: (_, state) {
            final draftId = state.pathParameters['draftId']!;
            onNavigatedToProcessing(draftId);
            return Scaffold(body: Text('Processando $draftId'));
          },
        ),
      ],
    );
  }

  group('LoteamentoImportScreen', () {
    testWidgets(
      'aceita múltiplos PDFs e envia juntos para Novo Loteamento',
      (tester) async {
        final spyRepo = _SpyImportRepository();
        String? navigatedDraftId;

        final router = buildRouter(
          LoteamentoImportScreen(
            construtoraId: 'c1',
            enableDropzone: false,
            pickFilesOverride: () async => [
              ImportUploadFile(
                bytes: Uint8List.fromList([1, 2, 3]),
                filename: 'lote_31_q28.pdf',
              ),
              ImportUploadFile(
                bytes: Uint8List.fromList([4, 5, 6]),
                filename: 'lote_32_q28.pdf',
              ),
            ],
          ),
          onNavigatedToProcessing: (id) => navigatedDraftId = id,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
              loteamentosImportRepositoryProvider.overrideWithValue(spyRepo),
              watchLoteamentosProvider((construtoraId: 'c1')).overrideWith(
                (ref) => Stream.value([sampleLoteamento]),
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Selecionar Arquivos'));
        await tester.pumpAndSettle();

        expect(find.text('Arquivos selecionados (2)'), findsOneWidget);
        expect(find.text('lote_31_q28.pdf'), findsOneWidget);
        expect(find.text('lote_32_q28.pdf'), findsOneWidget);

        await tester.ensureVisible(find.text('Enviar e Extrair Dados'));
        await tester.tap(find.text('Enviar e Extrair Dados'));
        await tester.pumpAndSettle();

        expect(spyRepo.lastConstrutoraId, 'c1');
        expect(spyRepo.lastFiles?.length, 2);
        expect(spyRepo.lastTargetLoteamentoId, isNull);
        expect(navigatedDraftId, 'draft_multi_123');
      },
    );

    testWidgets(
      'permite escolher Mesclar em Loteamento Existente enviando targetLoteamentoId',
      (tester) async {
        final spyRepo = _SpyImportRepository();
        String? navigatedDraftId;

        final router = buildRouter(
          LoteamentoImportScreen(
            construtoraId: 'c1',
            enableDropzone: false,
            pickFilesOverride: () async => [
              ImportUploadFile(
                bytes: Uint8List.fromList([9, 8, 7]),
                filename: 'prancha.pdf',
              ),
            ],
          ),
          onNavigatedToProcessing: (id) => navigatedDraftId = id,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
              loteamentosImportRepositoryProvider.overrideWithValue(spyRepo),
              watchLoteamentosProvider((construtoraId: 'c1')).overrideWith(
                (ref) => Stream.value([sampleLoteamento]),
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Mesclar em Existente'));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Loteamento Jardim Botanico').last);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Selecionar Arquivos'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Enviar e Extrair Dados'));
        await tester.tap(find.text('Enviar e Extrair Dados'));
        await tester.pumpAndSettle();

        expect(spyRepo.lastTargetLoteamentoId, 'lot-existente-1');
        expect(spyRepo.lastLoteamentoNameOverride, 'Loteamento Jardim Botanico');
        expect(navigatedDraftId, 'draft_multi_123');
      },
    );

    testWidgets(
      'rejeita arquivos com extensão inválida exibindo aviso',
      (tester) async {
        final spyRepo = _SpyImportRepository();

        final router = buildRouter(
          LoteamentoImportScreen(
            construtoraId: 'c1',
            enableDropzone: false,
            pickFilesOverride: () async => [
              ImportUploadFile(
                bytes: Uint8List.fromList([1]),
                filename: 'invalido.dwg',
              ),
            ],
          ),
          onNavigatedToProcessing: (_) {},
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
              loteamentosImportRepositoryProvider.overrideWithValue(spyRepo),
              watchLoteamentosProvider((construtoraId: 'c1')).overrideWith(
                (ref) => Stream.value(const <Loteamento>[]),
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Selecionar Arquivos'));
        await tester.pumpAndSettle();

        expect(find.textContaining('não suportado'), findsOneWidget);
        expect(spyRepo.lastFiles, isNull);
      },
    );
  });
}
