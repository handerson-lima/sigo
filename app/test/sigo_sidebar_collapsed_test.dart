import 'package:app/src/common_widgets/sigo_layout.dart';
import 'package:app/src/common_widgets/sigo_sidebar.dart';
import 'package:app/src/features/authentication/data/auth_repository.dart';
import 'package:app/src/features/authentication/data/user_repository.dart';
import 'package:app/src/features/obras/domain/obra_member.dart';
import 'package:app/src/features/obras/presentation/current_permissions_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget createTestWidget({required Size physicalSize}) {
    return ProviderScope(
      overrides: [
        authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
        trustedDevProvider.overrideWith((ref) => Stream.value(true)),
        currentPermissionsProvider(
          (construtoraId: 'c1', obraId: 'o1'),
        ).overrideWith(
          (ref) => Stream.value(
            ObraMember(
              userId: 'u1',
              isActive: true,
              isAdmin: true,
              modules: const ['all'],
              joinedAt: DateTime(2025),
            ),
          ),
        ),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: physicalSize),
          child: const SigoLayout(
            title: 'Painel Teste',
            activeRoute: '/construtoras/c1/obra/o1',
            child: Text('Conteudo Principal'),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'Desktop: Alterna colapso da sidebar ao clicar no menu hamburguer',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget(physicalSize: const Size(1280, 800)));
      await tester.pumpAndSettle();

      // Inicialmente expandido: largura 250 e texto do logo visivel
      final sidebarFinder = find.byType(SigoSidebar);
      expect(sidebarFinder, findsOneWidget);
      expect(tester.getSize(sidebarFinder).width, 250.0);
      expect(find.text('SIGO'), findsOneWidget);

      // Botão hamburguer presente
      final hamburgerFinder = find.byKey(const Key('sigo-hamburger-button'));
      expect(hamburgerFinder, findsOneWidget);

      // Clica no hamburguer para recolher
      await tester.tap(hamburgerFinder);
      await tester.pumpAndSettle();

      // Sidebar recolhida: largura 72
      expect(tester.getSize(sidebarFinder).width, 72.0);
      // Texto "Conecta SIGO" não é mais renderizado (substituído por Tooltip no hexágono)
      expect(find.text('SIGO'), findsNothing);

      // Ícones devem ter Tooltips
      expect(find.byType(Tooltip), findsWidgets);

      // Clica novamente para expandir
      await tester.tap(hamburgerFinder);
      await tester.pumpAndSettle();

      // Sidebar expandida novamente
      expect(tester.getSize(sidebarFinder).width, 250.0);
      expect(find.text('SIGO'), findsOneWidget);
    },
  );

  testWidgets(
    'Mobile: Clicar no menu hamburguer abre o Drawer com a sidebar expandida',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget(physicalSize: const Size(400, 800)));
      await tester.pumpAndSettle();

      // Drawer fechado inicialmente
      final hamburgerFinder = find.byKey(const Key('sigo-hamburger-button'));
      expect(hamburgerFinder, findsOneWidget);
      expect(find.byType(SigoSidebar), findsNothing);

      // Clica no hamburguer para abrir gaveta
      await tester.tap(hamburgerFinder);
      await tester.pumpAndSettle();

      // Drawer aberto com SigoSidebar expandida (largura normal no drawer)
      expect(find.byType(SigoSidebar), findsOneWidget);
      expect(find.text('SIGO'), findsOneWidget);
    },
  );
}
