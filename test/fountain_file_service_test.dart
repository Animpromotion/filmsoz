import 'dart:convert';
import 'dart:io';

import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/storage/fountain_file_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  group('FountainFileService', () {
    const service = FountainFileService();
    late Directory tempDirectory;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'filmsoz_fountain_test_',
      );
    });

    tearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('imports UTF-8 Fountain with Cyrillic text', () async {
      final sourcePath = path.join(tempDirectory.path, 'Тест.fountain');
      final sourceFile = File(sourcePath);

      await sourceFile.writeAsString(
        'ИНТ. КОМНАТА — НОЧЬ\n\n'
        'На столе лежит сценарий.\n\n'
        'ФАРХОД\n'
        '(тихо)\n'
        'Продолжаем работу.\n',
        encoding: utf8,
        flush: true,
      );

      final result = await service.importFromPath(sourcePath);

      expect(result.suggestedProjectName, 'Тест');
      expect(
        result.document.blocks.map((block) => block.type),
        <BlockType>[
          BlockType.sceneHeading,
          BlockType.action,
          BlockType.character,
          BlockType.parenthetical,
          BlockType.dialogue,
        ],
      );
      expect(
        result.document.blocks.last.text,
        'Продолжаем работу.',
      );
    });

    test('exports UTF-8 Fountain and adds the extension', () async {
      final document = FilmDocument(
        blocks: <FilmBlock>[
          FilmBlock(
            id: 'scene-1',
            type: BlockType.sceneHeading,
            text: 'НАТ. УЛИЦА — ВЕЧЕР',
          ),
          FilmBlock(
            id: 'action-1',
            type: BlockType.action,
            text: 'Город постепенно зажигает огни.',
          ),
          FilmBlock(
            id: 'character-1',
            type: BlockType.character,
            text: 'ФАРХОД',
          ),
          FilmBlock(
            id: 'dialogue-1',
            type: BlockType.dialogue,
            text: 'Пора возвращаться.',
          ),
        ],
      );

      final requestedPath = path.join(tempDirectory.path, 'Экспорт');
      final exportedPath = await service.exportToPath(
        document,
        requestedPath,
      );

      expect(exportedPath, endsWith('.fountain'));

      final exportedBytes = await File(exportedPath).readAsBytes();
      final exportedText = utf8.decode(exportedBytes);

      expect(exportedText, contains('НАТ. УЛИЦА — ВЕЧЕР'));
      expect(exportedText, contains('Город постепенно зажигает огни.'));
      expect(exportedText, contains('ФАРХОД'));
      expect(exportedText, contains('Пора возвращаться.'));
      expect(exportedBytes.take(3).toList(), isNot(<int>[0xEF, 0xBB, 0xBF]));
    });
  });
}
