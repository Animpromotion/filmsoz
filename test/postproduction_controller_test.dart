import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/editor/controller/screenplay_editor_controller.dart';
import 'package:filmsoz_studio/features/screenplay/postproduction/postproduction.dart';
import 'package:filmsoz_studio/features/screenplay/shooting_control/shooting_control.dart';
import 'package:filmsoz_studio/features/screenplay/storyboard/storyboard_shot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScreenplayEditorController post-production', () {
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
          shotTakes: const <String, List<ShotTake>>{
            'shot1': <ShotTake>[
              ShotTake(id: 'take1', status: ShotTakeStatus.selected),
            ],
          },
        ),
      );
    });

    tearDown(() => controller.dispose());

    test('updates scene status and selected takes with undo redo', () {
      expect(
        controller.setScenePostProduction(
          's1',
          const ScenePostProductionData(
            status: PostSceneStatus.editing,
            progress: 60,
            selectedTakeIds: <String>['take1', 'missing'],
          ),
        ),
        isTrue,
      );

      expect(controller.document.scenePostProductionFor('s1').progress, 60);
      expect(
        controller.document.scenePostProductionFor('s1').selectedTakeIds,
        <String>['take1'],
      );
      expect(controller.undo(), isTrue);
      expect(
          controller.document.scenePostProductionFor('s1').isDefault, isTrue);
      expect(controller.redo(), isTrue);
      expect(controller.document.scenePostProductionFor('s1').progress, 60);
    });

    test('creates sequences versions tasks and missing material', () {
      final sequenceId = controller.createPostProductionSequence();
      final versionId = controller.createEditVersion(sequenceId: sequenceId);
      final taskId = controller.createPostProductionTask(sceneId: 's1');
      final missingId = controller.createMissingMaterial(
        sceneId: 's1',
        shotId: 'shot1',
      );

      expect(
        controller.document.postProductionSequenceById(sequenceId),
        isNotNull,
      );
      expect(controller.document.editVersionById(versionId)!.isCurrent, isTrue);
      expect(controller.document.postProductionTaskById(taskId)!.sceneId, 's1');
      expect(
          controller.document.missingMaterialById(missingId)!.shotId, 'shot1');

      expect(controller.deleteEditVersion(versionId), isTrue);
      expect(controller.document.editVersions, isEmpty);
      expect(controller.undo(), isTrue);
      expect(controller.document.editVersionById(versionId), isNotNull);
    });

    test('duplicates scene and remaps selected takes', () {
      controller.setScenePostProduction(
        's1',
        const ScenePostProductionData(
          status: PostSceneStatus.review,
          selectedTakeIds: <String>['take1'],
        ),
      );

      final result = controller.duplicateScene('s1')!;
      final copiedShot =
          controller.document.storyboardShotsFor(result.sceneId).single;
      final copiedTake = controller.document.shotTakesFor(copiedShot.id).single;
      final copiedData =
          controller.document.scenePostProductionFor(result.sceneId);

      expect(copiedTake.id, isNot('take1'));
      expect(copiedData.selectedTakeIds, <String>[copiedTake.id]);
      expect(copiedData.status, PostSceneStatus.review);
    });
  });
}
