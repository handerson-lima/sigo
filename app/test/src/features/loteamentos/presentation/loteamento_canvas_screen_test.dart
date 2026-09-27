import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/features/loteamentos/presentation/loteamento_canvas_screen.dart';
import 'package:app/src/features/loteamentos/presentation/widgets/geojson_canvas_widget.dart';

void main() {
  group('LoteamentoCanvasScreen', () {
    testWidgets('renderiza o loading enquanto aguarda o provider', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            canvasDraftStreamProvider.overrideWith((ref, id) {
              return const Stream.empty(); // Fica aguardando
            }),
          ],
          child: const MaterialApp(
            home: LoteamentoCanvasScreen(construtoraId: 'const-1', draftId: 'test-123'),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renderiza GeojsonCanvasWidget quando o dado e recebido', (tester) async {
      final mockData = {
        'type': 'FeatureCollection',
        'features': []
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            canvasDraftStreamProvider.overrideWith((ref, id) {
              return Stream.value(mockData);
            }),
          ],
          child: const MaterialApp(
            home: LoteamentoCanvasScreen(construtoraId: 'const-1', draftId: 'test-123'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(GeojsonCanvasWidget), findsOneWidget);
    });

    testWidgets('renderiza erro se o stream falhar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            canvasDraftStreamProvider.overrideWith((ref, id) {
              return Stream.error(Exception('Falha no banco'));
            }),
          ],
          child: const MaterialApp(
            home: LoteamentoCanvasScreen(construtoraId: 'const-1', draftId: 'test-123'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Falha no banco'), findsOneWidget);
    });
  });
}
