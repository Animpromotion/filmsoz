import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as path;

class PostProductionFileService {
  const PostProductionFileService();

  static const XTypeGroup _csvTypeGroup = XTypeGroup(
    label: 'CSV post-production report',
    extensions: <String>['csv'],
  );

  static const XTypeGroup _pdfTypeGroup = XTypeGroup(
    label: 'PDF post-production report',
    extensions: <String>['pdf'],
  );

  Future<String?> choosePlanCsvPath({required String projectName}) {
    return _chooseSavePath(
      projectName: projectName,
      suffix: 'postproduction_plan',
      extension: 'csv',
      typeGroup: _csvTypeGroup,
    );
  }

  Future<String?> chooseVersionCsvPath({required String projectName}) {
    return _chooseSavePath(
      projectName: projectName,
      suffix: 'edit_versions',
      extension: 'csv',
      typeGroup: _csvTypeGroup,
    );
  }

  Future<String?> chooseReadinessPdfPath({required String projectName}) {
    return _chooseSavePath(
      projectName: projectName,
      suffix: 'postproduction_readiness',
      extension: 'pdf',
      typeGroup: _pdfTypeGroup,
    );
  }

  Future<String> writeCsv(String filePath, String content) async {
    final normalizedPath = _ensureExtension(filePath, 'csv');
    final file = File(normalizedPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(content, encoding: utf8, flush: true);
    return file.path;
  }

  Future<String> writePdf(String filePath, Uint8List bytes) async {
    final normalizedPath = _ensureExtension(filePath, 'pdf');
    final file = File(normalizedPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<String?> _chooseSavePath({
    required String projectName,
    required String suffix,
    required String extension,
    required XTypeGroup typeGroup,
  }) async {
    final location = await getSaveLocation(
      acceptedTypeGroups: <XTypeGroup>[typeGroup],
      suggestedName: '${_cleanFileName(projectName)}_$suffix.$extension',
      confirmButtonText: 'Сохранить',
      canCreateDirectories: true,
    );

    return location == null ? null : _ensureExtension(location.path, extension);
  }

  String _ensureExtension(String filePath, String extension) {
    return filePath.toLowerCase().endsWith('.$extension')
        ? filePath
        : '$filePath.$extension';
  }

  String _cleanFileName(String value) {
    final baseName = path.basenameWithoutExtension(value.trim());
    final resolved = baseName.isEmpty ? 'filmsoz_project' : baseName;
    return resolved.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  }
}
