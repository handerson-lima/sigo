import 'geolocation_service.dart';

/// Fallback nativo / desktop / testes para obtenção de coordenadas.
Future<GeoLocationResult> getPlatformCurrentPosition(Duration timeout) async {
  return const GeoLocationResult.unavailable('GPS: Indisponível');
}
