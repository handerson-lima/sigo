import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/features/loteamentos/presentation/widgets/lote_correcao_panel.dart';

void main() {
  group('LoteCorrecaoPanel', () {
    testWidgets('mostra TextField e botao Salvar para um lote', (tester) async {
      String? savedName;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoteCorrecaoPanel(
            properties: const {'tipo': 'lote', 'status': 'ambiguo', 'nome': 'Lote 1'},
            onSave: (name) => savedName = name,
            onCancel: () {},
          ),
        ),
      ));

      expect(find.text('Corrigir Lote'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Salvar'), findsOneWidget);
      expect(find.text('Confirmar Geometria'), findsNothing);

      await tester.enterText(find.byType(TextField), 'Lote 1 Editado');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(savedName, 'Lote 1 Editado');
    });

    testWidgets('mostra mensagem e botao Confirmar Geometria para quadra reparada', (tester) async {
      String? savedName;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoteCorrecaoPanel(
            properties: const {
              'tipo': 'quadra',
              'status': 'ambiguo',
              'nome': 'Quadra A',
              'geometria_reparada': true,
            },
            onSave: (name) => savedName = name,
            onCancel: () {},
          ),
        ),
      ));

      expect(find.text('Confirmar Quadra'), findsOneWidget);
      expect(find.text('A geometria desta quadra precisou ser recuperada. Por favor, verifique visualmente se as partes no canvas estão corretas e confirme.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Salvar'), findsNothing);
      expect(find.text('Confirmar Geometria'), findsOneWidget);

      await tester.tap(find.text('Confirmar Geometria'));
      await tester.pumpAndSettle();

      expect(savedName, 'Quadra A');
    });
  });
}
