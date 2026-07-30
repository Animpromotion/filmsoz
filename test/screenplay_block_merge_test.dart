import 'package:flutter_test/flutter_test.dart';
import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/editor/controller/screenplay_editor_controller.dart';

void main() {
  group('ScreenplayEditorController block merging', () {
    late ScreenplayEditorController controller;

    setUp(() {
      controller = ScreenplayEditorController();
    });

    tearDown(() {
      controller.dispose();
    });

    void loadDocument() {
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
              text: 'Фарход входит. ',
            ),
            FilmBlock(
              id: 'dialogue',
              type: BlockType.dialogue,
              text: 'Здесь тихо.',
            ),
          ],
        ),
        sourceName: 'Merge test',
      );
    }

    test('Backspace boundary merges current block into previous block', () {
      loadDocument();

      final result = controller.mergeBlockWithPrevious('dialogue');

      expect(result, isNotNull);
      expect(result!.blockId, 'action');
      expect(result.cursorOffset, 'Фарход входит. '.length);
      expect(controller.document.blocks, hasLength(2));
      expect(
        controller.document.blocks.last.text,
        'Фарход входит. Здесь тихо.',
      );
      expect(controller.document.blocks.last.type, BlockType.action);
    });

    test('Delete boundary merges next block into current block', () {
      loadDocument();

      final result = controller.mergeBlockWithNext('action');

      expect(result, isNotNull);
      expect(result!.blockId, 'action');
      expect(result.cursorOffset, 'Фарход входит. '.length);
      expect(controller.document.blocks, hasLength(2));
      expect(
        controller.document.blocks.last.text,
        'Фарход входит. Здесь тихо.',
      );
      expect(controller.document.blocks.last.type, BlockType.action);
    });

    test('A merge is restored by Undo and repeated by Redo', () {
      loadDocument();

      controller.mergeBlockWithPrevious('dialogue');
      expect(controller.document.blocks, hasLength(2));

      expect(controller.undo(), isTrue);
      expect(controller.document.blocks, hasLength(3));
      expect(controller.document.blocks[1].text, 'Фарход входит. ');
      expect(controller.document.blocks[2].text, 'Здесь тихо.');

      expect(controller.redo(), isTrue);
      expect(controller.document.blocks, hasLength(2));
      expect(
        controller.document.blocks.last.text,
        'Фарход входит. Здесь тихо.',
      );
    });

    test('Document boundaries do not merge outside the document', () {
      loadDocument();

      expect(controller.mergeBlockWithPrevious('scene'), isNull);
      expect(controller.mergeBlockWithNext('dialogue'), isNull);
      expect(controller.document.blocks, hasLength(3));
      expect(controller.canUndo, isFalse);
    });
  });
}
