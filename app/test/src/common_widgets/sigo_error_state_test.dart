import 'package:app/src/common_widgets/sigo_error_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('aciona o callback de retry', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      wrap(SigoErrorState(message: 'Falhou', onRetry: () => tapped = true)),
    );

    expect(find.text('Falhou'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('mapeia permission-denied para resumo em pt-BR', (tester) async {
    await tester.pumpWidget(
      wrap(
        SigoErrorState(
          message: 'Não foi possível carregar.',
          cause: Exception('[cloud_firestore/permission-denied] negado'),
          onRetry: () {},
        ),
      ),
    );

    expect(find.text('Sem permissão de acesso'), findsOneWidget);
  });

  testWidgets('mapeia unavailable para resumo em pt-BR', (tester) async {
    await tester.pumpWidget(
      wrap(
        SigoErrorState(
          message: 'Não foi possível carregar.',
          cause: Exception('[cloud_firestore/unavailable] offline'),
          onRetry: () {},
        ),
      ),
    );

    expect(find.text('Sem conexão com o servidor'), findsOneWidget);
  });

  testWidgets('trunca causa longa sem lançar exceção', (tester) async {
    final longCause = 'z' * 400;

    await tester.pumpWidget(
      wrap(
        SigoErrorState(
          message: 'Não foi possível carregar.',
          cause: Exception(longCause),
          onRetry: () {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('zzz'), findsOneWidget);
  });
}
