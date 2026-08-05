import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/document/scene_section.dart';
import 'package:filmsoz_studio/features/screenplay/postproduction/postproduction.dart';
import 'package:filmsoz_studio/features/screenplay/shooting_control/shooting_control.dart';

class PostProductionSummary {
  const PostProductionSummary({
    required this.sceneCount,
    required this.readySceneCount,
    required this.averageSceneProgress,
    required this.taskCount,
    required this.completedTaskCount,
    required this.overdueTaskCount,
    required this.openMissingMaterialCount,
    required this.currentVersionCount,
  });

  final int sceneCount;
  final int readySceneCount;
  final double averageSceneProgress;
  final int taskCount;
  final int completedTaskCount;
  final int overdueTaskCount;
  final int openMissingMaterialCount;
  final int currentVersionCount;

  double get overallProgress {
    if (sceneCount == 0 && taskCount == 0) {
      return 0;
    }

    final sceneWeight = sceneCount == 0 ? 0.0 : averageSceneProgress * 0.65;
    final taskProgress =
        taskCount == 0 ? 0.0 : completedTaskCount / taskCount * 100 * 0.35;
    final denominator =
        (sceneCount == 0 ? 0.0 : 0.65) + (taskCount == 0 ? 0.0 : 0.35);

    if (denominator == 0) {
      return 0;
    }

    return (sceneWeight + taskProgress) / denominator;
  }
}

class PostProductionService {
  const PostProductionService();

  PostProductionSummary summarize(
    FilmDocument document, {
    DateTime? now,
  }) {
    final scenes = document.sceneSections;
    var readySceneCount = 0;
    var sceneProgressTotal = 0;

    for (final scene in scenes) {
      final data = document.scenePostProductionFor(scene.id);
      sceneProgressTotal += data.progress;

      if (data.status == PostSceneStatus.ready) {
        readySceneCount++;
      }
    }

    final tasks = document.postProductionTasks;
    final today = _dateOnly(now ?? DateTime.now());
    var completedTaskCount = 0;
    var overdueTaskCount = 0;

    for (final task in tasks) {
      if (task.status == PostTaskStatus.done) {
        completedTaskCount++;
        continue;
      }

      final dueDate = _tryParseDate(task.dueDate);

      if (dueDate != null && dueDate.isBefore(today)) {
        overdueTaskCount++;
      }
    }

    final openMissingMaterialCount = document.missingMaterials.where((item) {
      return item.status != MissingMaterialStatus.completed &&
          item.status != MissingMaterialStatus.cancelled;
    }).length;

    return PostProductionSummary(
      sceneCount: scenes.length,
      readySceneCount: readySceneCount,
      averageSceneProgress:
          scenes.isEmpty ? 0 : sceneProgressTotal / scenes.length,
      taskCount: tasks.length,
      completedTaskCount: completedTaskCount,
      overdueTaskCount: overdueTaskCount,
      openMissingMaterialCount: openMissingMaterialCount,
      currentVersionCount:
          document.editVersions.where((version) => version.isCurrent).length,
    );
  }

  List<ShotTake> selectedTakesForScene(
    FilmDocument document,
    String sceneId,
  ) {
    final validTakeIds =
        document.scenePostProductionFor(sceneId).selectedTakeIds;
    final result = <ShotTake>[];

    for (final shot in document.storyboardShotsFor(sceneId)) {
      for (final take in document.shotTakesFor(shot.id)) {
        if (validTakeIds.contains(take.id)) {
          result.add(take);
        }
      }
    }

    return result;
  }

  List<ShotTake> availableSelectedTakesForScene(
    FilmDocument document,
    String sceneId,
  ) {
    final result = <ShotTake>[];

    for (final shot in document.storyboardShotsFor(sceneId)) {
      final takes = document.shotTakesFor(shot.id);
      final explicitlySelected = takes.where(
        (take) => take.status == ShotTakeStatus.selected,
      );

      if (explicitlySelected.isNotEmpty) {
        result.addAll(explicitlySelected);
      } else {
        result.addAll(
          takes.where((take) => take.status == ShotTakeStatus.recorded),
        );
      }
    }

    return result;
  }

  String buildPostProductionPlanCsv(
    FilmDocument document, {
    required String projectName,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(
        '\uFEFFПроект;Тип;Номер/ID;Название;Отдел;Статус;Прогресс;Ответственный;Срок;Сцена;Версия;Примечания');

    for (final scene in document.sceneSections) {
      final data = document.scenePostProductionFor(scene.id);
      buffer.writeln(
        <String>[
          projectName,
          'Сцена',
          '${scene.number}',
          scene.title,
          'Монтаж',
          data.status.label,
          '${data.progress}%',
          '',
          '',
          '${scene.number}. ${scene.title}',
          '',
          _joinNotes(data.editorNotes, data.directorNotes),
        ].map(_csvCell).join(';'),
      );
    }

    for (final task in document.postProductionTasks) {
      final scene = _sceneForId(document, task.sceneId);
      final version = document.editVersionById(task.versionId ?? '');
      buffer.writeln(
        <String>[
          projectName,
          'Задача',
          task.id,
          task.title,
          task.department.label,
          task.status.label,
          '${task.progress}%',
          task.assignee,
          task.dueDate,
          scene == null ? '' : '${scene.number}. ${scene.title}',
          version?.title ?? '',
          task.notes,
        ].map(_csvCell).join(';'),
      );
    }

    for (final item in document.missingMaterials) {
      final scene = _sceneForId(document, item.sceneId);
      buffer.writeln(
        <String>[
          projectName,
          item.type.label,
          item.id,
          item.title,
          'Производство',
          item.status.label,
          item.status == MissingMaterialStatus.completed ? '100%' : '0%',
          item.assignee,
          item.scheduledDate,
          scene == null ? '' : '${scene.number}. ${scene.title}',
          '',
          item.description,
        ].map(_csvCell).join(';'),
      );
    }

    return buffer.toString();
  }

  String buildVersionHistoryCsv(
    FilmDocument document, {
    required String projectName,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(
        '\uFEFFПроект;Монтажный эпизод;Версия;Название;Текущая;Программа;Файл;Дата;Длительность;Примечания');

    for (final version in document.editVersions) {
      final sequence = document.postProductionSequenceById(
        version.sequenceId ?? '',
      );
      buffer.writeln(
        <String>[
          projectName,
          sequence?.title ?? '',
          'v${version.versionNumber}',
          version.title,
          version.isCurrent ? 'Да' : 'Нет',
          version.application,
          version.filePath,
          version.createdAt,
          formatDuration(version.durationSeconds),
          version.notes,
        ].map(_csvCell).join(';'),
      );
    }

    return buffer.toString();
  }

  String formatDuration(double seconds) {
    final totalSeconds = seconds.isFinite && seconds > 0 ? seconds.round() : 0;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final remainder = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${remainder.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:'
        '${remainder.toString().padLeft(2, '0')}';
  }

  SceneSection? _sceneForId(FilmDocument document, String? sceneId) {
    if (sceneId == null || sceneId.isEmpty) {
      return null;
    }

    return document.sceneById(sceneId);
  }

  String _joinNotes(String first, String second) {
    return <String>[first.trim(), second.trim()]
        .where((value) => value.isNotEmpty)
        .join(' / ');
  }

  DateTime? _tryParseDate(String value) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      return null;
    }

    return DateTime.tryParse(normalized);
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }
}
