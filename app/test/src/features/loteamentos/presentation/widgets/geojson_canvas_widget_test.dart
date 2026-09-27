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
        (widget) => widget is CustomPaint && widget.painter is GeojsonPainter,
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

    test('GeojsonPainter aplica cores corretas baseadas no status', () {
      final features = [
        {
          'geometry': {'type': 'Polygon', 'coordinates': [[[0,0], [1,1]]]},
          'properties': {'status': 'resolvido'}
        },
        {
          'geometry': {'type': 'Polygon', 'coordinates': [[[0,0], [1,1]]]},
          'properties': {'status': 'ambiguo'}
        },
        {
          'geometry': {'type': 'Polygon', 'coordinates': [[[0,0], [1,1]]]},
          'properties': {'status': 'outro'}
        }
      ];

      final paths = [Path(), Path(), Path()];
      final painter = GeojsonPainter(features: features, paths: paths, drawOrder: [0, 1, 2]);

      final recorder = FlutterTestCanvasRecorder();
      painter.paint(recorder, const Size(100, 100));

      expect(recorder.paints.length, 6); // 3 preenchimentos + 3 bordas

      // Feature 0: resolvido -> verde
      expect(recorder.paints[0].color.toARGB32(), Colors.green.withAlpha(128).toARGB32());
      expect(recorder.paints[0].style, PaintingStyle.fill);

      // Feature 1: ambiguo -> laranja
      expect(recorder.paints[2].color.toARGB32(), Colors.orange.withAlpha(128).toARGB32());
      expect(recorder.paints[2].style, PaintingStyle.fill);

      // Feature 2: desconhecido -> cinza
      expect(recorder.paints[4].color.toARGB32(), Colors.grey.withAlpha(128).toARGB32());
      expect(recorder.paints[4].style, PaintingStyle.fill);
    });
  });
}

class FlutterTestCanvasRecorder implements Canvas {
  final List<Paint> paints = [];
  @override
  void drawPath(Path path, Paint paint) {
    paints.add(paint);
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
