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

      expect(find.text('Nenhuma feature encontrada.'), findsOneWidget);
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

    test('getStatusColor mapeia corretamente os status', () {
      expect(GeojsonCanvasWidget.getStatusColor('ambiguo'), Colors.orange.withValues(alpha: 0.6));
      expect(GeojsonCanvasWidget.getStatusColor('aprovado'), Colors.green.withValues(alpha: 0.6));
      expect(GeojsonCanvasWidget.getStatusColor('resolvido'), Colors.green.withValues(alpha: 0.6));
      expect(GeojsonCanvasWidget.getStatusColor('desconhecido'), Colors.grey.withValues(alpha: 0.4));
      expect(GeojsonCanvasWidget.getStatusColor(null), Colors.grey.withValues(alpha: 0.4));
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
