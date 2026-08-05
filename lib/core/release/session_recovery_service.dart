import 'dart:convert';
import 'dart:io';

import 'package:filmsoz_studio/core/release/app_info.dart';
import 'package:filmsoz_studio/core/release/app_settings_service.dart';
import 'package:path/path.dart' as path;

class FilmsozSessionState {
  const FilmsozSessionState({
    required this.previousSessionWasUnclean,
    this.previousStartedAt,
  });

  final bool previousSessionWasUnclean;
  final DateTime? previousStartedAt;
}

class FilmsozSessionRecoveryService {
  const FilmsozSessionRecoveryService({this.rootDirectoryPath});

  final String? rootDirectoryPath;

  Future<FilmsozSessionState> beginSession() async {
    final file = await _markerFile();
    var previousWasUnclean = false;
    DateTime? previousStartedAt;

    if (await file.exists()) {
      try {
        final previous = _asStringMap(
          jsonDecode(await file.readAsString(encoding: utf8)),
        );
        previousWasUnclean = previous['cleanExit'] != true;
        previousStartedAt = DateTime.tryParse(
          previous['startedAt']?.toString() ?? '',
        );
      } catch (_) {
        previousWasUnclean = true;
      }
    }

    final now = DateTime.now().toUtc();
    await _writeMarker(<String, dynamic>{
      'format': 'filmsoz-session',
      'version': 1,
      'appVersion': FilmsozAppInfo.fullVersion,
      'startedAt': now.toIso8601String(),
      'cleanExit': false,
      'previousSessionWasUnclean': previousWasUnclean,
      if (previousStartedAt != null)
        'previousStartedAt': previousStartedAt.toUtc().toIso8601String(),
    });

    return FilmsozSessionState(
      previousSessionWasUnclean: previousWasUnclean,
      previousStartedAt: previousStartedAt,
    );
  }

  Future<void> markCleanExit() async {
    final file = await _markerFile();
    Map<String, dynamic> marker = <String, dynamic>{};

    if (await file.exists()) {
      try {
        marker = _asStringMap(
          jsonDecode(await file.readAsString(encoding: utf8)),
        );
      } catch (_) {
        marker = <String, dynamic>{};
      }
    }

    marker
      ..['format'] = 'filmsoz-session'
      ..['version'] = 1
      ..['appVersion'] = FilmsozAppInfo.fullVersion
      ..['startedAt'] = marker['startedAt']?.toString() ??
          DateTime.now().toUtc().toIso8601String()
      ..['cleanExit'] = true;
    await _writeMarker(marker);
  }

  Future<FilmsozSessionState> readState() async {
    final file = await _markerFile();

    if (!await file.exists()) {
      return const FilmsozSessionState(
        previousSessionWasUnclean: false,
      );
    }

    try {
      final marker = _asStringMap(
        jsonDecode(await file.readAsString(encoding: utf8)),
      );

      if (marker['cleanExit'] == true) {
        return const FilmsozSessionState(
          previousSessionWasUnclean: false,
        );
      }

      return FilmsozSessionState(
        previousSessionWasUnclean: marker['previousSessionWasUnclean'] == true,
        previousStartedAt: DateTime.tryParse(
          marker['previousStartedAt']?.toString() ?? '',
        ),
      );
    } catch (_) {
      return const FilmsozSessionState(
        previousSessionWasUnclean: true,
      );
    }
  }

  Future<void> _writeMarker(Map<String, dynamic> payload) async {
    final file = await _markerFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      encoding: utf8,
      flush: true,
    );
  }

  Map<String, dynamic> _asStringMap(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid session marker.');
    }

    return value.map(
      (key, item) => MapEntry(key.toString(), item),
    );
  }

  Future<File> _markerFile() async {
    final root = await FilmsozAppSettingsService(
      rootDirectoryPath: rootDirectoryPath,
    ).applicationDirectory();
    return File(path.join(root.path, 'session_state.json'));
  }
}
