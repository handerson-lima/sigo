import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obras/src/features/setores/presentation/setores_list_screen.dart';
import 'package:obras/src/features/setores/data/setor_repository.dart';
import 'package:obras/src/features/setores/domain/setor.dart';

void main() {
  testWidgets('Renderiza lista de setores vazia', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchSetoresProvider.overrideWith((ref, arg) => Stream.value([])),
        ],
        child: const MaterialApp(
          home: SetoresListScreen(
            construtoraId: 'c1',
            loteamentoId: 'l1',
            quadraId: 'q1',
            loteId: 'lo1',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Nenhum registro encontrado.'), findsOneWidget);
  });

  testWidgets('Renderiza lista com setores', (tester) async {
    final mockSetor = Setor(
      id: 's1',
      construtoraId: 'c1',
      loteamentoId: 'l1',
      quadraId: 'q1',
      loteId: 'lo1',
      name: 'Setor A',
      createdAt: DateTime(2023, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchSetoresProvider.overrideWith((ref, arg) => Stream.value([mockSetor])),
        ],
        child: const MaterialApp(
          home: SetoresListScreen(
            construtoraId: 'c1',
            loteamentoId: 'l1',
            quadraId: 'q1',
            loteId: 'lo1',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Setor A'), findsOneWidget);
  });
}
