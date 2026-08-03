import 'package:filmsoz_studio/features/screenplay/development/scene_development.dart';
import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/editor/controller/screenplay_editor_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScreenplayEditorController development metadata', () {
    late ScreenplayEditorController controller;

    setUp(() {
      controller = ScreenplayEditorController();
      controller.replaceWithImportedDocument(
        FilmDocument(
          blocks: <FilmBlock>[
            _block('s1', BlockType.sceneHeading, 'ИНТ. ДОМ - ДЕНЬ'),
            _block('a1', BlockType.action, 'Первая сцена.'),
            _block('s2', BlockType.sceneHeading, 'НАТ. ДВОР - НОЧЬ'),
            _block('a2', BlockType.action, 'Вторая сцена.'),
          ],
        ),
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('stores card data and restores it through undo and redo', () {
      expect(
        controller.setSceneDevelopment(
          's1',
          summary: 'Важная завязка.',
          status: SceneWorkStatus.inProgress,
          colorTag: SceneColorTag.orange,
        ),
        isTrue,
      );

      final data = controller.document.sceneDevelopmentFor('s1');
      expect(data.summary, 'Важная завязка.');
      expect(data.status, SceneWorkStatus.inProgress);
      expect(data.colorTag, SceneColorTag.orange);

      expect(controller.undo(), isTrue);
      expect(controller.document.sceneDevelopmentFor('s1').isDefault, isTrue);
      expect(controller.redo(), isTrue);
      expect(
        controller.document.sceneDevelopmentFor('s1').summary,
        'Важная завязка.',
      );
    });

    test('stores screenplay goals in the project JSON', () {
      controller.setScreenplayGoals(
        const ScreenplayGoals(
          targetSceneCount: 50,
          targetPageCount: 90,
          targetMinutes: 100,
        ),
      );

      final restored = FilmDocument.fromJson(controller.document.toJson());

      expect(restored.goals.targetSceneCount, 50);
      expect(restored.goals.targetPageCount, 90);
      expect(restored.goals.targetMinutes, 100);
      expect(controller.undo(), isTrue);
      expect(controller.document.goals.isEmpty, isTrue);
    });

    test('duplicates development metadata together with the scene', () {
      controller.setSceneDevelopment(
        's1',
        summary: 'Копируемая карточка.',
        status: SceneWorkStatus.ready,
        colorTag: SceneColorTag.green,
      );

      final result = controller.duplicateScene('s1');
      final duplicated =
          controller.document.sceneDevelopmentFor(result!.sceneId);

      expect(duplicated.summary, 'Копируемая карточка.');
      expect(duplicated.status, SceneWorkStatus.ready);
      expect(duplicated.colorTag, SceneColorTag.green);
    });

    test('removes scene metadata with the deleted scene', () {
      controller.setSceneDevelopment(
        's1',
        summary: 'Удаляемая карточка.',
        status: SceneWorkStatus.revise,
        colorTag: SceneColorTag.purple,
      );

      controller.deleteScene('s1');

      expect(controller.document.sceneDevelopment.containsKey('s1'), isFalse);
      expect(controller.undo(), isTrue);
      expect(
        controller.document.sceneDevelopmentFor('s1').summary,
        'Удаляемая карточка.',
      );
    });

    test('loads old project JSON without development fields', () {
      final restored = FilmDocument.fromJson(<String, dynamic>{
        'blocks': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 's1',
            'type': 'sceneHeading',
            'text': 'ИНТ. ДОМ - ДЕНЬ',
          },
        ],
      });

      expect(restored.sceneDevelopment, isEmpty);
      expect(restored.goals.isEmpty, isTrue);
    });
  });
}

FilmBlock _block(String id, BlockType type, String text) {
  return FilmBlock(id: id, type: type, text: text);
}
