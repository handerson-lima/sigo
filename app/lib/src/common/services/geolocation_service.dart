import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'geolocation_platform.dart';

/// Resultado encapsulado da leitura de geolocalização com dados e fallback defensivo.
class GeoLocationResult {
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final String? errorMessage;
  final bool isAvailable;

  const GeoLocationResult({
    this.latitude,
    this.longitude,
    this.accuracy,
    this.errorMessage,
    this.isAvailable = true,
  });

  const GeoLocationResult.unavailable([this.errorMessage])
    : latitude = null,
      longitude = null,
      accuracy = null,
      isAvailable = false;

  /// Retorna string formatada para gravação no carimbo da foto.
  String formatCoordinates() {
    if (!isAvailable || latitude == null || longitude == null) {
      return errorMessage ?? 'GPS: Indisponível';
    }
    return 'Lat: ${latitude!.toStringAsFixed(5)}, Long: ${longitude!.toStringAsFixed(5)}';
  }

  @override
  String toString() => formatCoordinates();
}

/// Contrato para o serviço de geolocalização com timeout e resiliência offline.
abstract class GeolocationService {
  Future<GeoLocationResult> getCurrentPosition({
    Duration timeout = const Duration(seconds: 4),
  });
}

typedef PositionLocator = Future<GeoLocationResult> Function({
  required Duration timeout,
});

/// Implementação padrão com suporte a timeout defensivo e delegados customizáveis para testes.
class DefaultGeolocationService implements GeolocationService {
  final PositionLocator? locatorOverride;

  DefaultGeolocationService({this.locatorOverride});

  @override
  Future<GeoLocationResult> getCurrentPosition({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    try {
      final locator = locatorOverride;
      if (locator != null) {
        return await Future.microtask(() => locator(timeout: timeout)).timeout(
          timeout,
          onTimeout: () => const GeoLocationResult.unavailable(
            'GPS: Tempo esgotado / Indisponível',
          ),
        );
      }

      return await Future.microtask(() => getPlatformCurrentPosition(timeout))
          .timeout(
            timeout,
            onTimeout: () => const GeoLocationResult.unavailable(
              'GPS: Tempo esgotado / Indisponível',
            ),
          );
    } on TimeoutException {
      return const GeoLocationResult.unavailable(
        'GPS: Tempo esgotado / Indisponível',
      );
    } catch (e) {
      return GeoLocationResult.unavailable('GPS: Indisponível ($e)');
    }
  }
}

/// Provider do serviço de geolocalização.
final geolocationServiceProvider = Provider<GeolocationService>((ref) {
  return DefaultGeolocationService();
});
