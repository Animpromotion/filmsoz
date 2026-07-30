import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/editor/controller/screenplay_editor_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScreenplayEditorController block movement', () {
    late ScreenplayEditorController controller;

    setUp(() {
      controller = ScreenplayEditorController();
      controller.replaceWithImportedDocument(
        FilmDocument(
          blocks: <FilmBlock>[
            FilmBlock(id: 'a', type: BlockType.action, text: 'A'),
            FilmBlock(id: 'b', type: BlockType.action, text: 'B'),
            FilmBlock(id: 'c', type: BlockType.action, text: 'C'),
            FilmBlock(id: 'd', type: BlockType.action, text: 'D'),
            FilmBlock(id: 'e', type: BlockType.action, text: 'E'),
          ],
        ),
        sourceName: 'Movement test',
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('moves one block up and restores the order through undo and redo', () {
      final result = controller.moveBlocksByOffset(
        blockIds: const <String>['c'],
        offset: -1,
        focusBlockId: 'c',
      );

      expect(result, isNotNull);
      expect(result!.movedBlockIds, const <String>['c']);
      expect(result.focusBlockId, 'c');
      expect(result.firstIndex, 1);
      expect(_ids(controller), const <String>['a', 'c', 'b', 'd', 'e']);

      expect(controller.undo(), isTrue);
      expect(_ids(controller), const <String>['a', 'b', 'c', 'd', 'e']);

      expect(controller.redo(), isTrue);
      expect(_ids(controller), const <String>['a', 'c', 'b', 'd', 'e']);
    });

    test('moves a selected group down while preserving its relative order', () {
      final result = controller.moveBlocksByOffset(
        blockIds: const <String>['b', 'c'],
        offset: 1,
        focusBlockId: 'b',
      );

      expect(result, isNotNull);
      expect(result!.movedBlockIds, const <String>['b', 'c']);
      expect(_ids(controller), const <String>['a', 'd', 'b', 'c', 'e']);

      controller.moveBlocksByOffset(
        blockIds: const <String>['b', 'c'],
        offset: 1,
      );

      expect(_ids(controller), const <String>['a', 'd', 'e', 'b', 'c']);
      expect(
        controller.moveBlocksByOffset(
          blockIds: const <String>['b', 'c'],
          offset: 1,
        ),
        isNull,
      );
    });

    test('moves non-contiguous selected blocks one position as a stable set',
        () {
      final result = controller.moveBlocksByOffset(
        blockIds: const <String>['b', 'd'],
        offset: -1,
      );

      expect(result, isNotNull);
      expect(result!.movedBlockIds, const <String>['b', 'd']);
      expect(_ids(controller), const <String>['b', 'a', 'd', 'c', 'e']);
    });

    test('moves blocks before or after a drag target without changing ids', () {
      final afterResult = controller.moveBlocksRelativeToTarget(
        blockIds: const <String>['b', 'c'],
        targetBlockId: 'e',
        placeAfter: true,
        focusBlockId: 'b',
      );

      expect(afterResult, isNotNull);
      expect(_ids(controller), const <String>['a', 'd', 'e', 'b', 'c']);
      expect(
        controller.document.blocks.map((block) => block.id).toSet(),
        const <String>{'a', 'b', 'c', 'd', 'e'},
      );

      expect(controller.undo(), isTrue);
      expect(_ids(controller), const <String>['a', 'b', 'c', 'd', 'e']);

      final beforeResult = controller.moveBlocksRelativeToTarget(
        blockIds: const <String>['d'],
        targetBlockId: 'b',
        placeAfter: false,
      );

      expect(beforeResult, isNotNull);
      expect(_ids(controller), const <String>['a', 'd', 'b', 'c', 'e']);
      expect(
        controller.moveBlocksRelativeToTarget(
          blockIds: const <String>['b', 'c'],
          targetBlockId: 'b',
          placeAfter: false,
        ),
        isNull,
      );
    });
  });
}

List<String> _ids(ScreenplayEditorController controller) {
  return controller.document.blocks
      .map((block) => block.id)
      .toList(growable: false);
}
