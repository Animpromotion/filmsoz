import 'dart:io';

import 'package:filmsoz_studio/core/release/session_recovery_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session marker detects an unclean previous launch', () async {
    final directory = await Directory.systemTemp.createTemp('filmsoz_session_');
    addTearDown(() => directory.delete(recursive: true));
    final service = FilmsozSessionRecoveryService(
      rootDirectoryPath: directory.path,
    );

    final first = await service.beginSession();
    final second = await service.beginSession();

    expect(first.previousSessionWasUnclean, isFalse);
    expect(second.previousSessionWasUnclean, isTrue);

    await service.markCleanExit();
    final clean = await service.readState();
    expect(clean.previousSessionWasUnclean, isFalse);
  });
}
