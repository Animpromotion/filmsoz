import 'dart:convert';
import 'dart:io';

import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

class StoredFilmsozProject {
  const StoredFilmsozProject({
    required this.document,
    this.projectPath,
    this.projectName,
    this.isDirty = false,
  });

  final FilmDocument document;
  final String? projectPath;
  final String? projectName;
  final bool isDirty;
}

class LocalStorageService {
  static const String _folderName = 'Filmsoz Studio';
  static const String _autosaveFileName = 'filmsoz_autosave.filmsoz';
  static const String _backupFileName = 'filmsoz_autosave.backup.filmsoz';

  Future<String> get autosavePath async {
    final file = await _getAutosaveFile();
    return file.path;
  }

  String normalizeProjectPath(String filePath) {
    final trimmedPath = filePath.trim();

    if (trimmedPath.toLowerCase().endsWith('.filmsoz')) {
      return trimmedPath;
    }

    return '$trimmedPath.filmsoz';
  }

  Future<void> saveToLocal(
    FilmDocument document, {
    String? projectPath,
    String? projectName,
    bool isDirty = false,
  }) async {
    final autosaveFile = await _getAutosaveFile();
    final backupFile = await _getBackupFile();

    await _writeDocument(
      targetFile: autosaveFile,
      backupFile: backupFile,
      document: document,
      projectPath: projectPath,
      projectName: projectName,
      isDirty: isDirty,
    );

    debugPrint('[Filmsoz] Autosave written: ${autosaveFile.path}');
  }

  Future<StoredFilmsozProject?> loadAutosaveState() async {
    final autosaveFile = await _getAutosaveFile();

    if (await autosaveFile.exists()) {
      try {
        final state = await _readStoredProject(autosaveFile);
        debugPrint('[Filmsoz] Autosave loaded: ${autosaveFile.path}');
        return state;
      } catch (error) {
        debugPrint('[Filmsoz] Autosave read failed: $error');

        final backupFile = await _getBackupFile();

        if (await backupFile.exists()) {
          final state = await _readStoredProject(backupFile);
          debugPrint('[Filmsoz] Backup loaded: ${backupFile.path}');
          return state;
        }

        rethrow;
      }
    }

    final backupFile = await _getBackupFile();

    if (await backupFile.exists()) {
      final state = await _readStoredProject(backupFile);
      debugPrint('[Filmsoz] Backup loaded: ${backupFile.path}');
      return state;
    }

    debugPrint('[Filmsoz] No autosave file yet: ${autosaveFile.path}');
    return null;
  }

  Future<FilmDocument?> loadFromLocal() async {
    final state = await loadAutosaveState();
    return state?.document;
  }

  Future<String> saveProjectToPath(
    FilmDocument document,
    String filePath,
  ) async {
    final normalizedPath = normalizeProjectPath(filePath);
    final targetFile = File(normalizedPath);
    final backupFile = File('$normalizedPath.backup');

    final parentDirectory = targetFile.parent;

    if (!await parentDirectory.exists()) {
      await parentDirectory.create(recursive: true);
    }

    await _writeDocument(
      targetFile: targetFile,
      backupFile: backupFile,
      document: document,
      projectPath: normalizedPath,
      projectName: path.basenameWithoutExtension(normalizedPath),
      isDirty: false,
    );

    debugPrint('[Filmsoz] Project written: $normalizedPath');
    return normalizedPath;
  }

  Future<FilmDocument> loadProjectFromPath(String filePath) async {
    final normalizedPath = normalizeProjectPath(filePath);
    final file = File(normalizedPath);

    if (!await file.exists()) {
      throw FileSystemException(
        'Файл проекта не найден.',
        normalizedPath,
      );
    }

    final state = await _readStoredProject(file);
    debugPrint('[Filmsoz] Project loaded: $normalizedPath');
    return state.document;
  }

  Future<void> _writeDocument({
    required File targetFile,
    required File backupFile,
    required FilmDocument document,
    required String? projectPath,
    required String? projectName,
    required bool isDirty,
  }) async {
    final temporaryFile = File('${targetFile.path}.tmp');

    final payload = <String, dynamic>{
      'format': 'filmsoz',
      'version': 2,
      'savedAt': DateTime.now().toUtc().toIso8601String(),
      'project': <String, dynamic>{
        'path': projectPath,
        'name': projectName,
        'isDirty': isDirty,
      },
      'document': document.toJson(),
    };

    final jsonText = const JsonEncoder.withIndent('  ').convert(payload);

    await temporaryFile.writeAsString(
      jsonText,
      encoding: utf8,
      flush: true,
    );

    if (await targetFile.exists()) {
      await targetFile.copy(backupFile.path);
      await targetFile.delete();
    }

    await temporaryFile.rename(targetFile.path);
  }

  Future<StoredFilmsozProject> _readStoredProject(File file) async {
    final jsonText = await file.readAsString(encoding: utf8);
    final decoded = jsonDecode(jsonText);

    if (decoded is! Map) {
      throw const FormatException('Filmsoz file has an invalid format.');
    }

    final root = decoded.map(
      (key, value) => MapEntry(key.toString(), value),
    );

    final rawDocument = root['document'];
    final FilmDocument document;

    if (rawDocument is Map) {
      document = FilmDocument.fromJson(
        rawDocument.map(
          (key, value) => MapEntry(key.toString(), value),
        ),
      );
    } else {
      document = FilmDocument.fromJson(root);
    }

    final rawProject = root['project'];
    String? projectPath;
    String? projectName;
    var isDirty = false;

    if (rawProject is Map) {
      final project = rawProject.map(
        (key, value) => MapEntry(key.toString(), value),
      );

      final rawPath = project['path']?.toString().trim();
      final rawName = project['name']?.toString().trim();

      if (rawPath != null && rawPath.isNotEmpty) {
        projectPath = rawPath;
      }

      if (rawName != null && rawName.isNotEmpty) {
        projectName = rawName;
      }

      isDirty = project['isDirty'] == true;
    }

    return StoredFilmsozProject(
      document: document,
      projectPath: projectPath,
      projectName: projectName,
      isDirty: isDirty,
    );
  }

  Future<File> _getAutosaveFile() async {
    final directory = await _getStorageDirectory();
    return File(path.join(directory.path, _autosaveFileName));
  }

  Future<File> _getBackupFile() async {
    final directory = await _getStorageDirectory();
    return File(path.join(directory.path, _backupFileName));
  }

  Future<Directory> _getStorageDirectory() async {
    final userProfile = Platform.environment['USERPROFILE'];

    Directory baseDirectory;

    if (Platform.isWindows && userProfile != null && userProfile.isNotEmpty) {
      final documentsDirectory = Directory(
        path.join(userProfile, 'Documents'),
      );

      baseDirectory = await documentsDirectory.exists()
          ? documentsDirectory
          : Directory(userProfile);
    } else {
      baseDirectory = Directory.current;
    }

    final filmsozDirectory = Directory(
      path.join(baseDirectory.path, _folderName),
    );

    if (!await filmsozDirectory.exists()) {
      await filmsozDirectory.create(recursive: true);
    }

    return filmsozDirectory;
  }
}
