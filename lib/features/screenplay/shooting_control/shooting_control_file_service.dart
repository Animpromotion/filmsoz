import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as path;

class ContinuityPhotoData {
  const ContinuityPhotoData({
    required this.fileName,
    required this.mimeType,
    required this.base64Data,
  });

  final String fileName;
  final String mimeType;
  final String base64Data;
}

class ShootingControlFileService {
  const ShootingControlFileService();

  static const XTypeGroup _imageTypeGroup = XTypeGroup(
    label: 'Continuity photo',
    extensions: <String>['png', 'jpg', 'jpeg'],
  );

  static const XTypeGroup _csvTypeGroup = XTypeGroup(
    label: 'CSV report',
    extensions: <String>['csv'],
  );

  static const XTypeGroup _pdfTypeGroup = XTypeGroup(
    label: 'PDF report',
    extensions: <String>['pdf'],
  );

  Future<ContinuityPhotoData?> chooseContinuityPhoto() async {
    final file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[_imageTypeGroup],
      confirmButtonText: 'Добавить',
    );

    if (file == null) {
      return null;
    }

    final bytes = await file.readAsBytes();

    if (bytes.isEmpty) {
      throw StateError('Выбранное изображение пустое.');
    }

    const maxBytes = 10 * 1024 * 1024;

    if (bytes.length > maxBytes) {
      throw StateError(
          'Фотография больше 10 МБ. Выберите файл меньшего размера.');
    }

    final extension = path.extension(file.name).toLowerCase();
    final mimeType = extension == '.png' ? 'image/png' : 'image/jpeg';

    return ContinuityPhotoData(
      fileName: file.name,
      mimeType: mimeType,
      base64Data: base64Encode(bytes),
    );
  }

  Future<String?> chooseEditingLogCsvPath({required String projectName}) {
    return _chooseSavePath(
      projectName: projectName,
      suffix: 'editing_log',
      extension: 'csv',
      typeGroup: _csvTypeGroup,
    );
  }

  Future<String?> chooseJournalCsvPath({required String projectName}) {
    return _chooseSavePath(
      projectName: projectName,
      suffix: 'shooting_journal',
      extension: 'csv',
      typeGroup: _csvTypeGroup,
    );
  }

  Future<String?> choosePdfPath({required String projectName}) {
    return _chooseSavePath(
      projectName: projectName,
      suffix: 'shooting_report',
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
