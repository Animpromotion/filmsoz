import 'dart:io';

import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/versioning/project_versioning.dart';
import 'package:filmsoz_studio/features/screenplay/versioning/project_versioning_file_service.dart';
import 'package:filmsoz_studio/features/screenplay/versioning/project_versioning_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('comparison reports scene and block changes', () {
    final first = FilmDocument(
      blocks: <FilmBlock>[
        FilmBlock(
            id: 'scene_1', type: BlockType.sceneHeading, text: 'ИНТ. ДОМ'),
        FilmBlock(id: 'action_1', type: BlockType.action, text: 'Тишина.'),
      ],
    );
    final second = FilmDocument(
      blocks: <FilmBlock>[
        FilmBlock(
            id: 'scene_1', type: BlockType.sceneHeading, text: 'ИНТ. ДОМ'),
        FilmBlock(
            id: 'action_1', type: BlockType.action, text: 'Громкая музыка.'),
        FilmBlock(
            id: 'action_2', type: BlockType.action, text: 'Дверь открывается.'),
      ],
    );

    final comparison = const ProjectVersioningService().compareDocuments(
      first,
      second,
    );

    expect(comparison.addedBlocks, 1);
    expect(comparison.changedBlocks, 1);
    expect(comparison.changedScenes, 1);
  });

  test('comment filters find overdue assigned items', () {
    final document = FilmDocument.empty();
    document.projectMembers.add(
      const ProjectMember(id: 'member_1', name: 'Монтажёр'),
    );
    document.collaborationComments.addAll(
      const <CollaborationComment>[
        CollaborationComment(
          id: 'late',
          text: 'Исправить монтаж',
          assigneeId: 'member_1',
          dueDate: '2026-01-01',
        ),
        CollaborationComment(
          id: 'done',
          text: 'Готово',
          assigneeId: 'member_1',
          dueDate: '2026-01-01',
          status: CollaborationCommentStatus.resolved,
        ),
      ],
    );

    final result = const ProjectVersioningService().filterComments(
      document,
      memberId: 'member_1',
      overdueOnly: true,
      now: DateTime(2026, 8, 5),
    );

    expect(result.map((item) => item.id), <String>['late']);
  });

  test('fingerprint ignores local versioning history metadata', () {
    final document = FilmDocument.empty();
    final first = ProjectVersioningFileService.fingerprint(document);
    document.projectChangeLog.add(
      const ProjectChangeEntry(id: 'change_1', summary: 'Экспорт'),
    );
    document.projectCheckpoints.add(
      ProjectCheckpoint(
        id: 'checkpoint_1',
        name: 'Версия',
        snapshot: document.toJson(includeCheckpoints: false),
      ),
    );

    expect(ProjectVersioningFileService.fingerprint(document), first);
  });

  test('team package round-trip preserves document and detects conflict',
      () async {
    final directory = await Directory.systemTemp.createTemp('filmsoz_v19_');
    addTearDown(() => directory.delete(recursive: true));
    final filePath =
        '${directory.path}${Platform.pathSeparator}team.filmsozpack';
    final service = const ProjectVersioningFileService();
    final document = FilmDocument.empty();

    await service.writeTeamPackage(
      filePath: filePath,
      document: document,
      projectName: 'Тест',
      exportedAt: DateTime.utc(2026, 8, 5),
    );
    final imported = await service.readTeamPackage(filePath);

    expect(imported.projectName, 'Тест');
    expect(imported.document.blocks.length, document.blocks.length);
    expect(imported.conflictsWith(document), isFalse);

    document.blocks.first.text = 'ИЗМЕНЕНО';
    expect(imported.conflictsWith(document), isTrue);
  });
  test('automatic backups are loaded and pruned to configured limit', () async {
    final directory = await Directory.systemTemp.createTemp('filmsoz_backup_');
    addTearDown(() => directory.delete(recursive: true));
    final service = ProjectVersioningFileService(
      rootDirectoryPath: directory.path,
    );
    final document = FilmDocument.empty();

    for (var index = 0; index < 3; index++) {
      document.blocks.first.text = 'Версия $index';
      await service.createAutomaticBackup(
        document: document,
        projectName: 'Тестовый проект',
        maxBackups: 2,
        now: DateTime.utc(2026, 8, 5, 10, 0, index),
      );
    }

    final backups = await service.listAutomaticBackups(
      projectName: 'Тестовый проект',
    );

    expect(backups, hasLength(2));
    final restored = await service.loadAutomaticBackup(backups.first.path);
    expect(restored.blocks.first.text, 'Версия 2');
  });
}
