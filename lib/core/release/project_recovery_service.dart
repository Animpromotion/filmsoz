import 'dart:convert';
import 'dart:io';

import 'package:filmsoz_studio/core/release/project_diagnostics_service.dart';
import 'package:filmsoz_studio/core/release/project_migration_service.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';

class FilmsozProjectRecoveryResult {
  const FilmsozProjectRecoveryResult({
    required this.document,
    required this.messages,
    required this.sourceVersion,
    required this.usedTrimmedJson,
  });

  final FilmDocument document;
  final List<String> messages;
  final int sourceVersion;
  final bool usedTrimmedJson;
}

class FilmsozProjectRecoveryService {
  const FilmsozProjectRecoveryService({
    this.migrationService = const FilmsozProjectMigrationService(),
    this.diagnosticsService = const FilmsozProjectDiagnosticsService(),
  });

  final FilmsozProjectMigrationService migrationService;
  final FilmsozProjectDiagnosticsService diagnosticsService;

  Future<FilmsozProjectRecoveryResult> recoverFile(String filePath) async {
    final file = File(filePath);

    if (!await file.exists()) {
      throw FileSystemException('Файл проекта не найден.', filePath);
    }

    final text = await file.readAsString(encoding: utf8);
    Object? decoded;
    var usedTrimmedJson = false;

    try {
      decoded = jsonDecode(text);
    } on FormatException {
      final recoveredJson = _extractRootJsonObject(text);

      if (recoveredJson == null) {
        rethrow;
      }

      decoded = jsonDecode(recoveredJson);
      usedTrimmedJson = recoveredJson.length != text.trim().length;
    }

    final migration = migrationService.migrate(decoded);
    final rawDocument = migration.root['document'];

    if (rawDocument is! Map) {
      throw const FormatException('В файле не удалось найти документ.');
    }

    final document = FilmDocument.fromJson(
      rawDocument.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
    );
    final optimized = diagnosticsService.optimize(document);
    final messages = <String>[
      ...migration.messages,
      ...optimized.messages,
    ];

    if (usedTrimmedJson) {
      messages.insert(
        0,
        'Удалены повреждённые данные до или после JSON-документа.',
      );
    }

    return FilmsozProjectRecoveryResult(
      document: optimized.document,
      messages: List<String>.unmodifiable(messages),
      sourceVersion: migration.sourceVersion,
      usedTrimmedJson: usedTrimmedJson,
    );
  }

  String? _extractRootJsonObject(String source) {
    final start = source.indexOf('{');

    if (start == -1) {
      return null;
    }

    var depth = 0;
    var inString = false;
    var escaped = false;

    for (var index = start; index < source.length; index++) {
      final character = source[index];

      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (character == '\\') {
          escaped = true;
        } else if (character == '"') {
          inString = false;
        }

        continue;
      }

      if (character == '"') {
        inString = true;
      } else if (character == '{') {
        depth++;
      } else if (character == '}') {
        depth--;

        if (depth == 0) {
          return source.substring(start, index + 1);
        }
      }
    }

    return null;
  }
}
