import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/sync/blob_attachment.dart';
import 'package:app/src/sync/operation_queue.dart';

void main() {
  group('Story 2.5 — Armazenamento Local de Blobs (blob_attachment)', () {
    // Magic bytes fixtures
    final validJpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46]);
    final validPng = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00]);
    final validWebp = Uint8List.fromList([
      0x52, 0x49, 0x46, 0x46, // RIFF
      0x20, 0x00, 0x00, 0x00, // tamanho
      0x57, 0x45, 0x42, 0x50, // WEBP
      0x56, 0x50, 0x38, 0x20, // VP8
    ]);
    final invalidFormat = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x35]); // %PDF-

    test('detectImageMimeType identifica tipos corretos via magic bytes', () {
      expect(detectImageMimeType(validJpeg), 'image/jpeg');
      expect(detectImageMimeType(validPng), 'image/png');
      expect(detectImageMimeType(validWebp), 'image/webp');
    });

    test('detectImageMimeType rejeita formatos não suportados', () {
      expect(
        () => detectImageMimeType(invalidFormat),
        throwsA(isA<StateError>().having((e) => e.message, 'message', 'Use JPEG, PNG ou WebP')),
      );
    });

    test('detectImageMimeType rejeita arquivo vazio', () {
      expect(
        () => detectImageMimeType(Uint8List(0)),
        throwsA(isA<StateError>().having((e) => e.message, 'message', 'Foto ausente ou acima de 10 MB')),
      );
    });

    test('detectImageMimeType rejeita arquivo que excede 10 MB', () {
      // Cria um Uint8List simulado que excede 10 MB (10 * 1024 * 1024 + 1)
      final oversizedBytes = Uint8List(kMaxBlobSizeBytes + 1);
      oversizedBytes[0] = 0xFF;
      oversizedBytes[1] = 0xD8;
      oversizedBytes[2] = 0xFF;
      oversizedBytes[3] = 0xE0;

      expect(
        () => detectImageMimeType(oversizedBytes),
        throwsA(isA<StateError>().having((e) => e.message, 'message', 'Foto ausente ou acima de 10 MB')),
      );
    });

    test('buildBlobAttachment gera metadados padronizados, SHA-256 e base64 fiel', () {
      const storagePath = 'construtoras/c1/obras/o1/diarios/d1/u1/foto.jpg';
      final attachment = buildBlobAttachment(
        bytes: validJpeg,
        storagePath: storagePath,
      );

      expect(attachment['contentType'], 'image/jpeg');
      expect(attachment['path'], storagePath);
      expect(attachment['size'], validJpeg.length);
      expect(attachment['sha256'], sha256.convert(validJpeg).toString());

      // Valida integridade do base64 gerado
      final decodedBytes = base64Decode(attachment['bytes'] as String);
      expect(decodedBytes, validJpeg);
      expect(attachment['id'], isNotEmpty);
    });

    test('Anexo de blob persiste na OperationQueue com bytes íntegros para modo offline', () async {
      final memoryDb = <String, Map<String, dynamic>>{};
      final queue = OperationQueue(
        sessionUid: () => 'u1',
        store: (action, json) async {
          final args = jsonDecode(json) as Map<String, dynamic>;
          if (action == 'insert') {
            memoryDb[args['key'] as String] = args;
            return jsonEncode(args);
          }
          if (action == 'list') {
            return jsonEncode(memoryDb.values.toList());
          }
          return 'null';
        },
        upload: (a, bytes, uid) async {},
        execute: (action, payload) async {},
        autoSync: false,
      );

      final attachment = buildBlobAttachment(
        bytes: validPng,
        storagePath: 'construtoras/c1/obras/o1/diarios/d1/u1/doc.png',
      );

      await queue.enqueue(
        'finalizeDiario',
        {'construtoraId': 'c1', 'obraId': 'o1', 'operationId': 'op-blob-1'},
        attachments: [attachment],
      );

      final items = await queue.list();
      expect(items.length, 1);
      final storedAttachment = (items.first['attachments'] as List).first as Map<String, dynamic>;
      expect(storedAttachment['contentType'], 'image/png');
      expect(storedAttachment['sha256'], sha256.convert(validPng).toString());

      // Garante que os bytes recuperados da fila são exatamente os bytes da imagem
      final recoveredBytes = base64Decode(storedAttachment['bytes'] as String);
      expect(recoveredBytes, validPng);
    });
  });
}
