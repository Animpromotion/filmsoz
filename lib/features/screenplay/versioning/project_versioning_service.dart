import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/versioning/project_versioning.dart';

class VersionComparison {
  const VersionComparison({
    required this.addedBlocks,
    required this.removedBlocks,
    required this.changedBlocks,
    required this.addedScenes,
    required this.removedScenes,
    required this.changedScenes,
  });

  final int addedBlocks;
  final int removedBlocks;
  final int changedBlocks;
  final int addedScenes;
  final int removedScenes;
  final int changedScenes;

  bool get hasChanges =>
      addedBlocks > 0 ||
      removedBlocks > 0 ||
      changedBlocks > 0 ||
      addedScenes > 0 ||
      removedScenes > 0 ||
      changedScenes > 0;
}

class ProjectVersioningService {
  const ProjectVersioningService();

  VersionComparison compareDocuments(
    FilmDocument first,
    FilmDocument second,
  ) {
    final firstBlocks = <String, String>{
      for (final block in first.blocks)
        block.id: '${block.type.name}\u0000${block.text}',
    };
    final secondBlocks = <String, String>{
      for (final block in second.blocks)
        block.id: '${block.type.name}\u0000${block.text}',
    };

    final addedBlockIds = secondBlocks.keys.toSet().difference(
          firstBlocks.keys.toSet(),
        );
    final removedBlockIds = firstBlocks.keys.toSet().difference(
          secondBlocks.keys.toSet(),
        );
    final sharedBlockIds = firstBlocks.keys.toSet().intersection(
          secondBlocks.keys.toSet(),
        );
    final changedBlockIds = sharedBlockIds.where(
      (id) => firstBlocks[id] != secondBlocks[id],
    );

    final firstScenes = <String, String>{
      for (final scene in first.sceneSections)
        scene.id: scene.blocks
            .map((block) => '${block.type.name}\u0000${block.text}')
            .join('\u0001'),
    };
    final secondScenes = <String, String>{
      for (final scene in second.sceneSections)
        scene.id: scene.blocks
            .map((block) => '${block.type.name}\u0000${block.text}')
            .join('\u0001'),
    };
    final addedSceneIds = secondScenes.keys.toSet().difference(
          firstScenes.keys.toSet(),
        );
    final removedSceneIds = firstScenes.keys.toSet().difference(
          secondScenes.keys.toSet(),
        );
    final sharedSceneIds = firstScenes.keys.toSet().intersection(
          secondScenes.keys.toSet(),
        );
    final changedSceneIds = sharedSceneIds.where(
      (id) => firstScenes[id] != secondScenes[id],
    );

    return VersionComparison(
      addedBlocks: addedBlockIds.length,
      removedBlocks: removedBlockIds.length,
      changedBlocks: changedBlockIds.length,
      addedScenes: addedSceneIds.length,
      removedScenes: removedSceneIds.length,
      changedScenes: changedSceneIds.length,
    );
  }

  VersionComparison compareCheckpoints(
    ProjectCheckpoint first,
    ProjectCheckpoint second,
  ) {
    return compareDocuments(
      FilmDocument.fromJson(first.snapshot),
      FilmDocument.fromJson(second.snapshot),
    );
  }

  List<CollaborationComment> filterComments(
    FilmDocument document, {
    CollaborationCommentStatus? status,
    String? memberId,
    bool overdueOnly = false,
    DateTime? now,
  }) {
    final result = document.collaborationComments.where((comment) {
      if (status != null && comment.status != status) {
        return false;
      }

      if (memberId != null &&
          comment.authorId != memberId &&
          comment.assigneeId != memberId) {
        return false;
      }

      if (overdueOnly && !comment.isOverdue(now: now)) {
        return false;
      }

      return true;
    }).toList(growable: false);

    result.sort((first, second) {
      if (first.isResolved != second.isResolved) {
        return first.isResolved ? 1 : -1;
      }

      if (first.isOverdue(now: now) != second.isOverdue(now: now)) {
        return first.isOverdue(now: now) ? -1 : 1;
      }

      return second.updatedAt.compareTo(first.updatedAt);
    });
    return result;
  }

  String targetLabel(
    FilmDocument document,
    CollaborationComment comment,
  ) {
    final targetId = comment.targetId;

    if (targetId == null || targetId.isEmpty) {
      return 'Проект';
    }

    switch (comment.targetType) {
      case CollaborationTargetType.project:
        return 'Проект';
      case CollaborationTargetType.scene:
        final scene = document.sceneById(targetId);
        return scene == null
            ? 'Сцена удалена'
            : 'Сцена ${scene.number}: ${scene.title}';
      case CollaborationTargetType.shot:
        for (final scene in document.sceneSections) {
          final shots = document.storyboardShotsFor(scene.id);
          final index = shots.indexWhere((shot) => shot.id == targetId);

          if (index != -1) {
            return 'Кадр ${scene.number}.${index + 1}';
          }
        }
        return 'Кадр удалён';
      case CollaborationTargetType.take:
        for (final entry in document.shotTakes.entries) {
          final index = entry.value.indexWhere((take) => take.id == targetId);

          if (index != -1) {
            return 'Дубль ${index + 1}';
          }
        }
        return 'Дубль удалён';
      case CollaborationTargetType.task:
        final task = document.postProductionTaskById(targetId);
        return task == null ? 'Задача удалена' : 'Задача: ${task.title}';
    }
  }
}
