import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/parser/fountain_parser.dart';
import 'package:path/path.dart' as path;

class FountainImportResult {
  const FountainImportResult({
    required this.document,
    required this.sourcePath,
    required this.suggestedProjectName,
  });

  final FilmDocument document;
  final String sourcePath;
  final String suggestedProjectName;
}

class FountainFileService {
  const FountainFileService();

  static const XTypeGroup _fountainTypeGroup = XTypeGroup(
    label: 'Fountain screenplay',
    extensions: <String>['fountain'],
  );

  Future<String?> chooseImportFile() async {
    final file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[_fountainTypeGroup],
      confirmButtonText: 'Импортировать',
    );

    return file?.path;
  }

  Future<String?> chooseExportFile({
    required String suggestedName,
  }) async {
    final cleanName = suggestedName.trim().isEmpty
        ? 'Без названия'
        : path.basenameWithoutExtension(suggestedName.trim());

    final location = await getSaveLocation(
      acceptedTypeGroups: const <XTypeGroup>[_fountainTypeGroup],
      suggestedName: '$cleanName.fountain',
      confirmButtonText: 'Экспортировать',
      canCreateDirectories: true,
    );

    if (location == null) {
      return null;
    }

    return _ensureFountainExtension(location.path);
  }

  Future<FountainImportResult> importFromPath(String filePath) async {
    final sourceFile = File(filePath);

    if (!await sourceFile.exists()) {
      throw FileSystemException('Файл Fountain не найден.', filePath);
    }

    final source = await sourceFile.readAsString(encoding: utf8);
    final document = FountainParser.parse(source);
    final suggestedProjectName = path.basenameWithoutExtension(filePath);

    return FountainImportResult(
      document: document,
      sourcePath: sourceFile.path,
      suggestedProjectName: suggestedProjectName.trim().isEmpty
          ? 'Импортированный сценарий'
          : suggestedProjectName,
    );
  }

  Future<String> exportToPath(
    FilmDocument document,
    String filePath,
  ) async {
    final normalizedPath = _ensureFountainExtension(filePath);
    final targetFile = File(normalizedPath);
    final parentDirectory = targetFile.parent;

    if (!await parentDirectory.exists()) {
      await parentDirectory.create(recursive: true);
    }

    final fountainText = FountainParser.exportToFountain(document);

    await targetFile.writeAsString(
      fountainText,
      encoding: utf8,
      flush: true,
    );

    return targetFile.path;
  }

  String _ensureFountainExtension(String filePath) {
    if (filePath.toLowerCase().endsWith('.fountain')) {
      return filePath;
    }

    return '$filePath.fountain';
  }
}
