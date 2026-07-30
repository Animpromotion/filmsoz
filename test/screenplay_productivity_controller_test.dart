import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/editor/controller/screenplay_editor_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScreenplayEditorController productivity tools', () {
    late ScreenplayEditorController controller;

    setUp(() {
      controller = ScreenplayEditorController();
      controller.replaceWithImportedDocument(
        FilmDocument(
          blocks: <FilmBlock>[
            _block('s1', BlockType.sceneHeading, 'ИНТ. ДОМ - ДЕНЬ'),
            _block('a1', BlockType.action, 'Дом пуст. Дом закрыт.'),
            _block('s2', BlockType.sceneHeading, 'НАТ. ДВОР - ДЕНЬ'),
            _block('a2', BlockType.action, 'У дома стоит машина.'),
          ],
        ),
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('stores scene notes in JSON and supports undo and redo', () {
      expect(controller.setSceneNote('s1', 'Нужен красный реквизит.'), isTrue);
      expect(
        controller.document.sceneNote('s1'),
        'Нужен красный реквизит.',
      );

      final restored = FilmDocument.fromJson(controller.document.toJson());
      expect(restored.sceneNote('s1'), 'Нужен красный реквизит.');

      expect(controller.undo(), isTrue);
      expect(controller.document.sceneNote('s1'), isEmpty);
      expect(controller.redo(), isTrue);
      expect(
        controller.document.sceneNote('s1'),
        'Нужен красный реквизит.',
      );
    });

    test('copies a scene note when duplicating a scene', () {
      controller.setSceneNote('s1', 'Проверить свет.');
      final result = controller.duplicateScene('s1');

      expect(result, isNotNull);
      expect(
        controller.document.sceneNote(result!.sceneId),
        'Проверить свет.',
      );
    });

    test('removes a scene note together with a scene', () {
      controller.setSceneNote('s1', 'Удаляемая заметка.');
      controller.deleteScene('s1');

      expect(controller.document.sceneNotes.containsKey('s1'), isFalse);
      expect(controller.undo(), isTrue);
      expect(controller.document.sceneNote('s1'), 'Удаляемая заметка.');
    });

    test('replaces all text as one undoable operation', () {
      final replaced = controller.replaceAllText('дом', 'офис');

      expect(replaced, 4);
      expect(controller.document.blocks[0].text, 'ИНТ. офис - ДЕНЬ');
      expect(controller.document.blocks[1].text, 'офис пуст. офис закрыт.');
      expect(controller.document.blocks[3].text, 'У офиса стоит машина.');

      expect(controller.undo(), isTrue);
      expect(controller.document.blocks[0].text, 'ИНТ. ДОМ - ДЕНЬ');
      expect(controller.redo(), isTrue);
      expect(controller.document.blocks[0].text, 'ИНТ. офис - ДЕНЬ');
    });
  });
}

FilmBlock _block(String id, BlockType type, String text) {
  return FilmBlock(id: id, type: type, text: text);
}
