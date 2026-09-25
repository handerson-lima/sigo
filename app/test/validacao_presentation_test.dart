import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/features/authentication/data/user_repository.dart';
import 'package:app/src/features/validacao/data/validacao_repository.dart';
import 'package:app/src/features/validacao/domain/validacao_template.dart';
import 'package:app/src/features/validacao/domain/validacao_vistoria.dart';
import 'package:app/src/features/validacao/presentation/templates_list_screen.dart';
import 'package:app/src/features/validacao/presentation/lote_validacoes_screen.dart';

void main() {
  testWidgets('TemplatesListScreen exibe templates e detalhes de versão', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final now = DateTime(2026, 9, 18, 10, 0);
    final mockTemplates = [
      ValidacaoTemplate(
        id: 'tpl_1',
        construtoraId: 'c1',
        titulo: 'Checklist de Alvenaria',
        disciplina: 'alvenaria',
        version: 1,
        ativo: true,
        createdAt: now,
        updatedAt: now,
        itens: const [
          ChecklistTemplateItem(id: 'it_1', titulo: 'Prumo de paredes'),
        ],
      ),
      ValidacaoTemplate(
        id: 'tpl_2',
        construtoraId: 'c1',
        titulo: 'Inspeção Estrutural',
        disciplina: 'estrutura',
        version: 2,
        ativo: true,
        createdAt: now,
        updatedAt: now,
        itens: const [
          ChecklistTemplateItem(id: 'it_2', titulo: 'Armação de vigas'),
        ],
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trustedDevProvider.overrideWith((ref) => Stream.value(true)),
          templatesListStreamProvider('c1')
              .overrideWith((ref) => Stream.value(mockTemplates)),
        ],
        child: const MaterialApp(
          home: TemplatesListScreen(construtoraId: 'c1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Templates de Validação & Qualidade'), findsWidgets);
    expect(find.text('Checklist de Alvenaria'), findsOneWidget);
    expect(find.text('Inspeção Estrutural'), findsOneWidget);
    expect(find.text('v1'), findsOneWidget);
    expect(find.text('v2'), findsOneWidget);
  });

  testWidgets(
    'LoteValidacoesScreen exibe selo consolidado e lista de vistorias',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final now = DateTime(2026, 9, 18, 10, 0);
      final mockVistorias = [
        ValidacaoVistoria(
          id: 'val_1',
          construtoraId: 'c1',
          obraId: 'o1',
          loteId: 'Lote 10',
          templateId: 'tpl_1',
          templateTitulo: 'Checklist de Alvenaria',
          disciplina: 'alvenaria',
          templateVersion: 1,
          status: ValidacaoStatus.aprovado,
          inspetorUid: 'u1',
          inspetorNome: 'Engenheiro Lucas',
          dataVistoria: now,
          dataFinalizacao: now,
          itensRespondidos: const [
            ItemRespondido(
              itemId: 'it_1',
              titulo: 'Prumo de paredes',
              status: ItemConformidadeStatus.conforme,
            ),
          ],
          createdAt: now,
          updatedAt: now,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trustedDevProvider.overrideWith((ref) => Stream.value(true)),
            loteVistoriasStreamProvider((
              construtoraId: 'c1',
              obraId: 'o1',
              loteId: 'Lote 10',
            )).overrideWith((ref) => Stream.value(mockVistorias)),
          ],
          child: const MaterialApp(
            home: LoteValidacoesScreen(
              construtoraId: 'c1',
              obraId: 'o1',
              loteId: 'Lote 10',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Validação & Qualidade do Lote'), findsWidgets);
      expect(find.text('Qualidade Conforme (100% Aprovado)'), findsOneWidget);
      expect(find.text('Checklist de Alvenaria'), findsOneWidget);
      expect(find.text('Aprovado'), findsOneWidget);
    },
  );
}
