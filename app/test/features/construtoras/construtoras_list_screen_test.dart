import 'package:app/src/features/authentication/data/user_repository.dart';
import 'package:app/src/features/construtoras/domain/construtora.dart';
import 'package:app/src/features/construtoras/presentation/construtoras_list_screen.dart';
import 'package:app/src/features/construtoras/presentation/user_construtoras_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Construtora _c(String id, {bool isActive = true}) => Construtora(
  id: id,
  name: 'Construtora $id',
  createdAt: DateTime(2026, 1, 1),
  isActive: isActive,
);

void main() {
  group('12.2 UI — Minhas Construtoras', () {
    testWidgets('imprime a lista fornecida pelo provider (sem inativas)', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trustedDevProvider.overrideWith((ref) => Stream.value(false)),
            userConstrutorasProvider.overrideWith((ref) async => [_c('Ativa')]),
          ],
          child: const MaterialApp(home: ConstrutorasListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Construtora Ativa'), findsOneWidget);
      expect(find.text('Construtora Inativa'), findsNothing);
    });

    testWidgets('mostra estado vazio quando não há construtoras', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trustedDevProvider.overrideWith((ref) => Stream.value(false)),
            userConstrutorasProvider.overrideWith((ref) async => []),
          ],
          child: const MaterialApp(home: ConstrutorasListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Você não pertence a nenhuma construtora'),
        findsOneWidget,
      );
    });
  });
}
