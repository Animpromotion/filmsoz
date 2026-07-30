import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/parser/fountain_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FountainParser.parse', () {
    test('parses Russian screenplay elements', () {
      const source = '''
ИНТ. КОМНАТА — НОЧЬ

На столе лежит сценарий.

ФАРХОД
(тихо)
Мы начинаем.

>СКЛЕЙКА:
''';

      final document = FountainParser.parse(source);

      expect(
        document.blocks.map((block) => block.type),
        <BlockType>[
          BlockType.sceneHeading,
          BlockType.action,
          BlockType.character,
          BlockType.parenthetical,
          BlockType.dialogue,
          BlockType.transition,
        ],
      );
      expect(document.blocks[0].text, 'ИНТ. КОМНАТА — НОЧЬ');
      expect(document.blocks[3].text, '(тихо)');
      expect(document.blocks[4].text, 'Мы начинаем.');
      expect(document.blocks[5].text, 'СКЛЕЙКА:');
    });

    test('recognizes Cyrillic and Latin scene heading prefixes', () {
      const headings = <String>[
        'ИНТ. КОМНАТА — ДЕНЬ',
        'НАТ. УЛИЦА — НОЧЬ',
        'ЭКСТ. ДВОР — УТРО',
        'INT. ROOM - DAY',
        'EXT. STREET - NIGHT',
        'INT./EXT. CAR - DAY',
        'ИНТ./НАТ. МАШИНА — ДЕНЬ',
      ];

      for (final heading in headings) {
        final document = FountainParser.parse('$heading\n');

        expect(
          document.blocks.single.type,
          BlockType.sceneHeading,
          reason: 'Expected scene heading: $heading',
        );
      }
    });

    test('supports forced Fountain elements and multiline dialogue', () {
      const source = '''
.Необычная сцена

!ЭТО ДЕЙСТВИЕ, А НЕ ПЕРСОНАЖ

@Фарход
Первая строка.
Вторая строка.
''';

      final document = FountainParser.parse(source);

      expect(document.blocks[0].type, BlockType.sceneHeading);
      expect(document.blocks[0].text, 'НЕОБЫЧНАЯ СЦЕНА');
      expect(document.blocks[1].type, BlockType.action);
      expect(document.blocks[1].text, 'ЭТО ДЕЙСТВИЕ, А НЕ ПЕРСОНАЖ');
      expect(document.blocks[2].type, BlockType.character);
      expect(document.blocks[2].text, 'Фарход');
      expect(document.blocks[3].type, BlockType.dialogue);
      expect(document.blocks[3].text, 'Первая строка.\nВторая строка.');
    });
  });

  group('FountainParser.exportToFountain', () {
    test('exports and imports current Filmsoz block types', () {
      final document = FilmDocument(
        blocks: <FilmBlock>[
          FilmBlock(
            id: '1',
            type: BlockType.sceneHeading,
            text: 'ИНТ. СТУДИЯ — ДЕНЬ',
          ),
          FilmBlock(
            id: '2',
            type: BlockType.action,
            text: 'Фарход открывает ноутбук.',
          ),
          FilmBlock(
            id: '3',
            type: BlockType.character,
            text: 'ФАРХОД',
          ),
          FilmBlock(
            id: '4',
            type: BlockType.parenthetical,
            text: '(улыбаясь)',
          ),
          FilmBlock(
            id: '5',
            type: BlockType.dialogue,
            text: 'Filmsoz готов к работе.',
          ),
          FilmBlock(
            id: '6',
            type: BlockType.transition,
            text: 'СКЛЕЙКА:',
          ),
        ],
      );

      final fountain = FountainParser.exportToFountain(document);
      final restored = FountainParser.parse(fountain);

      expect(fountain, contains('ИНТ. СТУДИЯ — ДЕНЬ'));
      expect(fountain, contains('ФАРХОД'));
      expect(fountain, contains('(улыбаясь)'));
      expect(fountain, contains('>СКЛЕЙКА:'));
      expect(
        restored.blocks.map((block) => block.type),
        document.blocks.map((block) => block.type),
      );
      expect(
        restored.blocks.map((block) => block.text),
        document.blocks.map((block) => block.text),
      );
    });

    test('forces uppercase action so it remains action after round trip', () {
      final document = FilmDocument(
        blocks: <FilmBlock>[
          FilmBlock(
            id: '1',
            type: BlockType.action,
            text: 'ЭТО ВАЖНОЕ ДЕЙСТВИЕ',
          ),
        ],
      );

      final fountain = FountainParser.exportToFountain(document);
      final restored = FountainParser.parse(fountain);

      expect(fountain, startsWith('!ЭТО ВАЖНОЕ ДЕЙСТВИЕ'));
      expect(restored.blocks.single.type, BlockType.action);
      expect(restored.blocks.single.text, 'ЭТО ВАЖНОЕ ДЕЙСТВИЕ');
    });
  });
}
