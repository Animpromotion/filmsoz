import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/editor/controller/screenplay_editor_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScreenplayEditorController batch block editing', () {
    late ScreenplayEditorController controller;

    setUp(() {
      controller = ScreenplayEditorController();
      controller.replaceWithImportedDocument(
        FilmDocument(
          blocks: <FilmBlock>[
            FilmBlock(
              id: 'scene',
              type: BlockType.sceneHeading,
              text: 'ИНТ. КОМНАТА — НОЧЬ',
            ),
            FilmBlock(
              id: 'action',
              type: BlockType.action,
              text: 'Фарход входит.',
            ),
            FilmBlock(
              id: 'character',
              type: BlockType.character,
              text: 'ФАРХОД',
            ),
            FilmBlock(
              id: 'dialogue',
              type: BlockType.dialogue,
              text: 'Здесь тихо.',
            ),
          ],
        ),
        sourceName: 'Batch edit test',
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('copyBlocksByIds preserves document order and returns detached copies',
        () {
      final copied = controller.copyBlocksByIds(
        <String>{'dialogue', 'action'},
      );

      expect(copied.map((block) => block.id), <String>['action', 'dialogue']);
      expect(
        copied.map((block) => block.type),
        <BlockType>[BlockType.action, BlockType.dialogue],
      );

      copied.first.text = 'Изменённая копия';

      expect(controller.document.blocks[1].text, 'Фарход входит.');
    });

    test('deleteBlocks removes the selected group in one undo operation', () {
      final result = controller.deleteBlocks(
        <String>{'action', 'character'},
      );

      expect(result, isNotNull);
      expect(result!.focusBlockId, 'dialogue');
      expect(
        controller.document.blocks.map((block) => block.id),
        <String>['scene', 'dialogue'],
      );

      expect(controller.undo(), isTrue);
      expect(
        controller.document.blocks.map((block) => block.id),
        <String>['scene', 'action', 'character', 'dialogue'],
      );

      expect(controller.redo(), isTrue);
      expect(
        controller.document.blocks.map((block) => block.id),
        <String>['scene', 'dialogue'],
      );
    });

    test('deleting every block leaves one editable action block', () {
      final result = controller.deleteBlocks(
        controller.document.blocks.map((block) => block.id),
      );

      expect(result, isNotNull);
      expect(controller.document.blocks, hasLength(1));
      expect(controller.document.blocks.single.type, BlockType.action);
      expect(controller.document.blocks.single.text, isEmpty);

      expect(controller.undo(), isTrue);
      expect(controller.document.blocks, hasLength(4));
    });

    test('insertBlocksAfter creates new ids and supports undo and redo', () {
      final copied = controller.copyBlocksByIds(
        <String>{'character', 'dialogue'},
      );
      final originalIds = copied.map((block) => block.id).toSet();

      final result = controller.insertBlocksAfter(
        afterBlockId: 'action',
        blocks: copied,
      );

      expect(result, isNotNull);
      expect(result!.insertedBlockIds, hasLength(2));
      expect(
        result.insertedBlockIds.any(originalIds.contains),
        isFalse,
      );
      expect(
        controller.document.blocks.map((block) => block.type),
        <BlockType>[
          BlockType.sceneHeading,
          BlockType.action,
          BlockType.character,
          BlockType.dialogue,
          BlockType.character,
          BlockType.dialogue,
        ],
      );
      expect(controller.document.blocks[2].text, 'ФАРХОД');
      expect(controller.document.blocks[3].text, 'Здесь тихо.');

      expect(controller.undo(), isTrue);
      expect(controller.document.blocks, hasLength(4));

      expect(controller.redo(), isTrue);
      expect(controller.document.blocks, hasLength(6));
    });
  });
}
