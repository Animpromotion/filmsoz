import 'dart:io';

import 'package:filmsoz_studio/core/release/error_log_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('error log records and reads application failures', () async {
    final directory = await Directory.systemTemp.createTemp('filmsoz_logs_');
    addTearDown(() => directory.delete(recursive: true));
    final service = FilmsozErrorLogService(rootDirectoryPath: directory.path);

    await service.record(
      'test',
      StateError('Тестовая ошибка'),
      StackTrace.current,
    );
    final entries = await service.readRecent();

    expect(entries, hasLength(1));
    expect(entries.first.category, 'test');
    expect(entries.first.message, contains('Тестовая ошибка'));

    await service.clear();
    expect(await service.readRecent(), isEmpty);
  });
}
