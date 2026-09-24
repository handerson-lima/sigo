import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/common/services/geolocation_service.dart';
import 'package:app/src/common/services/watermark_service.dart';

/// Helper para gerar bytes de imagem PNG válida em memória para os testes.
Future<Uint8List> createTestPngBytes({
  int width = 200,
  int height = 200,
  ui.Color color = const ui.Color(0xFF2E7D32),
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(
    recorder,
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
  );
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = color,
  );
  final picture = recorder.endRecording();
  final img = await picture.toImage(width, height);
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Story 2.13 — GeolocationService & GeoLocationResult', () {
    test('formata coordenadas decimais corretamente quando disponível', () {
      const pos = GeoLocationResult(
        latitude: -23.55052,
        longitude: -46.63331,
        accuracy: 10.0,
      );

      expect(pos.isAvailable, isTrue);
      expect(pos.formatCoordinates(), 'Lat: -23.55052, Long: -46.63331');
      expect(pos.toString(), 'Lat: -23.55052, Long: -46.63331');
    });

    test('exibe mensagem descritiva quando indisponível ou permissão negada', () {
      const denied = GeoLocationResult.unavailable('GPS: Sem Permissão');
      expect(denied.isAvailable, isFalse);
      expect(denied.formatCoordinates(), 'GPS: Sem Permissão');

      const timeout = GeoLocationResult.unavailable('GPS: Tempo esgotado / Indisponível');
      expect(timeout.isAvailable, isFalse);
      expect(timeout.formatCoordinates(), 'GPS: Tempo esgotado / Indisponível');

      const defaultUnavail = GeoLocationResult.unavailable();
      expect(defaultUnavail.formatCoordinates(), 'GPS: Indisponível');
    });

    test('DefaultGeolocationService com locator customizado retorna coordenadas válidas', () async {
      final service = DefaultGeolocationService(
        locatorOverride: ({required timeout}) async {
          return const GeoLocationResult(
            latitude: -15.78010,
            longitude: -47.92920,
          );
        },
      );

      final result = await service.getCurrentPosition();
      expect(result.isAvailable, isTrue);
      expect(result.latitude, -15.78010);
      expect(result.longitude, -47.92920);
    });

    test('DefaultGeolocationService trata timeout graciosamente sem lançar exceção', () async {
      final service = DefaultGeolocationService(
        locatorOverride: ({required timeout}) async {
          await Future.delayed(const Duration(milliseconds: 200));
          return const GeoLocationResult(latitude: 0, longitude: 0);
        },
      );

      final result = await service.getCurrentPosition(
        timeout: const Duration(milliseconds: 50),
      );

      expect(result.isAvailable, isFalse);
      expect(result.formatCoordinates(), contains('GPS: Tempo esgotado'));
    });

    test('DefaultGeolocationService captura exceções e retorna indisponível', () async {
      final service = DefaultGeolocationService(
        locatorOverride: ({required timeout}) async {
          throw Exception('Hardware GPS desabilitado');
        },
      );

      final result = await service.getCurrentPosition();
      expect(result.isAvailable, isFalse);
      expect(result.formatCoordinates(), contains('GPS: Indisponível'));
    });
  });

  group('Story 2.13 — WatermarkService (Aplicação de Carimbo Visual)', () {
    late WatermarkService watermarkService;

    setUp(() {
      watermarkService = WatermarkService();
    });

    test('aplica carimbo sobre imagem com GPS, data/hora e contexto da obra', () async {
      final originalBytes = await createTestPngBytes(width: 400, height: 300);
      expect(originalBytes.isNotEmpty, isTrue);

      final metadata = WatermarkMetadata(
        timestamp: DateTime(2026, 9, 16, 14, 30, 0),
        location: const GeoLocationResult(
          latitude: -23.55052,
          longitude: -46.63331,
        ),
        obraNomeOuId: 'Residencial Aurora',
        responsavelNomeOuUid: 'Eng. Carlos',
      );

      final stampedBytes = await watermarkService.applyWatermark(
        originalBytes,
        metadata,
      );

      expect(stampedBytes, isNotNull);
      expect(stampedBytes.isNotEmpty, isTrue);
      expect(stampedBytes, isNot(equals(originalBytes)));

      // Verifica se a imagem resultante é decodificável e preserva dimensões
      final codec = await ui.instantiateImageCodec(stampedBytes);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 400);
      expect(frame.image.height, 300);
    });

    test('aplica carimbo com indicação graciosa de GPS indisponível / sem permissão', () async {
      final originalBytes = await createTestPngBytes(width: 300, height: 300);

      final metadata = WatermarkMetadata(
        timestamp: DateTime(2026, 9, 16, 18, 45, 12),
        location: const GeoLocationResult.unavailable('GPS: Sem Permissão'),
        obraNomeOuId: 'Obra Central 01',
      );

      final stampedBytes = await watermarkService.applyWatermark(
        originalBytes,
        metadata,
      );

      expect(stampedBytes.isNotEmpty, isTrue);
      expect(stampedBytes, isNot(equals(originalBytes)));

      final codec = await ui.instantiateImageCodec(stampedBytes);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 300);
      expect(frame.image.height, 300);
    });

    test('funciona com diferentes formatos e resoluções (retrato, paisagem, alta resolução)', () async {
      // Retrato
      final portraitBytes = await createTestPngBytes(width: 300, height: 600);
      final stampedPortrait = await watermarkService.applyWatermark(
        portraitBytes,
        WatermarkMetadata(
          timestamp: DateTime.now(),
          obraNomeOuId: 'Torre A',
        ),
      );
      final codecPortrait = await ui.instantiateImageCodec(stampedPortrait);
      final framePortrait = await codecPortrait.getNextFrame();
      expect(framePortrait.image.width, 300);
      expect(framePortrait.image.height, 600);

      // Paisagem de alta resolução
      final highResBytes = await createTestPngBytes(width: 1200, height: 800);
      final stampedHighRes = await watermarkService.applyWatermark(
        highResBytes,
        WatermarkMetadata(
          timestamp: DateTime.now(),
          location: const GeoLocationResult(
            latitude: -22.9068,
            longitude: -43.1729,
          ),
          obraNomeOuId: 'Condomínio Imperial',
          responsavelNomeOuUid: 'Fiscal Maria',
        ),
      );
      final codecHighRes = await ui.instantiateImageCodec(stampedHighRes);
      final frameHighRes = await codecHighRes.getNextFrame();
      expect(frameHighRes.image.width, 1200);
      expect(frameHighRes.image.height, 800);
    });

    test('retorna bytes originais como fallback seguro se os dados forem inválidos', () async {
      final invalidBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final result = await watermarkService.applyWatermark(
        invalidBytes,
        WatermarkMetadata(timestamp: DateTime.now()),
      );

      expect(result, equals(invalidBytes));

      final emptyBytes = Uint8List(0);
      final emptyResult = await watermarkService.applyWatermark(
        emptyBytes,
        WatermarkMetadata(timestamp: DateTime.now()),
      );
      expect(emptyResult, equals(emptyBytes));
    });

    test('stampPhoto helper executa ciclo completo integrando geolocalização', () async {
      final originalBytes = await createTestPngBytes(width: 250, height: 250);

      final fakeGeoService = DefaultGeolocationService(
        locatorOverride: ({required timeout}) async {
          return const GeoLocationResult(
            latitude: -19.92083,
            longitude: -43.93778,
          );
        },
      );

      final stampedBytes = await watermarkService.stampPhoto(
        imageBytes: originalBytes,
        loteamentoId: 'obra-bh-101', quadraId: 'obra-bh-101', status: LoteStatus.noPrazo,
        obraNome: 'Edifício Savassi',
        responsavelId: 'user-789',
        responsavelNome: 'Mestre Silva',
        geolocationService: fakeGeoService,
      );

      expect(stampedBytes.isNotEmpty, isTrue);
      expect(stampedBytes, isNot(equals(originalBytes)));

      final codec = await ui.instantiateImageCodec(stampedBytes);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 250);
      expect(frame.image.height, 250);
    });
  });
}
