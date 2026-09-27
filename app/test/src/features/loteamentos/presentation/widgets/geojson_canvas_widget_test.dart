import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/features/loteamentos/presentation/widgets/geojson_canvas_widget.dart';

void main() {
  group('GeojsonCanvasWidget', () {
    testWidgets('renderiza estado vazio quando sem features (Acesso Inicial incompleto)', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: GeojsonCanvasWidget(geojsonData: {'features': []}),
        ),
      ));

      expect(find.text('Canvas vazio (sem coordenadas válidas).'), findsOneWidget);
    });

    testWidgets('pula geometria invalida e renderiza sem falhar (Geometria Inválida)', (tester) async {
      final data = {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            // faltando geometry de proposito para testar o skip
            'properties': {'status': 'ambiguo'}
          },
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Polygon',
              'coordinates': [
                [[0, 0], [0, 10], [10, 10], [10, 0], [0, 0]]
              ]
            },
            'properties': {'status': 'aprovado'}
          }
        ]
      };

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GeojsonCanvasWidget(geojsonData: data),
        ),
      ));

      // Deve renderizar o InteractiveViewer e o CustomPaint
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('renderiza poligonos com sucesso no canvas (Acesso Inicial / Renderização Visual)', (tester) async {
      final data = {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Polygon',
              'coordinates': [
                [[0, 0], [0, 10], [10, 10], [10, 0], [0, 0]]
              ]
            },
            'properties': {'status': 'ambiguo'}
          }
        ]
      };

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GeojsonCanvasWidget(geojsonData: data),
        ),
      ));

      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      // Verificamos que o CustomPainter foi instanciado
      final customPaintFinder = find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter.runtimeType.toString() == '_GeojsonPainter',
      );
      expect(customPaintFinder, findsOneWidget);
    });

    testWidgets('simula tap num poligono e chama onFeatureTap (Interação)', (tester) async {
      final data = {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Polygon',
              'coordinates': [
                [[0, 0], [0, 100], [100, 100], [100, 0], [0, 0]]
              ]
            },
            'properties': {'status': 'ambiguo'}
          }
        ]
      };

      int? tappedIndex;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GeojsonCanvasWidget(
            geojsonData: data,
            onFeatureTap: (index) {
              tappedIndex = index;
            },
          ),
        ),
      ));

      await tester.pumpAndSettle();

      final customPaint = find.byType(CustomPaint).last;
      
      // Tap no centro do polígono (50, 50). Como o InteractiveViewer centraliza, 
      // precisamos clicar exatamente no meio do widget RenderBox.
      final center = tester.getCenter(customPaint);
      await tester.tapAt(center);
      await tester.pumpAndSettle();

      expect(tappedIndex, 0);
    });

    testWidgets('renderiza canvas vazio quando nao ha coordenadas validas (Feature sem rings)', (tester) async {
      final data = {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Polygon',
              'coordinates': [] // Lista vazia
            },
            'properties': {'status': 'ambiguo'}
          }
        ]
      };

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GeojsonCanvasWidget(geojsonData: data),
        ),
      ));

      expect(find.text('Canvas vazio (sem coordenadas válidas).'), findsOneWidget);
    });
  });
}
