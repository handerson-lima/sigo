import 'dart:convert';
import 'dart:js_interop';

import 'geolocation_service.dart';

@JS('sigoGetCurrentPosition')
external JSPromise<JSString>? _sigoGetCurrentPosition(JSNumber timeoutMs);

/// Implementação Web utilizando a API do navegador via JS Interop.
Future<GeoLocationResult> getPlatformCurrentPosition(Duration timeout) async {
  try {
    final promise = _sigoGetCurrentPosition(timeout.inMilliseconds.toJS);
    if (promise == null) {
      return const GeoLocationResult.unavailable('GPS: Indisponível');
    }
    final jsResult = await promise.toDart;
    final jsonStr = jsResult.toDart;
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    if (map['error'] != null) {
      return GeoLocationResult.unavailable(map['error'] as String);
    }
    return GeoLocationResult(
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      accuracy: (map['accuracy'] as num?)?.toDouble(),
    );
  } catch (e) {
    return GeoLocationResult.unavailable('GPS: Indisponível ($e)');
  }
}
