import 'dart:convert';
import 'dart:io';

import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

class LocalStorageService {
  static const String _folderName = 'Filmsoz Studio';
  static const String _autosaveFileName = 'filmsoz_autosave.filmsoz';
  static const String _backupFileName = 'filmsoz_autosave.backup.filmsoz';

  Future<String> get autosavePath async {
    final file = await _getAutosaveFile();
    return file.path;
  }

  Future<void> saveToLocal(FilmDocument document) async {
    final autosaveFile = await _getAutosaveFile();
    final backupFile = await _getBackupFile();
    final temporaryFile = File('${autosaveFile.path}.tmp');

    final payload = <String, dynamic>{
      'format': 'filmsoz',
      'version': 1,
      'savedAt': DateTime.now().toUtc().toIso8601String(),
      'document': document.toJson(),
    };

    final jsonText = const JsonEncoder.withIndent('  ').convert(payload);

    await temporaryFile.writeAsString(
      jsonText,
      encoding: utf8,
      flush: true,
    );

    if (await autosaveFile.exists()) {
      await autosaveFile.copy(backupFile.path);
      await autosaveFile.delete();
    }

    await temporaryFile.rename(autosaveFile.path);

    debugPrint('[Filmsoz] Autosave written: ${autosaveFile.path}');
  }

  Future<FilmDocument?> loadFromLocal() async {
    final autosaveFile = await _getAutosaveFile();

    if (await autosaveFile.exists()) {
      try {
        final document = await _readDocument(autosaveFile);
        debugPrint('[Filmsoz] Autosave loaded: ${autosaveFile.path}');
        return document;
      } catch (error) {
        debugPrint('[Filmsoz] Autosave read failed: $error');

        final backupFile = await _getBackupFile();

        if (await backupFile.exists()) {
          final document = await _readDocument(backupFile);
          debugPrint('[Filmsoz] Backup loaded: ${backupFile.path}');
          return document;
        }

        rethrow;
      }
    }

    final backupFile = await _getBackupFile();

    if (await backupFile.exists()) {
      final document = await _readDocument(backupFile);
      debugPrint('[Filmsoz] Backup loaded: ${backupFile.path}');
      return document;
    }

    debugPrint('[Filmsoz] No autosave file yet: ${autosaveFile.path}');
    return null;
  }

  Future<FilmDocument> _readDocument(File file) async {
    final jsonText = await file.readAsString(encoding: utf8);
    final decoded = jsonDecode(jsonText);

    if (decoded is! Map) {
      throw const FormatException('Filmsoz file has an invalid format.');
    }

    final root = decoded.map(
      (key, value) => MapEntry(key.toString(), value),
    );

    final rawDocument = root['document'];

    if (rawDocument is Map) {
      return FilmDocument.fromJson(
        rawDocument.map(
          (key, value) => MapEntry(key.toString(), value),
        ),
      );
    }

    return FilmDocument.fromJson(root);
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
