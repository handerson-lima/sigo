import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/src/features/fornecedores/data/fornecedores_repository.dart';
import 'package:app/src/features/fornecedores/domain/fornecedor.dart';
import 'package:app/src/features/fornecedores/presentation/widgets/fornecedor_autocomplete_field.dart';

void main() {
  group('Fornecedor Presentation & Widgets Tests', () {
    final fornecedoresMock = [
      Fornecedor(
        id: 'f1',
        construtoraId: 'c1',
        tipoPessoa: TipoPessoa.juridica,
        documento: '11222333000181',
        razaoSocial: 'Votorantim Cimentos S/A',
        nomeFantasia: 'Votorantim',
        categorias: ['materiais_basicos'],
        status: StatusFornecedor.ativo,
        dadosBancarios: const DadosBancariosFornecedor(
          chavePix: '11222333000181',
          tipoChavePix: 'cnpj',
        ),
      ),
      Fornecedor(
        id: 'f2',
        construtoraId: 'c1',
        tipoPessoa: TipoPessoa.fisica,
        documento: '52998224725',
        razaoSocial: 'João da Silva Pinturas',
        categorias: ['acabamento', 'servicos_empreiteiro'],
        status: StatusFornecedor.ativo,
      ),
    ];

    testWidgets('FornecedorAutocompleteField exibe e seleciona fornecedor corretamente',
        (tester) async {
      Fornecedor? selecionado;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fornecedoresStreamProvider.overrideWith((ref, arg) {
              return Stream.value(fornecedoresMock);
            }),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: FornecedorAutocompleteField(
                  construtoraId: 'c1',
                  onSelected: (f) {
                    selecionado = f;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifica se o campo foi renderizado
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('Fornecedor / Prestador de Serviço'), findsOneWidget);

      // Clica no campo para abrir o autocomplete
      await tester.tap(find.byType(TextFormField));
      await tester.pumpAndSettle();

      // Digita 'Vot'
      await tester.enterText(find.byType(TextFormField), 'Vot');
      await tester.pumpAndSettle();

      // Deve encontrar a opção no dropdown
      expect(find.text('Votorantim'), findsOneWidget);

      // Clica na opção
      await tester.tap(find.text('Votorantim'));
      await tester.pumpAndSettle();

      // Confirma que o callback foi acionado
      expect(selecionado, isNotNull);
      expect(selecionado!.id, 'f1');
      expect(selecionado!.razaoSocial, 'Votorantim Cimentos S/A');
    });

    testWidgets('FornecedorAutocompleteField busca por CPF de pessoa física',
        (tester) async {
      Fornecedor? selecionado;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fornecedoresStreamProvider.overrideWith((ref, arg) {
              return Stream.value(fornecedoresMock);
            }),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: FornecedorAutocompleteField(
                  construtoraId: 'c1',
                  onSelected: (f) => selecionado = f,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Digita parte do CPF
      await tester.enterText(find.byType(TextFormField), '529982');
      await tester.pumpAndSettle();

      expect(find.text('João da Silva Pinturas'), findsOneWidget);

      await tester.tap(find.text('João da Silva Pinturas'));
      await tester.pumpAndSettle();

      expect(selecionado, isNotNull);
      expect(selecionado!.id, 'f2');
      expect(selecionado!.isPessoaJuridica, isFalse);
    });
  });
}
