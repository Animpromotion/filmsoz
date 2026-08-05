import 'dart:io';

import 'package:filmsoz_studio/core/release/app_settings.dart';
import 'package:filmsoz_studio/core/release/app_settings_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('application settings are normalized and persisted', () async {
    final directory =
        await Directory.systemTemp.createTemp('filmsoz_settings_');
    addTearDown(() => directory.delete(recursive: true));
    final service = FilmsozAppSettingsService(
      rootDirectoryPath: directory.path,
    );

    await service.save(
      const FilmsozAppSettings(
        autosaveSeconds: 1,
        projectsDirectory: ' D:/Projects ',
        recoveryEnabled: false,
        compactToolbar: true,
      ),
    );

    final loaded = await service.load();

    expect(loaded.autosaveSeconds, 5);
    expect(loaded.projectsDirectory, 'D:/Projects');
    expect(loaded.recoveryEnabled, isFalse);
    expect(loaded.compactToolbar, isTrue);
  });
}
