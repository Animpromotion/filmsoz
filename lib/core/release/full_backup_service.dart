import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:filmsoz_studio/core/release/app_info.dart';
import 'package:filmsoz_studio/core/release/app_settings.dart';
import 'package:filmsoz_studio/core/release/project_migration_service.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:path/path.dart' as path;

class FilmsozFullBackup {
  const FilmsozFullBackup({
    required this.document,
    required this.projectName,
    required this.createdAt,
    required this.settings,
    this.projectPath,
  });

  final FilmDocument document;
  final String projectName;
  final String? projectPath;
  final DateTime createdAt;
  final FilmsozAppSettings settings;
}

class FilmsozFullBackupService {
  const FilmsozFullBackupService();

  static const XTypeGroup _backupTypeGroup = XTypeGroup(
    label: 'Filmsoz full backup',
    extensions: <String>['filmsozbackup'],
  );

  Future<String?> chooseSavePath({
    required String projectName,
    required FilmsozAppSettings settings,
  }) async {
    final cleanName = _cleanName(projectName);
    final location = await getSaveLocation(
      acceptedTypeGroups: const <XTypeGroup>[_backupTypeGroup],
      initialDirectory: settings.backupsDirectory.trim().isEmpty
          ? null
          : settings.backupsDirectory.trim(),
      suggestedName: '${cleanName}_full_backup.filmsozbackup',
      confirmButtonText: 'Создать резервную копию',
      canCreateDirectories: true,
    );

    if (location == null) {
      return null;
    }

    return _ensureExtension(location.path);
  }

  Future<String?> chooseOpenPath({
    required FilmsozAppSettings settings,
  }) async {
    final file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[_backupTypeGroup],
      initialDirectory: settings.backupsDirectory.trim().isEmpty
          ? null
          : settings.backupsDirectory.trim(),
      confirmButtonText: 'Восстановить',
    );
    return file?.path;
  }

  Future<String> write({
    required String filePath,
    required FilmDocument document,
    required String projectName,
    required FilmsozAppSettings settings,
    String? projectPath,
  }) async {
    final targetPath = _ensureExtension(filePath);
    final file = File(targetPath);
    await file.parent.create(recursive: true);
    final payload = <String, dynamic>{
      'format': 'filmsoz-full-backup',
      'version': 1,
      'appVersion': FilmsozAppInfo.fullVersion,
      'projectFormatVersion': FilmsozAppInfo.projectFormatVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'project': <String, dynamic>{
        'name': projectName,
        if (projectPath != null) 'path': projectPath,
      },
      'settings': settings.toJson(),
      'document': document.toJson(),
    };

    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      encoding: utf8,
      flush: true,
    );
    return targetPath;
  }

  Future<FilmsozFullBackup> read(String filePath) async {
    final file = File(filePath);

    if (!await file.exists()) {
      throw FileSystemException('Резервная копия не найдена.', filePath);
    }

    final decoded = jsonDecode(await file.readAsString(encoding: utf8));

    if (decoded is! Map) {
      throw const FormatException('Некорректная резервная копия Filmsoz.');
    }

    final root = decoded.map(
      (key, value) => MapEntry(key.toString(), value),
    );

    if (root['format']?.toString() != 'filmsoz-full-backup') {
      throw const FormatException('Файл не является полной копией Filmsoz.');
    }

    final migration = const FilmsozProjectMigrationService().migrate(
      <String, dynamic>{
        'format': 'filmsoz',
        'version': root['projectFormatVersion'],
        'project': root['project'],
        'document': root['document'],
      },
    );
    final rawDocument = migration.root['document'];

    if (rawDocument is! Map) {
      throw const FormatException('В резервной копии нет документа.');
    }

    final rawProject = root['project'];
    final project = rawProject is Map
        ? rawProject.map(
            (key, value) => MapEntry(key.toString(), value),
          )
        : <String, dynamic>{};
    final rawSettings = root['settings'];

    return FilmsozFullBackup(
      document: FilmDocument.fromJson(
        rawDocument.map(
          (key, value) => MapEntry(key.toString(), value),
        ),
      ),
      projectName: project['name']?.toString() ?? 'Восстановленный проект',
      projectPath: _nullableString(project['path']),
      createdAt: DateTime.tryParse(root['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      settings: rawSettings is Map
          ? FilmsozAppSettings.fromJson(
              rawSettings.map(
                (key, value) => MapEntry(key.toString(), value),
              ),
            )
          : const FilmsozAppSettings(),
    );
  }

  String _cleanName(String value) {
    final cleaned = path
        .basenameWithoutExtension(value.trim().isEmpty ? 'Filmsoz' : value)
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    return cleaned.isEmpty ? 'Filmsoz' : cleaned;
  }

  String _ensureExtension(String filePath) {
    return filePath.toLowerCase().endsWith('.filmsozbackup')
        ? filePath
        : '$filePath.filmsozbackup';
  }

  String? _nullableString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
