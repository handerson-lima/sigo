import 'package:flutter/material.dart';

class GeojsonCanvasWidget extends StatefulWidget {
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
  State<GeojsonCanvasWidget> createState() => _GeojsonCanvasWidgetState();
}

class _GeojsonCanvasWidgetState extends State<GeojsonCanvasWidget> {
  List<Path> _cachedPaths = [];
  double _width = 0;
  double _height = 0;
  List<dynamic> _features = [];

  @override
  void initState() {
    super.initState();
    _computePaths();
  }

  @override
  void didUpdateWidget(covariant GeojsonCanvasWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.geojsonData != widget.geojsonData) {
      _computePaths();
    }
  }

  void _computePaths() {
    _features = widget.geojsonData['features'] as List<dynamic>? ?? [];
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

    void processRing(List<dynamic> ring) {
      for (final point in ring) {
        final x = (point[0] as num).toDouble();
        final y = (point[1] as num).toDouble();
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }

    for (final feature in _features) {
      final geometry = feature['geometry'] as Map<String, dynamic>?;
      if (geometry == null) {
        debugPrint('Geometria inválida: geometry is null para feature');
        continue;
      }

      final type = geometry['type'];
      final coords = geometry['coordinates'] as List<dynamic>?;
      if (coords == null || coords.isEmpty) {
        debugPrint('Geometria inválida: coordinates is null or empty para feature');
        continue;
      }

      if (type == 'Polygon') {
        for (final ring in coords) {
          processRing(ring as List<dynamic>);
        }
      } else if (type == 'MultiPolygon') {
        for (final poly in coords) {
          final polyCoords = poly as List<dynamic>;
          for (final ring in polyCoords) {
            processRing(ring as List<dynamic>);
          }
        }
      }
    }

    if (minX == double.infinity) {
      _width = 0;
      _height = 0;
      _cachedPaths = [];
      return;
    }

    _width = maxX - minX;
    _height = maxY - minY;
    
    final offset = Offset(-minX, -minY);
    _cachedPaths = _features.map((feature) {
      final path = Path();
      final geometry = feature['geometry'] as Map<String, dynamic>?;
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
        for (final ring in coords) {
          addRing(ring as List<dynamic>);
        }
      } else if (type == 'MultiPolygon') {
        for (final poly in coords) {
          final polyCoords = poly as List<dynamic>;
          for (final ring in polyCoords) {
            addRing(ring as List<dynamic>);
          }
        }
      }
      return path;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_width == 0 && _height == 0) {
      return const Center(child: Text('Canvas vazio (sem coordenadas válidas).'));
    }

    return InteractiveViewer(
      boundaryMargin: const EdgeInsets.all(double.infinity),
      minScale: 0.1,
      maxScale: 10.0,
      constrained: false, // permite mover livremente em tela infinita
      child: GestureDetector(
        onTapUp: (details) {
          if (widget.onFeatureTap == null) return;
          final localPosition = details.localPosition;
          for (int i = _cachedPaths.length - 1; i >= 0; i--) {
            if (_cachedPaths[i].contains(localPosition)) {
              widget.onFeatureTap!(i);
              return;
            }
          }
          // Tap fora
          widget.onFeatureTap!(-1);
        },
        child: CustomPaint(
          size: Size(_width, _height), // Tamanho original exato mapeado em 0..width, 0..height
          painter: GeojsonPainter(
            features: _features,
            paths: _cachedPaths,
            selectedFeatureIndex: widget.selectedFeatureIndex,
          ),
        ),
      ),
    );
  }
}

class GeojsonPainter extends CustomPainter {
  final List<dynamic> features;
  final List<Path> paths;
  final int? selectedFeatureIndex;

  GeojsonPainter({
    required this.features,
    required this.paths,
    this.selectedFeatureIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < features.length; i++) {
      final feature = features[i];
      final path = paths[i];
      final isSelected = i == selectedFeatureIndex;
      final properties = feature['properties'] as Map<String, dynamic>? ?? {};
      final status = properties['status'] as String?;

      // Cor de preenchimento baseada no status
      Color fillColor = Colors.grey.withAlpha(128); // unknown
      if (status == 'resolvido') {
        fillColor = Colors.green.withAlpha(128);
      } else if (status == 'ambiguo') {
        fillColor = Colors.orange.withAlpha(128);
      }

      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = fillColor;
      
      canvas.drawPath(path, paint);

      // Borda
      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = isSelected ? Colors.blue : Colors.black87
        ..strokeWidth = isSelected ? 2.0 : 0.5; // Destaque visual
      
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant GeojsonPainter oldDelegate) {
    return oldDelegate.selectedFeatureIndex != selectedFeatureIndex ||
           oldDelegate.features != features;
  }
}
