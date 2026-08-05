import 'dart:convert';
import 'dart:io';

import 'package:filmsoz_studio/core/release/app_settings_service.dart';
import 'package:path/path.dart' as path;

class FilmsozErrorLogEntry {
  const FilmsozErrorLogEntry({
    required this.timestamp,
    required this.category,
    required this.message,
    this.stackTrace = '',
  });

  final DateTime timestamp;
  final String category;
  final String message;
  final String stackTrace;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'timestamp': timestamp.toUtc().toIso8601String(),
      'category': category,
      'message': message,
      'stackTrace': stackTrace,
    };
  }

  factory FilmsozErrorLogEntry.fromJson(Map<String, dynamic> json) {
    return FilmsozErrorLogEntry(
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      category: json['category']?.toString() ?? 'unknown',
      message: json['message']?.toString() ?? '',
      stackTrace: json['stackTrace']?.toString() ?? '',
    );
  }
}

class FilmsozErrorLogService {
  const FilmsozErrorLogService({this.rootDirectoryPath});

  final String? rootDirectoryPath;

  Future<void> record(
    String category,
    Object error, [
    StackTrace? stackTrace,
  ]) async {
    try {
      final file = await _todayLogFile();
      final entry = FilmsozErrorLogEntry(
        timestamp: DateTime.now(),
        category: category.trim().isEmpty ? 'application' : category.trim(),
        message: error.toString(),
        stackTrace: stackTrace?.toString() ?? '',
      );
      await file.writeAsString(
        '${jsonEncode(entry.toJson())}\n',
        encoding: utf8,
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      // Logging must never crash the application.
    }
  }

  Future<List<FilmsozErrorLogEntry>> readRecent({
    int maxEntries = 200,
  }) async {
    final directory = await logDirectory();
    final files = <File>[];

    await for (final entity in directory.list()) {
      if (entity is File && entity.path.toLowerCase().endsWith('.jsonl')) {
        files.add(entity);
      }
    }

    files.sort((first, second) => second.path.compareTo(first.path));
    final result = <FilmsozErrorLogEntry>[];

    for (final file in files) {
      final lines = await file.readAsLines(encoding: utf8);

      for (final line in lines.reversed) {
        if (line.trim().isEmpty) {
          continue;
        }

        try {
          final decoded = jsonDecode(line);

          if (decoded is Map) {
            result.add(
              FilmsozErrorLogEntry.fromJson(
                decoded.map(
                  (key, value) => MapEntry(key.toString(), value),
                ),
              ),
            );
          }
        } catch (_) {
          continue;
        }

        if (result.length >= maxEntries) {
          return result;
        }
      }
    }

    return result;
  }

  Future<void> prune({required int maxFiles}) async {
    final directory = await logDirectory();
    final files = <File>[];

    await for (final entity in directory.list()) {
      if (entity is File && entity.path.toLowerCase().endsWith('.jsonl')) {
        files.add(entity);
      }
    }

    files.sort((first, second) => second.path.compareTo(first.path));
    final safeLimit = maxFiles.clamp(1, 90).toInt();

    for (final file in files.skip(safeLimit)) {
      await file.delete();
    }
  }

  Future<void> clear() async {
    final directory = await logDirectory();

    await for (final entity in directory.list()) {
      if (entity is File && entity.path.toLowerCase().endsWith('.jsonl')) {
        await entity.delete();
      }
    }
  }

  Future<Directory> logDirectory() async {
    final root = await FilmsozAppSettingsService(
      rootDirectoryPath: rootDirectoryPath,
    ).applicationDirectory();
    final directory = Directory(path.join(root.path, 'Logs'));

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return directory;
  }

  Future<File> _todayLogFile() async {
    final directory = await logDirectory();
    final now = DateTime.now().toUtc();
    String two(int value) => value.toString().padLeft(2, '0');
    final name = 'filmsoz_${now.year}${two(now.month)}${two(now.day)}.jsonl';
    return File(path.join(directory.path, name));
  }
}
