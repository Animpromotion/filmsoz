import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/postproduction/postproduction.dart';
import 'package:filmsoz_studio/features/screenplay/shooting_control/shooting_control.dart';
import 'package:filmsoz_studio/features/screenplay/storyboard/storyboard_shot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('post-production data survives JSON round trip', () {
    final document = FilmDocument(
      blocks: <FilmBlock>[
        FilmBlock(
          id: 's1',
          type: BlockType.sceneHeading,
          text: 'ИНТ. МОНТАЖНАЯ - ДЕНЬ',
        ),
      ],
      storyboardShots: const <String, List<StoryboardShot>>{
        's1': <StoryboardShot>[StoryboardShot(id: 'shot1')],
      },
      shotTakes: const <String, List<ShotTake>>{
        'shot1': <ShotTake>[ShotTake(id: 'take1')],
      },
      scenePostProduction: const <String, ScenePostProductionData>{
        's1': ScenePostProductionData(
          status: PostSceneStatus.review,
          progress: 75,
          editorNotes: 'Проверить ритм.',
          selectedTakeIds: <String>['take1'],
          directorApproval: ApprovalStatus.changesRequested,
        ),
      },
      postProductionSequences: const <PostProductionSequence>[
        PostProductionSequence(
          id: 'seq1',
          title: 'Первый акт',
          sceneIds: <String>['s1'],
        ),
      ],
      editVersions: const <EditVersion>[
        EditVersion(
          id: 'v1',
          title: 'Черновой монтаж',
          sequenceId: 'seq1',
          versionNumber: 3,
          application: 'DaVinci Resolve',
          isCurrent: true,
        ),
      ],
      postProductionTasks: const <PostProductionTask>[
        PostProductionTask(
          id: 'task1',
          title: 'Свести диалог',
          department: PostTaskDepartment.sound,
          status: PostTaskStatus.inProgress,
          progress: 40,
          sceneId: 's1',
          versionId: 'v1',
        ),
      ],
      missingMaterials: const <MissingMaterialItem>[
        MissingMaterialItem(
          id: 'm1',
          title: 'Крупный план руки',
          type: MissingMaterialType.pickup,
          sceneId: 's1',
          shotId: 'shot1',
        ),
      ],
    );

    final restored = FilmDocument.fromJson(document.toJson());

    expect(restored.scenePostProductionFor('s1').progress, 75);
    expect(
      restored.scenePostProductionFor('s1').selectedTakeIds,
      <String>['take1'],
    );
    expect(restored.postProductionSequences.single.title, 'Первый акт');
    expect(restored.editVersions.single.application, 'DaVinci Resolve');
    expect(restored.postProductionTasks.single.versionId, 'v1');
    expect(restored.missingMaterials.single.shotId, 'shot1');
  });

  test('orphaned post-production references are normalized on load', () {
    final document = FilmDocument.fromJson(<String, dynamic>{
      'blocks': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 's1',
          'type': 'sceneHeading',
          'text': 'НАТ. ДВОР - ДЕНЬ',
        },
      ],
      'scenePostProduction': <String, dynamic>{
        'missing': <String, dynamic>{'progress': 80},
      },
      'postProductionSequences': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'seq1',
          'title': 'Эпизод',
          'sceneIds': <String>['s1', 'missing'],
        },
      ],
      'editVersions': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'v1',
          'title': 'Версия',
          'sequenceId': 'missingSequence',
        },
      ],
      'postProductionTasks': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 't1',
          'title': 'Задача',
          'sceneId': 'missing',
          'versionId': 'missingVersion',
        },
      ],
      'missingMaterials': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'm1',
          'title': 'Материал',
          'sceneId': 'missing',
          'shotId': 'missingShot',
        },
      ],
    });

    expect(document.scenePostProduction, isEmpty);
    expect(document.postProductionSequences.single.sceneIds, <String>['s1']);
    expect(document.editVersions.single.sequenceId, isNull);
    expect(document.postProductionTasks.single.sceneId, isNull);
    expect(document.postProductionTasks.single.versionId, isNull);
    expect(document.missingMaterials.single.sceneId, isNull);
    expect(document.missingMaterials.single.shotId, isNull);
  });
}
