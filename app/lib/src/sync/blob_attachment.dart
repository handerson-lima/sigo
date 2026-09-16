import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

const int kMaxBlobSizeBytes = 10 * 1024 * 1024; // 10 MB

/// Detecta o tipo MIME da imagem a partir dos seus magic bytes reais.
String detectImageMimeType(Uint8List bytes) {
  if (bytes.isEmpty || bytes.length > kMaxBlobSizeBytes) {
    throw StateError('Foto ausente ou acima de 10 MB');
  }
  if (bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
    return 'image/jpeg';
  }
  if (bytes.length > 8 && bytes[0] == 0x89 && bytes[1] == 0x50) {
    return 'image/png';
  }
  if (bytes.length > 12 &&
      ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
      ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') {
    return 'image/webp';
  }
  throw StateError('Use JPEG, PNG ou WebP');
}

/// Cria o payload de anexo binário padronizado para a fila durável IndexedDB.
Map<String, dynamic> buildBlobAttachment({
  required Uint8List bytes,
  required String storagePath,
  String? id,
}) {
  final contentType = detectImageMimeType(bytes);
  final attachmentId = id ?? const Uuid().v4();
  final hash = sha256.convert(bytes).toString();

  return {
    'id': attachmentId,
    'size': bytes.length,
    'sha256': hash,
    'contentType': contentType,
    'bytes': base64Encode(bytes),
    'path': storagePath,
  };
}
