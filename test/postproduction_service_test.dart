import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/postproduction/postproduction.dart';
import 'package:filmsoz_studio/features/screenplay/postproduction/postproduction_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('summarizes readiness and overdue work', () {
    final document = FilmDocument(
      blocks: <FilmBlock>[
        FilmBlock(id: 's1', type: BlockType.sceneHeading, text: 'INT. A - DAY'),
        FilmBlock(id: 's2', type: BlockType.sceneHeading, text: 'INT. B - DAY'),
      ],
      scenePostProduction: const <String, ScenePostProductionData>{
        's1': ScenePostProductionData(
          status: PostSceneStatus.ready,
          progress: 100,
        ),
        's2': ScenePostProductionData(
          status: PostSceneStatus.editing,
          progress: 50,
        ),
      },
      postProductionTasks: const <PostProductionTask>[
        PostProductionTask(
          id: 't1',
          title: 'Done',
          status: PostTaskStatus.done,
          progress: 100,
        ),
        PostProductionTask(
          id: 't2',
          title: 'Late',
          dueDate: '2026-01-01',
        ),
      ],
      missingMaterials: const <MissingMaterialItem>[
        MissingMaterialItem(id: 'm1', title: 'Pickup'),
      ],
    );

    const service = PostProductionService();
    final summary = service.summarize(
      document,
      now: DateTime(2026, 8, 5),
    );

    expect(summary.sceneCount, 2);
    expect(summary.readySceneCount, 1);
    expect(summary.averageSceneProgress, 75);
    expect(summary.completedTaskCount, 1);
    expect(summary.overdueTaskCount, 1);
    expect(summary.openMissingMaterialCount, 1);
    expect(summary.overallProgress, greaterThan(60));
  });

  test('builds UTF-8 CSV reports', () {
    final document = FilmDocument(
      blocks: <FilmBlock>[
        FilmBlock(
          id: 's1',
          type: BlockType.sceneHeading,
          text: 'ИНТ. ДОМ - ДЕНЬ',
        ),
      ],
      postProductionTasks: const <PostProductionTask>[
        PostProductionTask(
          id: 't1',
          title: 'Цветокоррекция сцены',
          department: PostTaskDepartment.color,
          sceneId: 's1',
        ),
      ],
      editVersions: const <EditVersion>[
        EditVersion(id: 'v1', title: 'Монтаж 1', versionNumber: 1),
      ],
    );

    const service = PostProductionService();
    final plan = service.buildPostProductionPlanCsv(
      document,
      projectName: 'Филмсоз',
    );
    final versions = service.buildVersionHistoryCsv(
      document,
      projectName: 'Филмсоз',
    );

    expect(plan, contains('Цветокоррекция сцены'));
    expect(plan, contains('ИНТ. ДОМ - ДЕНЬ'));
    expect(versions, contains('Монтаж 1'));
    expect(plan.codeUnitAt(0), 0xFEFF);
  });
}
