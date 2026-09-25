import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'geolocation_service.dart';

/// Metadados a serem gravados de forma indelével na imagem.
class WatermarkMetadata {
  final DateTime timestamp;
  final GeoLocationResult? location;
  final String? obraNomeOuId;
  final String? responsavelNomeOuUid;

  const WatermarkMetadata({
    required this.timestamp,
    this.location,
    this.obraNomeOuId,
    this.responsavelNomeOuUid,
  });
}

/// Serviço de aplicação de carimbo (Watermark) diretamente nos pixels da imagem via Canvas.
class WatermarkService {
  /// Aplica a tarja e textos informativos sobre os bytes da imagem.
  /// Em caso de falha de renderização ou formato inválido, retorna os [imageBytes] originais.
  Future<Uint8List> applyWatermark(
    Uint8List imageBytes,
    WatermarkMetadata metadata,
  ) async {
    if (imageBytes.isEmpty) return imageBytes;

    try {
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final width = image.width;
      final height = image.height;

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(
        recorder,
        ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      );

      // 1. Desenha a imagem original
      canvas.drawImage(image, ui.Offset.zero, ui.Paint());

      // 2. Prepara as linhas de texto
      final lines = <String>[];

      // Linha 1: Data e hora
      final dateFormatted = DateFormat('dd/MM/yyyy HH:mm:ss').format(metadata.timestamp);
      lines.add(dateFormatted);

      // Linha 2: Coordenadas geográficas
      final gpsFormatted = metadata.location?.formatCoordinates() ?? 'GPS: Indisponível';
      lines.add(gpsFormatted);

      // Linha 3: Obra e Responsável
      final contextSegments = <String>[];
      if (metadata.obraNomeOuId != null && metadata.obraNomeOuId!.trim().isNotEmpty) {
        contextSegments.add('Loteamento: ${metadata.obraNomeOuId!.trim()}');
      }
      if (metadata.responsavelNomeOuUid != null && metadata.responsavelNomeOuUid!.trim().isNotEmpty) {
        contextSegments.add('Resp: ${metadata.responsavelNomeOuUid!.trim()}');
      }
      if (contextSegments.isNotEmpty) {
        lines.add(contextSegments.join(' | '));
      }

      // 3. Cálculo de proporção dinâmico (escala baseada na largura e orientação)
      final minDimension = width < height ? width : height;
      final scale = (minDimension / 800.0).clamp(0.6, 4.0);
      final fontSize = (18.0 * scale).clamp(11.0, 64.0);
      final lineHeight = fontSize * 1.35;
      final horizontalPadding = (16.0 * scale).clamp(10.0, 48.0);
      final verticalPadding = (12.0 * scale).clamp(8.0, 36.0);

      final totalTextHeight = lines.length * lineHeight;
      final bandHeight = totalTextHeight + (verticalPadding * 2);

      // 4. Faixa de fundo semi-transparente de alto contraste
      final bandRect = ui.Rect.fromLTWH(
        0,
        height - bandHeight,
        width.toDouble(),
        bandHeight,
      );

      final bandPaint = ui.Paint()
        ..color = const ui.Color(0xB3000000) // ~70% preto
        ..style = ui.PaintingStyle.fill;
      canvas.drawRect(bandRect, bandPaint);

      // Linha sutil de destaque no topo da faixa
      final accentPaint = ui.Paint()
        ..color = const ui.Color(0xFF00B4D8) // Tom ciano/azul da identidade SIGO
        ..strokeWidth = (2.0 * scale).clamp(1.0, 6.0)
        ..style = ui.PaintingStyle.stroke;
      canvas.drawLine(
        ui.Offset(0, height - bandHeight),
        ui.Offset(width.toDouble(), height - bandHeight),
        accentPaint,
      );

      // 5. Renderização dos textos
      double currentY = height - bandHeight + verticalPadding;
      for (final line in lines) {
        final paragraphBuilder = ui.ParagraphBuilder(
          ui.ParagraphStyle(
            textAlign: ui.TextAlign.left,
            maxLines: 1,
            ellipsis: '...',
          ),
        )
          ..pushStyle(
            ui.TextStyle(
              color: const ui.Color(0xFFFFFFFF),
              fontSize: fontSize,
              fontWeight: ui.FontWeight.w600,
            ),
          )
          ..addText(line);

        final paragraph = paragraphBuilder.build()
          ..layout(
            ui.ParagraphConstraints(width: width - (horizontalPadding * 2)),
          );

        canvas.drawParagraph(paragraph, ui.Offset(horizontalPadding, currentY));
        currentY += lineHeight;
      }

      // 6. Converte o Picture gravado de volta em imagem e bytes PNG
      final picture = recorder.endRecording();
      final watermarkedImage = await picture.toImage(width, height);
      final byteData = await watermarkedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) {
        return imageBytes;
      }

      return byteData.buffer.asUint8List();
    } catch (e) {
      debugPrint('Falha ao processar carimbo visual: $e');
      return imageBytes;
    }
  }

  /// Método utilitário integrado que obtém geolocalização e aplica o carimbo em uma única chamada.
  Future<Uint8List> stampPhoto({
    required Uint8List imageBytes,
    required String obraId,
    String? obraNome,
    required String responsavelId,
    String? responsavelNome,
    GeolocationService? geolocationService,
    Duration gpsTimeout = const Duration(seconds: 4),
  }) async {
    GeoLocationResult? location;
    if (geolocationService != null) {
      try {
        location = await geolocationService.getCurrentPosition(
          timeout: gpsTimeout,
        );
      } catch (e) {
        location = const GeoLocationResult.unavailable('GPS: Indisponível');
      }
    } else {
      location = const GeoLocationResult.unavailable('GPS: Indisponível');
    }

    final metadata = WatermarkMetadata(
      timestamp: DateTime.now(),
      location: location,
      obraNomeOuId: obraNome ?? obraId,
      responsavelNomeOuUid: responsavelNome ?? responsavelId,
    );

    return applyWatermark(imageBytes, metadata);
  }
}

/// Provider do serviço de carimbo.
final watermarkServiceProvider = Provider<WatermarkService>((ref) {
  return WatermarkService();
});
