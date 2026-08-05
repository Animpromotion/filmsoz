import 'package:filmsoz_studio/features/screenplay/editor/controller/screenplay_editor_controller.dart';
import 'package:filmsoz_studio/features/screenplay/versioning/project_versioning.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('controller manages members comments and undo', () {
    final controller = ScreenplayEditorController();
    addTearDown(controller.dispose);

    controller.upsertProjectMember(
      const ProjectMember(id: 'member_1', name: 'Фарход', role: 'Режиссёр'),
    );
    controller.upsertCollaborationComment(
      const CollaborationComment(
        id: 'comment_1',
        text: 'Проверить сцену',
        assigneeId: 'member_1',
      ),
    );

    expect(controller.document.projectMembers, hasLength(1));
    expect(controller.document.collaborationComments, hasLength(1));
    expect(controller.document.projectChangeLog, isNotEmpty);

    expect(controller.undo(), isTrue);
    expect(controller.document.collaborationComments, isEmpty);
  });

  test('checkpoint restores screenplay content and remains available', () {
    final controller = ScreenplayEditorController();
    addTearDown(controller.dispose);
    final blockId = controller.document.blocks.first.id;

    controller.updateBlockText(blockId, 'ПЕРВАЯ ВЕРСИЯ');
    final checkpoint = controller.createProjectCheckpoint(
      name: 'Первая версия',
    );
    controller.updateBlockText(blockId, 'ВТОРАЯ ВЕРСИЯ');

    expect(controller.restoreProjectCheckpoint(checkpoint.id), isTrue);
    expect(controller.document.blocks.first.text, 'ПЕРВАЯ ВЕРСИЯ');
    expect(controller.document.projectCheckpointById(checkpoint.id), isNotNull);
  });

  test('deleting a member clears comment assignments', () {
    final controller = ScreenplayEditorController();
    addTearDown(controller.dispose);

    controller.upsertProjectMember(
      const ProjectMember(id: 'member_1', name: 'Участник'),
    );
    controller.upsertCollaborationComment(
      const CollaborationComment(
        id: 'comment_1',
        text: 'Задача',
        authorId: 'member_1',
        assigneeId: 'member_1',
      ),
    );

    expect(controller.deleteProjectMember('member_1'), isTrue);
    final comment = controller.document.collaborationComments.single;
    expect(comment.authorId, isNull);
    expect(comment.assigneeId, isNull);
  });
}
