import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as path;

class ScreenplayPdfFileService {
  const ScreenplayPdfFileService();

  static const XTypeGroup _pdfTypeGroup = XTypeGroup(
    label: 'PDF document',
    extensions: <String>['pdf'],
  );

  Future<String?> chooseSaveFile({required String suggestedName}) async {
    final cleanName = _cleanFileName(suggestedName);
    final location = await getSaveLocation(
      acceptedTypeGroups: const <XTypeGroup>[_pdfTypeGroup],
      suggestedName: '$cleanName.pdf',
      confirmButtonText: 'Экспортировать',
      canCreateDirectories: true,
    );

    if (location == null) {
      return null;
    }

    return ensurePdfExtension(location.path);
  }

  Future<String> writePdf(String filePath, Uint8List bytes) async {
    final resolvedPath = ensurePdfExtension(filePath);
    final file = File(resolvedPath);

    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return resolvedPath;
  }

  String ensurePdfExtension(String filePath) {
    return filePath.toLowerCase().endsWith('.pdf') ? filePath : '$filePath.pdf';
  }

  String _cleanFileName(String value) {
    final baseName = path.basenameWithoutExtension(value.trim());
    final resolved = baseName.isEmpty ? 'Без названия' : baseName;
    return resolved.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  }
}
