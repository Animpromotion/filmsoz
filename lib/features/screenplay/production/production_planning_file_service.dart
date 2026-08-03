import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as path;

class ProductionPlanningFileService {
  const ProductionPlanningFileService();

  static const XTypeGroup _csvTypeGroup = XTypeGroup(
    label: 'CSV production planning report',
    extensions: <String>['csv'],
  );

  Future<String?> chooseSavePath({
    required String projectName,
    required String suffix,
  }) async {
    final cleanProjectName = projectName.trim().isEmpty
        ? 'filmsoz_project'
        : path.basenameWithoutExtension(projectName.trim());
    final cleanSuffix = suffix.trim().isEmpty ? 'report' : suffix.trim();
    final location = await getSaveLocation(
      acceptedTypeGroups: const <XTypeGroup>[_csvTypeGroup],
      suggestedName: '${cleanProjectName}_$cleanSuffix.csv',
      confirmButtonText: 'Сохранить',
      canCreateDirectories: true,
    );

    if (location == null) {
      return null;
    }

    return _ensureCsvExtension(location.path);
  }

  Future<String> writeCsv(String filePath, String content) async {
    final normalizedPath = _ensureCsvExtension(filePath);
    final file = File(normalizedPath);

    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }

    await file.writeAsString(
      content,
      encoding: utf8,
      flush: true,
    );

    return file.path;
  }

  String _ensureCsvExtension(String filePath) {
    return filePath.toLowerCase().endsWith('.csv') ? filePath : '$filePath.csv';
  }
}
