import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as path;

class ProductionReportFileService {
  const ProductionReportFileService();

  static const XTypeGroup _csvTypeGroup = XTypeGroup(
    label: 'CSV production report',
    extensions: <String>['csv'],
  );

  Future<String?> chooseSavePath({required String suggestedName}) async {
    final cleanName = suggestedName.trim().isEmpty
        ? 'production_report'
        : path.basenameWithoutExtension(suggestedName.trim());

    final location = await getSaveLocation(
      acceptedTypeGroups: const <XTypeGroup>[_csvTypeGroup],
      suggestedName: '${cleanName}_production_report.csv',
      confirmButtonText: 'Экспортировать',
      canCreateDirectories: true,
    );

    if (location == null) {
      return null;
    }

    return _ensureCsvExtension(location.path);
  }

  Future<String> writeReport(String filePath, String csvText) async {
    final normalizedPath = _ensureCsvExtension(filePath);
    final targetFile = File(normalizedPath);

    if (!await targetFile.parent.exists()) {
      await targetFile.parent.create(recursive: true);
    }

    await targetFile.writeAsString(
      csvText,
      encoding: utf8,
      flush: true,
    );

    return targetFile.path;
  }

  String _ensureCsvExtension(String filePath) {
    return filePath.toLowerCase().endsWith('.csv') ? filePath : '$filePath.csv';
  }
}
