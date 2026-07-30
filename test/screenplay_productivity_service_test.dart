import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/productivity/screenplay_productivity_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = ScreenplayProductivityService();

  group('ScreenplayProductivityService', () {
    test('builds character statistics and suggestions', () {
      final document = FilmDocument(
        blocks: <FilmBlock>[
          _block('s1', BlockType.sceneHeading, 'ИНТ. ДОМ - ДЕНЬ'),
          _block('c1', BlockType.character, 'ФАРХОД'),
          _block('d1', BlockType.dialogue, 'Мы начинаем новый фильм.'),
          _block('c2', BlockType.character, 'АННА'),
          _block('p1', BlockType.parenthetical, '(тихо)'),
          _block('d2', BlockType.dialogue, 'Я готова.'),
          _block('c3', BlockType.character, 'ФАРХОД (ЗК)'),
          _block('d3', BlockType.dialogue, 'Тогда поехали.'),
        ],
      );

      final statistics = service.characterStatistics(document);

      expect(statistics, hasLength(2));
      expect(statistics.first.name, 'ФАРХОД');
      expect(statistics.first.characterBlocks, 2);
      expect(statistics.first.dialogueBlocks, 2);
      expect(statistics.first.dialogueWords, 6);
      expect(statistics.last.name, 'АННА');
      expect(statistics.last.dialogueBlocks, 1);
      expect(
        service.characterSuggestions(document, query: 'ФА'),
        contains('ФАРХОД'),
      );
    });

    test('extracts locations and applies a location suggestion', () {
      final document = FilmDocument(
        blocks: <FilmBlock>[
          _block('s1', BlockType.sceneHeading, 'ИНТ. ДОМ - ДЕНЬ'),
          _block('s2', BlockType.sceneHeading, 'НАТ. ДВОР — ВЕЧЕР'),
          _block('s3', BlockType.sceneHeading, 'ИНТ. ДОМ - НОЧЬ'),
        ],
      );

      expect(service.extractLocation('INT./EXT. CAR - DAY'), 'CAR');
      expect(
        service.locationSuggestions(document),
        const <String>['ДОМ', 'ДВОР'],
      );
      expect(
        service.applyLocationSuggestion(
          'НАТ. СТАРЫЙ ДВОР — ВЕЧЕР',
          'ПЛОЩАДЬ',
        ),
        'НАТ. ПЛОЩАДЬ — ВЕЧЕР',
      );
    });

    test('counts text matches without treating query as a regexp', () {
      final document = FilmDocument(
        blocks: <FilmBlock>[
          _block('a1', BlockType.action, 'Дом. Большой дом.'),
          _block('a2', BlockType.action, 'ДОМ у реки.'),
        ],
      );

      expect(service.countMatches(document, 'дом'), 3);
      expect(service.countMatches(document, 'дом', matchCase: true), 1);
      expect(service.countMatches(document, '.'), 3);
    });
  });
}

FilmBlock _block(String id, BlockType type, String text) {
  return FilmBlock(id: id, type: type, text: text);
}
