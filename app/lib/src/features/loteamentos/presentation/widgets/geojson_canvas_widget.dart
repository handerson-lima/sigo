import 'package:flutter/material.dart';

class GeojsonCanvasWidget extends StatelessWidget {
  final Map<String, dynamic> geojsonData;

  const GeojsonCanvasWidget({
    super.key,
    required this.geojsonData,
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
      if (geometry == null) continue;
      final type = geometry['type'];
      if (type == 'Polygon') {
        final coords = geometry['coordinates'] as List<dynamic>?;
        if (coords != null && coords.isNotEmpty) {
          final ring = coords[0] as List<dynamic>;
          for (final point in ring) {
            final x = (point[0] as num).toDouble();
            final y = (point[1] as num).toDouble();
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
          }
        }
      }
    }

    if (minX == double.infinity) {
      return const Center(child: Text('Geometria inválida.'));
    }

    final width = maxX - minX;
    final height = maxY - minY;
    
    return InteractiveViewer(
      boundaryMargin: const EdgeInsets.all(double.infinity),
      minScale: 0.1,
      maxScale: 10.0,
      constrained: false, // permite mover livremente em tela infinita
      child: Transform.translate(
        // Centraliza os desenhos movendo a origem baseada no centro do bbox
        offset: Offset(-minX - width / 2, -minY - height / 2),
        child: CustomPaint(
          size: Size(width, height), // Tamanho original em coordenadas do mapa
          painter: _GeojsonPainter(features: features),
        ),
      ),
    );
  }
}

class _GeojsonPainter extends CustomPainter {
  final List<dynamic> features;

  _GeojsonPainter({required this.features});

  @override
  void paint(Canvas canvas, Size size) {
    for (final feature in features) {
      final properties = feature['properties'] as Map<String, dynamic>? ?? {};
      final status = properties['status'] as String?;
      final geometry = feature['geometry'] as Map<String, dynamic>?;

      if (geometry == null) continue;
      final type = geometry['type'];
      
      if (type == 'Polygon') {
        final coords = geometry['coordinates'] as List<dynamic>?;
        if (coords != null && coords.isNotEmpty) {
          final ring = coords[0] as List<dynamic>;
          
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
          if (status == 'ambiguo') {
            paint.color = Colors.orange.withValues(alpha: 0.6);
          } else if (status == 'aprovado' || status == 'resolvido') {
            paint.color = Colors.green.withValues(alpha: 0.6);
          } else {
            paint.color = Colors.grey.withValues(alpha: 0.4);
          }

          canvas.drawPath(path, paint);

          // Borda
          final strokePaint = Paint()
            ..style = PaintingStyle.stroke
            ..color = Colors.black87
            ..strokeWidth = 0.5; // Espessura fina
          
          // Nota: como a escala pode estar muito variada, o ideal seria que a espessura da linha não escalasse,
          // mas como estamos usando CustomPaint simples, essa linha escalará com o zoom do InteractiveViewer.
          canvas.drawPath(path, strokePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GeojsonPainter oldDelegate) {
    return true; // Simplificado para redesenhar quando o estado mudar
  }
}
