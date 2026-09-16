import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

Future<String> queueStore(String action, String input) async {
  final args = jsonDecode(input) as Map<String, dynamic>;
  final dir = Directory(
    '${(await getApplicationDocumentsDirectory()).path}/sigo-queue-v1',
  );
  await dir.create(recursive: true);
  final lock = await File('${dir.path}/lock').open(mode: FileMode.append);
  await lock.lock();
  try {
    if (action.startsWith('cache')) {
      final cache = Directory('${dir.path}/read-cache');
      await cache.create(recursive: true);
      File? getFile() => args['key'] != null
          ? File('${cache.path}/${sha256.convert(utf8.encode(args['key'] as String))}.json')
          : null;
      if (action == 'cacheGet') {
        final file = getFile();
        if (file == null || !await file.exists()) return 'null';
        final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        return data['uid'] == args['uid'] ? jsonEncode(data['value']) : 'null';
      }
      if (action == 'cachePut') {
        final file = getFile();
        if (file != null) {
          await file.writeAsString(jsonEncode(args), flush: true);
        }
      }
      if (action == 'cacheClear') {
        await for (final entry in cache.list()) {
          if (entry is File &&
              jsonDecode(await entry.readAsString())['uid'] == args['uid']) {
            await entry.delete();
          }
        }
      }
      return 'null';
    }
    if (action == 'list') {
      final all = <dynamic>[];
      await for (final file in dir.list()) {
        if (file is File && file.path.endsWith('.json')) {
          final row = jsonDecode(await file.readAsString());
          if (row['uid'] == args['uid']) all.add(row);
        }
      }
      return jsonEncode(all);
    }
    final name = sha256.convert(utf8.encode(args['key'] as String)).toString();
    final file = File('${dir.path}/$name.json');
    Map<String, dynamic>? row = await file.exists()
        ? jsonDecode(await file.readAsString())
        : null;
    if (action == 'insert' && row == null) {
      row = args;
    } else if (action == 'claim') {
      if (row == null ||
          row['uid'] != args['uid'] ||
          [
            'synced',
            'conflict',
            'authorization_rejected',
          ].contains(row['state']) ||
          (row['leaseUntil'] as int? ?? 0) >
              DateTime.now().millisecondsSinceEpoch ||
          (args['force'] != true &&
              (row['nextAttemptAt'] as int? ?? 0) >
                  DateTime.now().millisecondsSinceEpoch)) {
        return 'null';
      }
      row['state'] = 'syncing';
      row['lease'] = args['lease'];
      row['leaseUntil'] = DateTime.now().millisecondsSinceEpoch + 120000;
    } else if (action == 'finish') {
      if (row == null ||
          row['uid'] != args['uid'] ||
          row['lease'] != args['lease']) {
        return 'null';
      }
      row['state'] = args['state'];
      row['error'] = args['error'];
      row['lease'] = null;
      row['leaseUntil'] = 0;
      row['attempts'] = (row['attempts'] as int? ?? 0) + 1;
      row['nextAttemptAt'] = args['state'] == 'failed'
          ? DateTime.now().millisecondsSinceEpoch + 15000
          : 0;
    }
    if (row != null) {
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(jsonEncode(row), flush: true);
      await temporary.rename(file.path);
    }
    return jsonEncode(row);
  } finally {
    await lock.unlock();
    await lock.close();
  }
}
