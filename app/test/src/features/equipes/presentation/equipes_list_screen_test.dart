import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obras/src/features/equipes/presentation/equipes_list_screen.dart';
import 'package:obras/src/features/equipes/data/equipe_repository.dart';
import 'package:obras/src/features/equipes/domain/equipe.dart';

void main() {
  testWidgets('Renderiza lista de equipes vazia', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchEquipesProvider.overrideWith((ref, arg) => Stream.value([])),
        ],
        child: const MaterialApp(
          home: EquipesListScreen(
            construtoraId: 'c1',
            loteamentoId: 'l1',
            quadraId: 'q1',
            loteId: 'lo1',
            setorId: 's1',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Nenhum registro encontrado.'), findsOneWidget);
  });

  testWidgets('Renderiza lista com equipes', (tester) async {
    final mockEquipe = Equipe(
      id: 'e1',
      construtoraId: 'c1',
      loteamentoId: 'l1',
      quadraId: 'q1',
      loteId: 'lo1',
      setorId: 's1',
      name: 'Equipe A',
      createdAt: DateTime(2023, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchEquipesProvider.overrideWith((ref, arg) => Stream.value([mockEquipe])),
        ],
        child: const MaterialApp(
          home: EquipesListScreen(
            construtoraId: 'c1',
            loteamentoId: 'l1',
            quadraId: 'q1',
            loteId: 'lo1',
            setorId: 's1',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Equipe A'), findsOneWidget);
  });
}
