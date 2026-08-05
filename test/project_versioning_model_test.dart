import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/versioning/project_versioning.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FilmDocument preserves versioning and collaboration data', () {
    final document = FilmDocument(
      blocks: <FilmBlock>[
        FilmBlock(
            id: 'scene_1', type: BlockType.sceneHeading, text: 'ИНТ. ДОМ'),
      ],
      projectMembers: const <ProjectMember>[
        ProjectMember(id: 'member_1', name: 'Фарход', role: 'Режиссёр'),
      ],
      collaborationComments: const <CollaborationComment>[
        CollaborationComment(
          id: 'comment_1',
          text: 'Уточнить реквизит',
          targetType: CollaborationTargetType.scene,
          targetId: 'scene_1',
          authorId: 'member_1',
          assigneeId: 'member_1',
          dueDate: '2026-08-10',
        ),
      ],
      projectChangeLog: const <ProjectChangeEntry>[
        ProjectChangeEntry(
          id: 'change_1',
          summary: 'Создан комментарий',
          actorId: 'member_1',
        ),
      ],
      projectCheckpoints: const <ProjectCheckpoint>[
        ProjectCheckpoint(
          id: 'checkpoint_1',
          name: 'Черновик',
          snapshot: <String, dynamic>{'blocks': <Object>[]},
        ),
      ],
      versioningSettings: const ProjectVersioningSettings(
        autoBackupMinutes: 15,
        maxAutomaticBackups: 12,
      ),
    );

    final restored = FilmDocument.fromJson(document.toJson());

    expect(restored.projectMembers.single.name, 'Фарход');
    expect(restored.collaborationComments.single.targetId, 'scene_1');
    expect(restored.projectChangeLog.single.summary, 'Создан комментарий');
    expect(restored.projectCheckpoints.single.name, 'Черновик');
    expect(restored.versioningSettings.autoBackupMinutes, 15);
    expect(restored.versioningSettings.maxAutomaticBackups, 12);
  });

  test('checkpoint snapshots can exclude checkpoint history', () {
    final document = FilmDocument.empty();
    document.projectCheckpoints.add(
      ProjectCheckpoint(
        id: 'checkpoint_1',
        name: 'Версия',
        snapshot: document.toJson(includeCheckpoints: false),
      ),
    );

    final snapshot = document.toJson(includeCheckpoints: false);

    expect(snapshot.containsKey('projectCheckpoints'), isFalse);
  });

  test('versioning settings clamp unsafe values', () {
    final settings = const ProjectVersioningSettings().copyWith(
      autoBackupMinutes: 0,
      maxAutomaticBackups: 999,
    );

    expect(settings.autoBackupMinutes, 1);
    expect(settings.maxAutomaticBackups, 100);
  });
}
