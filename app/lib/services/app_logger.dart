import 'dart:io';

import 'package:path_provider/path_provider.dart';

class AppLogger {
  AppLogger._();

  static File? _file;

  static Future<File> file() async {
    final existing = _file;
    if (existing != null) return existing;
    final dir = await getApplicationDocumentsDirectory();
    final log = File('${dir.path}/candle_clash.log');
    if (!await log.exists()) {
      await log.create(recursive: true);
    }
    _file = log;
    return log;
  }

  static Future<void> info(String message) => write('INFO', message);

  static Future<void> error(
    String message, [
    Object? error,
    StackTrace? stack,
  ]) {
    final suffix = [
      if (error != null) 'error=$error',
      if (stack != null) 'stack=$stack',
    ].join('\n');
    return write('ERROR', suffix.isEmpty ? message : '$message\n$suffix');
  }

  static Future<void> write(String level, String message) async {
    final line = '[${DateTime.now().toIso8601String()}][$level] $message\n';
    assert(() {
      // ignore: avoid_print
      print(line.trimRight());
      return true;
    }());
    try {
      final log = await file();
      await log.writeAsString(line, mode: FileMode.append, flush: true);
    } catch (_) {
      // Logging must never break gameplay.
    }
  }
}
