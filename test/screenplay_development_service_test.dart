import 'package:filmsoz_studio/features/screenplay/development/scene_development.dart';
import 'package:filmsoz_studio/features/screenplay/development/screenplay_development_service.dart';
import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = ScreenplayDevelopmentService();

  group('ScreenplayDevelopmentService', () {
    test('extracts locations, characters and timing estimates', () {
      final document = _document();
      final firstScene = document.sceneSections.first;

      expect(service.locationForScene(firstScene), 'ДОМ');
      expect(service.charactersForScene(firstScene), <String>['АННА']);
      expect(service.estimatedMinutesForScene(firstScene), greaterThan(0));
      expect(service.estimatedPagesForScene(firstScene), greaterThan(0));
    });

    test('filters scenes by status, color, character and location', () {
      final document = _document();

      expect(
        service
            .filterScenes(
              document,
              status: SceneWorkStatus.ready,
            )
            .map((scene) => scene.id),
        <String>['s2'],
      );
      expect(
        service
            .filterScenes(
              document,
              colorTag: SceneColorTag.red,
            )
            .map((scene) => scene.id),
        <String>['s1'],
      );
      expect(
        service
            .filterScenes(document, character: 'БОРИС')
            .map((scene) => scene.id),
        <String>['s2'],
      );
      expect(
        service
            .filterScenes(document, location: 'ДВОР')
            .map((scene) => scene.id),
        <String>['s2'],
      );
    });

    test('builds character and location reports', () {
      final document = _document();
      final characters = service.characterReport(document);
      final locations = service.locationReport(document);

      expect(characters.map((item) => item.name), <String>['АННА', 'БОРИС']);
      expect(characters.first.dialogueCount, 1);
      expect(locations.map((item) => item.location), <String>['ДВОР', 'ДОМ']);
      expect(locations.fold<int>(0, (sum, item) => sum + item.sceneCount), 2);
    });

    test('exports a semicolon CSV report with Cyrillic data', () {
      final csv = service.buildProductionReportCsv(
        _document(),
        projectName: 'Тестовый фильм',
      );

      expect(csv.startsWith('\uFEFF'), isTrue);
      expect(csv, contains('Тестовый фильм'));
      expect(csv, contains('ИНТ. ДОМ - ДЕНЬ'));
      expect(csv, contains('Переработать'));
      expect(csv, contains('БОРИС'));
      expect(csv, contains('ЛОКАЦИИ'));
    });
  });
}

FilmDocument _document() {
  return FilmDocument(
    blocks: <FilmBlock>[
      _block('s1', BlockType.sceneHeading, 'ИНТ. ДОМ - ДЕНЬ'),
      _block('a1', BlockType.action, 'Анна открывает окно.'),
      _block('c1', BlockType.character, 'АННА'),
      _block('d1', BlockType.dialogue, 'Доброе утро.'),
      _block('s2', BlockType.sceneHeading, 'НАТ. ДВОР - НОЧЬ'),
      _block('a2', BlockType.action, 'Во дворе темно.'),
      _block('c2', BlockType.character, 'БОРИС'),
      _block('d2', BlockType.dialogue, 'Пора идти.'),
    ],
    sceneDevelopment: const <String, SceneDevelopmentData>{
      's1': SceneDevelopmentData(
        summary: 'Анна начинает день.',
        status: SceneWorkStatus.revise,
        colorTag: SceneColorTag.red,
      ),
      's2': SceneDevelopmentData(
        summary: 'Борис ждёт во дворе.',
        status: SceneWorkStatus.ready,
        colorTag: SceneColorTag.blue,
      ),
    },
  );
}

FilmBlock _block(String id, BlockType type, String text) {
  return FilmBlock(id: id, type: type, text: text);
}
