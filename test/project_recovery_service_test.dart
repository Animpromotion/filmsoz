import 'dart:convert';
import 'dart:io';

import 'package:filmsoz_studio/core/release/project_recovery_service.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recovery extracts a valid project from surrounding damaged text',
      () async {
    final directory = await Directory.systemTemp.createTemp('filmsoz_recover_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File(
      '${directory.path}${Platform.pathSeparator}damaged.filmsoz',
    );
    final document = FilmDocument.empty();
    document.blocks.first.text = 'ИНТ. ВОССТАНОВЛЕНИЕ - ДЕНЬ';
    final payload = <String, dynamic>{
      'format': 'filmsoz',
      'version': 3,
      'document': document.toJson(),
    };

    await file.writeAsString(
      'damaged prefix\n${jsonEncode(payload)}\ntrailing {broken data',
      encoding: utf8,
    );

    final result = await const FilmsozProjectRecoveryService().recoverFile(
      file.path,
    );

    expect(result.usedTrimmedJson, isTrue);
    expect(
      result.document.blocks.first.text,
      'ИНТ. ВОССТАНОВЛЕНИЕ - ДЕНЬ',
    );
  });
}
