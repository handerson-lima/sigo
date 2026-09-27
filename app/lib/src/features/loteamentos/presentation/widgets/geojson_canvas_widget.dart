import 'package:flutter/material.dart';

class GeojsonCanvasWidget extends StatelessWidget {
  final Map<String, dynamic> geojsonData;
  final int? selectedFeatureIndex;
  final ValueChanged<int>? onFeatureTap;

  const GeojsonCanvasWidget({
    super.key,
    required this.geojsonData,
    this.selectedFeatureIndex,
    this.onFeatureTap,
  });

  @override
  Widget build(BuildContext context) {
    // Extrai features
    final features = geojsonData['features'] as List<dynamic>? ?? [];

    if (features.isEmpty) {
      return const Center(child: Text('Nenhuma feature encontrada.'));
    }

    // Calcula os bounds (minX, minY, maxX, maxY) para centralizar e focar
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final feature in features) {
      final geometry = feature['geometry'] as Map<String, dynamic>?;
      if (geometry == null) {
        debugPrint('Geometria inválida/ausente ignorada.');
        continue;
      }
      final type = geometry['type'];
      final coords = geometry['coordinates'] as List<dynamic>?;
      if (coords == null || coords.isEmpty) {
        debugPrint('Coordenadas vazias ignoradas no tipo $type.');
        continue;
      }

      void processRing(List<dynamic> ring) {
        for (final point in ring) {
          final x = (point[0] as num).toDouble();
          final y = (point[1] as num).toDouble();
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }

      if (type == 'Polygon') {
        processRing(coords[0] as List<dynamic>);
      } else if (type == 'MultiPolygon') {
        for (final poly in coords) {
          final polyCoords = poly as List<dynamic>;
          if (polyCoords.isNotEmpty) {
            processRing(polyCoords[0] as List<dynamic>);
          }
        }
      }
    }

    // Helper para criar paths (usado no paint e no hit-test)
    Path createPathForFeature(Map<String, dynamic>? geometry, Offset offset) {
      final path = Path();
      if (geometry == null) return path;
      final type = geometry['type'];
      final coords = geometry['coordinates'] as List<dynamic>?;
      if (coords == null || coords.isEmpty) return path;

      void addRing(List<dynamic> ring) {
        bool first = true;
        for (final point in ring) {
          final x = (point[0] as num).toDouble() + offset.dx;
          final y = (point[1] as num).toDouble() + offset.dy;
          if (first) {
            path.moveTo(x, y);
            first = false;
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
      }

      if (type == 'Polygon') {
        addRing(coords[0] as List<dynamic>);
      } else if (type == 'MultiPolygon') {
        for (final poly in coords) {
          final polyCoords = poly as List<dynamic>;
          if (polyCoords.isNotEmpty) {
            addRing(polyCoords[0] as List<dynamic>);
          }
        }
      }
      return path;
    }

    if (minX == double.infinity) {
      return const Center(child: Text('Canvas vazio (sem coordenadas válidas).'));
    }

    final width = maxX - minX;
    final height = maxY - minY;
    final offset = Offset(-minX - width / 2, -minY - height / 2);
    
    return InteractiveViewer(
      boundaryMargin: const EdgeInsets.all(double.infinity),
      minScale: 0.1,
      maxScale: 10.0,
      constrained: false, // permite mover livremente em tela infinita
      child: GestureDetector(
        onTapUp: (details) {
          if (onFeatureTap == null) return;
          final localPosition = details.localPosition;
          for (int i = features.length - 1; i >= 0; i--) {
            final feature = features[i];
            final path = createPathForFeature(feature['geometry'], offset);
            if (path.contains(localPosition)) {
              onFeatureTap!(i);
              return;
            }
          }
          // Tap fora
          onFeatureTap!(-1);
        },
        child: Transform.translate(
          // Centraliza os desenhos movendo a origem baseada no centro do bbox
          offset: offset,
          child: CustomPaint(
            size: Size(width, height), // Tamanho original em coordenadas do mapa
            painter: _GeojsonPainter(features: features, selectedFeatureIndex: selectedFeatureIndex),
          ),
        ),
      ),
    );
  }
  static Color getStatusColor(String? status) {
    if (status == 'ambiguo') {
      return Colors.orange.withValues(alpha: 0.6);
    } else if (status == 'aprovado' || status == 'resolvido') {
      return Colors.green.withValues(alpha: 0.6);
    } else {
      return Colors.grey.withValues(alpha: 0.4);
    }
  }
}

class _GeojsonPainter extends CustomPainter {
  final List<dynamic> features;
  final int? selectedFeatureIndex;

  _GeojsonPainter({required this.features, this.selectedFeatureIndex});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < features.length; i++) {
      final feature = features[i];
      final isSelected = i == selectedFeatureIndex;
      final properties = feature['properties'] as Map<String, dynamic>? ?? {};
      final status = properties['status'] as String?;
      final geometry = feature['geometry'] as Map<String, dynamic>?;

      if (geometry == null) continue;
      final type = geometry['type'];
      final coords = geometry['coordinates'] as List<dynamic>?;
      if (coords == null || coords.isEmpty) continue;

      void drawRing(List<dynamic> ring) {
        final path = Path();
        bool first = true;
        for (final point in ring) {
          final x = (point[0] as num).toDouble();
          final y = (point[1] as num).toDouble();
          if (first) {
            path.moveTo(x, y);
            first = false;
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();

        final paint = Paint()..style = PaintingStyle.fill;
        paint.color = GeojsonCanvasWidget.getStatusColor(status);

        canvas.drawPath(path, paint);

        // Borda
        final strokePaint = Paint()
          ..style = PaintingStyle.stroke
          ..color = isSelected ? Colors.blue : Colors.black87
          ..strokeWidth = isSelected ? 2.0 : 0.5; // Destaque visual
        
        canvas.drawPath(path, strokePaint);
      }

      if (type == 'Polygon') {
        drawRing(coords[0] as List<dynamic>);
      } else if (type == 'MultiPolygon') {
        for (final poly in coords) {
          final polyCoords = poly as List<dynamic>;
          if (polyCoords.isNotEmpty) {
            drawRing(polyCoords[0] as List<dynamic>);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GeojsonPainter oldDelegate) {
    return oldDelegate.selectedFeatureIndex != selectedFeatureIndex ||
           oldDelegate.features != features;
  }
}
