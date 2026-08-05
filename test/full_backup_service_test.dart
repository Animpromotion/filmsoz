import 'dart:io';

import 'package:filmsoz_studio/core/release/app_settings.dart';
import 'package:filmsoz_studio/core/release/full_backup_service.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('full backup round-trip preserves the Filmsoz document', () async {
    final directory = await Directory.systemTemp.createTemp('filmsoz_full_');
    addTearDown(() => directory.delete(recursive: true));
    final filePath =
        '${directory.path}${Platform.pathSeparator}project.filmsozbackup';
    final document = FilmDocument.empty();
    document.blocks.first.text = 'ИНТ. ТЕСТ - ДЕНЬ';
    const service = FilmsozFullBackupService();

    await service.write(
      filePath: filePath,
      document: document,
      projectName: 'Тестовый фильм',
      settings: const FilmsozAppSettings(autosaveSeconds: 60),
    );
    final restored = await service.read(filePath);

    expect(restored.projectName, 'Тестовый фильм');
    expect(restored.document.blocks.first.text, 'ИНТ. ТЕСТ - ДЕНЬ');
    expect(restored.settings.autosaveSeconds, 60);
  });
}
