import 'dart:io';
import 'dart:typed_data';

import 'package:filmsoz_studio/features/screenplay/pdf/screenplay_pdf_file_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  group('ScreenplayPdfFileService', () {
    const service = ScreenplayPdfFileService();
    late Directory tempDirectory;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp('filmsoz_pdf_');
    });

    tearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('adds extension and writes bytes', () async {
      final requestedPath = path.join(tempDirectory.path, 'screenplay');
      final savedPath = await service.writePdf(
        requestedPath,
        Uint8List.fromList(<int>[37, 80, 68, 70, 45]),
      );

      expect(savedPath, endsWith('.pdf'));
      expect(await File(savedPath).readAsBytes(), <int>[37, 80, 68, 70, 45]);
    });
  });
}
