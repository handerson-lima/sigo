import 'package:app/src/features/construtoras/domain/construtora.dart';
import 'package:app/src/features/developer/presentation/dev_construtoras_list_screen.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Construtora _construtora({bool isActive = true}) => Construtora(
  id: 'c1',
  name: 'Construtora c1',
  createdAt: DateTime(2026, 1, 1),
  isActive: isActive,
);

Future<void> _abrirDialogo(
  WidgetTester tester,
  FakeFirebaseFirestore fake,
) async {
  await fake.collection('construtoras').doc('c1').set({
    'id': 'c1',
    'name': 'Construtora c1',
    'isActive': true,
    'createdAt': DateTime(2026, 1, 1).toIso8601String(),
  });

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => buildEditConstrutoraDialog(
                construtora: _construtora(),
                firestore: fake,
              ),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  group('12.1 — Editar construtora no Painel Dev', () {
    testWidgets('desativar persiste isActive=false e confirma', (tester) async {
      final fake = FakeFirebaseFirestore();
      await _abrirDialogo(tester, fake);

      expect(find.text('Construtora Ativa'), findsOneWidget);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Salvar'));
      await tester.pumpAndSettle();

      final snapshot = await fake.collection('construtoras').doc('c1').get();
      expect(snapshot.data()!['isActive'], false);
      expect(find.text('Construtora inativada com sucesso.'), findsOneWidget);
    });

    testWidgets('salvar sem alterar status usa mensagem neutra', (
      tester,
    ) async {
      final fake = FakeFirebaseFirestore();
      await _abrirDialogo(tester, fake);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Salvar'));
      await tester.pumpAndSettle();

      final snapshot = await fake.collection('construtoras').doc('c1').get();
      expect(snapshot.data()!['isActive'], true);
      expect(find.text('Construtora atualizada com sucesso.'), findsOneWidget);
    });
  });
}
