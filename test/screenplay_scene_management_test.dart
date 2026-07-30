import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/editor/controller/screenplay_editor_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FilmDocument scene sections', () {
    test('numbers scenes and calculates searchable statistics', () {
      final document = FilmDocument(
        blocks: <FilmBlock>[
          _block('s1', BlockType.sceneHeading, 'ИНТ. ДОМ - ДЕНЬ'),
          _block('a1', BlockType.action, 'Мама входит.'),
          _block('c1', BlockType.character, 'АННА'),
          _block('d1', BlockType.dialogue, 'Привет, мир.'),
          _block('s2', BlockType.sceneHeading, 'НАТ. ДВОР - ВЕЧЕР'),
          _block('a2', BlockType.action, 'У ворот стоит машина.'),
        ],
      );

      final scenes = document.sceneSections;

      expect(scenes, hasLength(2));
      expect(scenes.first.number, 1);
      expect(scenes.first.id, 's1');
      expect(scenes.first.blockCount, 4);
      expect(scenes.first.contentBlockCount, 3);
      expect(scenes.first.wordCount, 9);
      expect(
        scenes.first.characterCount,
        'ИНТ. ДОМ - ДЕНЬ'.length +
            'Мама входит.'.length +
            'АННА'.length +
            'Привет, мир.'.length,
      );
      expect(scenes.first.matchesQuery('1'), isTrue);
      expect(scenes.first.matchesQuery('дом'), isTrue);
      expect(scenes.first.matchesQuery('привет'), isTrue);
      expect(scenes.first.matchesQuery('машина'), isFalse);
      expect(scenes.last.number, 2);
    });
  });

  group('ScreenplayEditorController scene management', () {
    late ScreenplayEditorController controller;

    setUp(() {
      controller = ScreenplayEditorController();
      controller.replaceWithImportedDocument(
        _threeSceneDocument(),
        sourceName: 'Scene management test',
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('moves a complete scene and supports undo and redo', () {
      final result = controller.moveSceneByOffset(
        sceneId: 's2',
        offset: -1,
      );

      expect(result, isNotNull);
      expect(result!.sceneId, 's2');
      expect(result.sceneNumber, 1);
      expect(
        _ids(controller),
        const <String>['p', 's2', 'a2', 's1', 'a1', 's3', 'a3'],
      );

      expect(controller.undo(), isTrue);
      expect(
        _ids(controller),
        const <String>['p', 's1', 'a1', 's2', 'a2', 's3', 'a3'],
      );

      expect(controller.redo(), isTrue);
      expect(
        _ids(controller),
        const <String>['p', 's2', 'a2', 's1', 'a1', 's3', 'a3'],
      );
    });

    test('protects scene headings from ordinary block movement', () {
      final result = controller.moveBlocksByOffset(
        blockIds: const <String>['s2'],
        offset: -1,
      );

      expect(result, isNull);
      expect(
        _ids(controller),
        const <String>['p', 's1', 'a1', 's2', 'a2', 's3', 'a3'],
      );
    });

    test('moves a scene relative to a navigator drop target', () {
      final result = controller.moveSceneRelativeToTarget(
        sceneId: 's1',
        targetSceneId: 's3',
        placeAfter: true,
      );

      expect(result, isNotNull);
      expect(result!.sceneNumber, 3);
      expect(
        _ids(controller),
        const <String>['p', 's2', 'a2', 's3', 'a3', 's1', 'a1'],
      );

      expect(
        controller.moveSceneRelativeToTarget(
          sceneId: 's1',
          targetSceneId: 's3',
          placeAfter: true,
        ),
        isNull,
      );
    });

    test('duplicates the whole scene with new block identifiers', () {
      final source = controller.document.sceneById('s2')!;
      final result = controller.duplicateScene('s2');

      expect(result, isNotNull);
      expect(result!.sceneNumber, 3);
      expect(result.sceneId, isNot('s2'));

      final duplicate = controller.document.sceneById(result.sceneId)!;
      expect(
        duplicate.blocks.map((block) => block.type),
        source.blocks.map((block) => block.type),
      );
      expect(
        duplicate.blocks.map((block) => block.text),
        source.blocks.map((block) => block.text),
      );
      expect(
        duplicate.blockIds.toSet().intersection(source.blockIds.toSet()),
        isEmpty,
      );

      expect(controller.undo(), isTrue);
      expect(controller.document.sceneSections, hasLength(3));
    });

    test('deletes the whole scene and restores it through undo', () {
      final result = controller.deleteScene('s2');

      expect(result, isNotNull);
      expect(result!.activeSceneId, 's3');
      expect(result.focusBlockId, 's3');
      expect(controller.document.sceneSections, hasLength(2));
      expect(
        _ids(controller),
        const <String>['p', 's1', 'a1', 's3', 'a3'],
      );

      expect(controller.undo(), isTrue);
      expect(
        _ids(controller),
        const <String>['p', 's1', 'a1', 's2', 'a2', 's3', 'a3'],
      );
    });

    test('keeps one editable scene after deleting the only scene', () {
      controller.replaceWithImportedDocument(
        FilmDocument(
          blocks: <FilmBlock>[
            _block('s1', BlockType.sceneHeading, 'ИНТ. ДОМ - ДЕНЬ'),
            _block('a1', BlockType.action, 'Тишина.'),
          ],
        ),
      );

      final result = controller.deleteScene('s1');

      expect(result, isNotNull);
      expect(controller.document.sceneSections, hasLength(1));
      expect(
        controller.document.sceneSections.first.heading.text,
        'ИНТ. НОВАЯ СЦЕНА - ДЕНЬ',
      );
      expect(controller.undo(), isTrue);
      expect(controller.document.sceneSections.first.id, 's1');
    });
  });
}

FilmDocument _threeSceneDocument() {
  return FilmDocument(
    blocks: <FilmBlock>[
      _block('p', BlockType.action, 'Преамбула'),
      _block('s1', BlockType.sceneHeading, 'ИНТ. ДОМ - ДЕНЬ'),
      _block('a1', BlockType.action, 'Первая сцена'),
      _block('s2', BlockType.sceneHeading, 'НАТ. ДВОР - ДЕНЬ'),
      _block('a2', BlockType.action, 'Вторая сцена'),
      _block('s3', BlockType.sceneHeading, 'ИНТ. МАШИНА - НОЧЬ'),
      _block('a3', BlockType.action, 'Третья сцена'),
    ],
  );
}

FilmBlock _block(String id, BlockType type, String text) {
  return FilmBlock(id: id, type: type, text: text);
}

List<String> _ids(ScreenplayEditorController controller) {
  return controller.document.blocks
      .map((block) => block.id)
      .toList(growable: false);
}
