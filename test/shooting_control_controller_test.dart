import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/editor/controller/screenplay_editor_controller.dart';
import 'package:filmsoz_studio/features/screenplay/production/production_planning.dart';
import 'package:filmsoz_studio/features/screenplay/shooting_control/shooting_control.dart';
import 'package:filmsoz_studio/features/screenplay/storyboard/storyboard_shot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScreenplayEditorController shooting control', () {
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
          ],
          storyboardShots: const <String, List<StoryboardShot>>{
            's1': <StoryboardShot>[StoryboardShot(id: 'shot1')],
          },
          shootingDays: const <ShootingDayPlan>[
            ShootingDayPlan(id: 'day1', title: 'День 1'),
          ],
        ),
      );
    });

    tearDown(() => controller.dispose());

    test('creates updates and selects only one best take', () {
      final firstId = controller.createShotTake('shot1')!;
      final secondId = controller.createShotTake('shot1')!;
      final first = controller.document.shotTakeById('shot1', firstId)!;
      final second = controller.document.shotTakeById('shot1', secondId)!;

      controller.updateShotTake(
        'shot1',
        first.copyWith(status: ShotTakeStatus.selected),
      );
      controller.updateShotTake(
        'shot1',
        second.copyWith(status: ShotTakeStatus.selected),
      );

      expect(
        controller.document.shotTakeById('shot1', firstId)!.status,
        ShotTakeStatus.recorded,
      );
      expect(
        controller.document.shotTakeById('shot1', secondId)!.status,
        ShotTakeStatus.selected,
      );
    });

    test('duplicates and deletes take with undo redo', () {
      final firstId = controller.createShotTake('shot1')!;
      final duplicateId = controller.duplicateShotTake('shot1', firstId)!;

      expect(controller.document.shotTakesFor('shot1'), hasLength(2));
      expect(duplicateId, isNot(firstId));
      expect(controller.deleteShotTake('shot1', duplicateId), isTrue);
      expect(controller.document.shotTakesFor('shot1'), hasLength(1));
      expect(controller.undo(), isTrue);
      expect(controller.document.shotTakesFor('shot1'), hasLength(2));
      expect(controller.redo(), isTrue);
      expect(controller.document.shotTakesFor('shot1'), hasLength(1));
    });

    test('duplicates scene with shots and their takes', () {
      final takeId = controller.createShotTake('shot1')!;
      controller.updateShotTake(
        'shot1',
        controller.document
            .shotTakeById('shot1', takeId)!
            .copyWith(fileName: 'A001.mov'),
      );

      final result = controller.duplicateScene('s1')!;
      final copiedShot =
          controller.document.storyboardShotsFor(result.sceneId).single;
      final copiedTake = controller.document.shotTakesFor(copiedShot.id).single;

      expect(copiedShot.id, isNot('shot1'));
      expect(copiedTake.id, isNot(takeId));
      expect(copiedTake.fileName, 'A001.mov');
    });

    test('stores journal and clears day links when day is deleted', () {
      final takeId = controller.createShotTake(
        'shot1',
        shootingDayId: 'day1',
      )!;
      expect(
        controller.setShootingDayJournal(
          'day1',
          const ShootingDayJournal(summary: 'Снято успешно'),
        ),
        isTrue,
      );

      controller.deleteShootingDay('day1');

      expect(controller.document.shootingDayJournals, isEmpty);
      expect(
        controller.document.shotTakeById('shot1', takeId)!.shootingDayId,
        isNull,
      );
    });
  });
}
