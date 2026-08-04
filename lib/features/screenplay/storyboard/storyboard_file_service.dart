import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as path;

class StoryboardImageData {
  const StoryboardImageData({
    required this.fileName,
    required this.mimeType,
    required this.base64Data,
  });

  final String fileName;
  final String mimeType;
  final String base64Data;

  Uint8List get bytes => base64Decode(base64Data);
}

class StoryboardFileService {
  const StoryboardFileService();

  static const XTypeGroup _imageTypeGroup = XTypeGroup(
    label: 'Storyboard image',
    extensions: <String>['png', 'jpg', 'jpeg'],
  );

  static const XTypeGroup _csvTypeGroup = XTypeGroup(
    label: 'CSV shot list',
    extensions: <String>['csv'],
  );

  static const XTypeGroup _pdfTypeGroup = XTypeGroup(
    label: 'PDF storyboard',
    extensions: <String>['pdf'],
  );

  Future<StoryboardImageData?> chooseImage() async {
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

    const maxBytes = 15 * 1024 * 1024;

    if (bytes.length > maxBytes) {
      throw StateError(
          'Изображение больше 15 МБ. Выберите файл меньшего размера.');
    }

    final extension = path.extension(file.name).toLowerCase();
    final mimeType = switch (extension) {
      '.png' => 'image/png',
      _ => 'image/jpeg',
    };

    return StoryboardImageData(
      fileName: file.name,
      mimeType: mimeType,
      base64Data: base64Encode(bytes),
    );
  }

  Future<String?> chooseCsvSavePath({required String projectName}) async {
    return _chooseSavePath(
      projectName: projectName,
      suffix: 'shot_list',
      extension: 'csv',
      typeGroup: _csvTypeGroup,
    );
  }

  Future<String?> choosePdfSavePath({required String projectName}) async {
    return _chooseSavePath(
      projectName: projectName,
      suffix: 'storyboard',
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
    final cleanProjectName = _cleanFileName(projectName);
    final location = await getSaveLocation(
      acceptedTypeGroups: <XTypeGroup>[typeGroup],
      suggestedName: '${cleanProjectName}_$suffix.$extension',
      confirmButtonText: 'Сохранить',
      canCreateDirectories: true,
    );

    if (location == null) {
      return null;
    }

    return _ensureExtension(location.path, extension);
  }

  String _ensureExtension(String filePath, String extension) {
    final normalizedExtension = '.$extension';
    return filePath.toLowerCase().endsWith(normalizedExtension)
        ? filePath
        : '$filePath$normalizedExtension';
  }

  String _cleanFileName(String value) {
    final baseName = path.basenameWithoutExtension(value.trim());
    final resolved = baseName.isEmpty ? 'filmsoz_project' : baseName;
    return resolved.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  }
}
