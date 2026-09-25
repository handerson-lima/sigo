import 'package:app/src/common_widgets/sigo_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('exibe a mensagem', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SigoEmptyState(message: 'Nenhum item')),
      ),
    );

    expect(find.text('Nenhum item'), findsOneWidget);
  });

  testWidgets('exibe a ação quando fornecida', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SigoEmptyState(
            message: 'Nenhum item',
            action: ElevatedButton(
              onPressed: () => tapped = true,
              child: const Text('Criar'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Criar'), findsOneWidget);
    await tester.tap(find.text('Criar'));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
