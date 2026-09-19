import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/features/authentication/data/user_repository.dart';
import 'package:app/src/features/construtoras/domain/membro.dart';
import 'package:app/src/features/construtoras/presentation/add_membro_dialog.dart';
import 'package:app/src/features/construtoras/presentation/membros_screen.dart';

void main() {
  group('Story 5.7 — Atribuição e Gestão de Proprietário (Owner)', () {
    test('Modelo Membro interpreta isOwner e compatibilidade de role owner', () {
      final ownerComFlag = Membro.fromFirestore({
        'email': 'dono@construtora.com',
        'isOwner': true,
        'isAdmin': true,
        'role': 'owner',
      }, 'uid-1');
      expect(ownerComFlag.isOwner, isTrue);
      expect(ownerComFlag.isAdmin, isTrue);
      expect(ownerComFlag.role, 'owner');
      expect(ownerComFlag.email, 'dono@construtora.com');

      final ownerSemFlagBooleana = Membro.fromFirestore({
        'email': 'socio@construtora.com',
        'role': 'owner',
      }, 'uid-2');
      expect(ownerSemFlagBooleana.isOwner, isTrue);
      expect(ownerSemFlagBooleana.isAdmin, isTrue);
      expect(ownerSemFlagBooleana.role, 'owner');

      final adminComum = Membro.fromFirestore({
        'email': 'admin@construtora.com',
        'isAdmin': true,
        'isOwner': false,
        'role': 'admin',
      }, 'uid-3');
      expect(adminComum.isOwner, isFalse);
      expect(adminComum.isAdmin, isTrue);
      expect(adminComum.role, 'admin');

      final operario = Membro.fromFirestore({
        'email': 'operario@construtora.com',
        'isAdmin': false,
        'isOwner': false,
        'role': 'operario',
      }, 'uid-4');
      expect(operario.isOwner, isFalse);
      expect(operario.isAdmin, isFalse);
      expect(operario.role, 'operario');
    });

    testWidgets('MembrosScreen renderiza destaque visual e badges para Proprietário, Admin e Operário',
        (tester) async {
      final mockMembros = [
        Membro(
          uid: 'owner-1',
          email: 'dono@empresa.com',
          isOwner: true,
          isAdmin: true,
          role: 'owner',
        ),
        Membro(
          uid: 'admin-1',
          email: 'admin@empresa.com',
          isOwner: false,
          isAdmin: true,
          role: 'admin',
        ),
        Membro(
          uid: 'operario-1',
          email: 'operario@empresa.com',
          isOwner: false,
          isAdmin: false,
          role: 'operario',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            membrosProvider('c-1').overrideWith(
              (ref) => Stream.value(mockMembros),
            ),
          ],
          child: const MaterialApp(
            home: MembrosScreen(construtoraId: 'c-1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifica e-mails na lista
      expect(find.text('dono@empresa.com'), findsOneWidget);
      expect(find.text('admin@empresa.com'), findsOneWidget);
      expect(find.text('operario@empresa.com'), findsOneWidget);

      // Verifica labels de cargo renderizados
      expect(find.text('Proprietário'), findsNWidgets(2)); // subtítulo e trailing badge
      expect(find.text('Administrador'), findsOneWidget);
      expect(find.text('Operário'), findsOneWidget);

      // Verifica ícone distintivo do proprietário
      expect(find.byIcon(Icons.stars_rounded), findsOneWidget);
      expect(find.byIcon(Icons.admin_panel_settings), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('AddMembroDialog exibe opção de Proprietário para Dev', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trustedDevProvider.overrideWith((ref) => Stream.value(true)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AddMembroDialog(construtoraId: 'c-1'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Abre o DropdownButton
      final dropdownFinder = find.byType(DropdownButtonFormField<String>);
      expect(dropdownFinder, findsOneWidget);
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();

      // Opção Proprietário deve estar visível para o Dev
      expect(find.text('Proprietário').last, findsOneWidget);
      expect(find.text('Administrador').last, findsOneWidget);
      expect(find.text('Operário').last, findsOneWidget);
    });
  });
}
