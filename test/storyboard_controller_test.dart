import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/editor/controller/screenplay_editor_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScreenplayEditorController storyboard', () {
    late ScreenplayEditorController controller;

    setUp(() {
      controller = ScreenplayEditorController();
      controller.replaceWithImportedDocument(
        FilmDocument(
          blocks: <FilmBlock>[
            FilmBlock(
              id: 's1',
              type: BlockType.sceneHeading,
              text: 'ИНТ. ДОМ - ДЕНЬ',
            ),
            FilmBlock(
              id: 'a1',
              type: BlockType.action,
              text: 'Герой входит.',
            ),
          ],
        ),
      );
    });

    tearDown(() => controller.dispose());

    test('creates updates duplicates and reorders shots', () {
      final firstId = controller.createStoryboardShot('s1')!;
      final first = controller.document.storyboardShotById('s1', firstId)!;

      expect(
        controller.updateStoryboardShot(
          's1',
          first.copyWith(
            title: 'Первый',
            durationSeconds: 4,
            equipment: const <String>['Штатив', 'штатив'],
          ),
        ),
        isTrue,
      );
      expect(
        controller.document.storyboardShotById('s1', firstId)!.equipment,
        <String>['Штатив'],
      );

      final secondId = controller.duplicateStoryboardShot('s1', firstId)!;
      expect(controller.document.storyboardShotsFor('s1'), hasLength(2));
      expect(
        controller.moveStoryboardShot('s1', oldIndex: 1, newIndex: 0),
        isTrue,
      );
      expect(controller.document.storyboardShotsFor('s1').first.id, secondId);
    });

    test('delete shot can be undone and redone', () {
      final id = controller.createStoryboardShot('s1')!;

      expect(controller.deleteStoryboardShot('s1', id), isTrue);
      expect(controller.document.storyboardShotsFor('s1'), isEmpty);
      expect(controller.undo(), isTrue);
      expect(controller.document.storyboardShotsFor('s1'), hasLength(1));
      expect(controller.redo(), isTrue);
      expect(controller.document.storyboardShotsFor('s1'), isEmpty);
    });

    test('duplicating scene copies shots with new identifiers', () {
      final shotId = controller.createStoryboardShot('s1')!;
      controller.updateStoryboardShot(
        's1',
        controller.document
            .storyboardShotById('s1', shotId)!
            .copyWith(title: 'Исходный кадр'),
      );

      final result = controller.duplicateScene('s1')!;
      final copiedShots =
          controller.document.storyboardShotsFor(result.sceneId);

      expect(copiedShots, hasLength(1));
      expect(copiedShots.single.title, 'Исходный кадр');
      expect(copiedShots.single.id, isNot(shotId));
    });

    test('deleting scene removes its storyboard', () {
      controller.createStoryboardShot('s1');
      controller.deleteScene('s1');

      expect(controller.document.storyboardShots.containsKey('s1'), isFalse);
    });
  });
}
