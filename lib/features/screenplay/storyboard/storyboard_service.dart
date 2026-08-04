import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/document/scene_section.dart';
import 'package:filmsoz_studio/features/screenplay/storyboard/storyboard_shot.dart';

class NumberedStoryboardShot {
  const NumberedStoryboardShot({
    required this.scene,
    required this.shot,
    required this.shotIndex,
  });

  final SceneSection scene;
  final StoryboardShot shot;
  final int shotIndex;

  String get number => '${scene.number}.$shotIndex';
}

class StoryboardService {
  const StoryboardService();

  List<NumberedStoryboardShot> numberedShots(FilmDocument document) {
    final result = <NumberedStoryboardShot>[];

    for (final scene in document.sceneSections) {
      final shots = document.storyboardShotsFor(scene.id);

      for (var index = 0; index < shots.length; index++) {
        result.add(
          NumberedStoryboardShot(
            scene: scene,
            shot: shots[index],
            shotIndex: index + 1,
          ),
        );
      }
    }

    return result;
  }

  List<NumberedStoryboardShot> filterShots(
    FilmDocument document, {
    String query = '',
    Set<ShotSize> shotSizes = const <ShotSize>{},
    String equipment = '',
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final normalizedEquipment = equipment.trim().toLowerCase();

    return numberedShots(document).where((entry) {
      if (shotSizes.isNotEmpty && !shotSizes.contains(entry.shot.shotSize)) {
        return false;
      }

      if (normalizedEquipment.isNotEmpty &&
          !entry.shot.equipment.any(
            (item) => item.toLowerCase().contains(normalizedEquipment),
          )) {
        return false;
      }

      if (normalizedQuery.isEmpty) {
        return true;
      }

      final searchable = <String>[
        entry.number,
        entry.scene.title,
        entry.shot.title,
        entry.shot.shotSize.label,
        entry.shot.cameraAngle.label,
        entry.shot.cameraMovement.label,
        entry.shot.lens,
        ...entry.shot.equipment,
        entry.shot.visualDescription,
        entry.shot.actionDescription,
        entry.shot.dialogue,
        entry.shot.sound,
        entry.shot.notes,
      ].join('\n').toLowerCase();

      return searchable.contains(normalizedQuery);
    }).toList(growable: false);
  }

  double totalDurationSeconds(FilmDocument document) {
    return numberedShots(document).fold<double>(
      0,
      (total, entry) => total + entry.shot.durationSeconds,
    );
  }

  double sceneDurationSeconds(FilmDocument document, String sceneId) {
    return document.storyboardShotsFor(sceneId).fold<double>(
          0,
          (total, shot) => total + shot.durationSeconds,
        );
  }

  String formatDuration(double seconds) {
    final totalSeconds = seconds.round().clamp(0, 359999);
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final remainingSeconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${remainingSeconds.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:'
        '${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String buildShotListCsv(
    FilmDocument document, {
    required String projectName,
  }) {
    final rows = <List<String>>[
      <String>['FILMSOZ SHOT LIST'],
      <String>['Проект', projectName],
      <String>['Всего кадров', '${numberedShots(document).length}'],
      <String>[
        'Общая длительность',
        formatDuration(totalDurationSeconds(document))
      ],
      const <String>[],
      <String>[
        'Кадр',
        'Сцена',
        'Заголовок сцены',
        'Название кадра',
        'План',
        'Ракурс',
        'Движение',
        'Объектив',
        'FPS',
        'Длительность, сек',
        'Оборудование',
        'Изображение',
        'Описание изображения',
        'Действие',
        'Диалог',
        'Звук',
        'Примечания',
      ],
    ];

    for (final entry in numberedShots(document)) {
      final shot = entry.shot;
      rows.add(<String>[
        entry.number,
        '${entry.scene.number}',
        entry.scene.title,
        shot.title,
        shot.shotSize.label,
        shot.cameraAngle.label,
        shot.cameraMovement.label,
        shot.lens,
        _formatNumber(shot.fps),
        _formatNumber(shot.durationSeconds),
        shot.equipment.join(', '),
        shot.imageFileName ?? '',
        shot.visualDescription,
        shot.actionDescription,
        shot.dialogue,
        shot.sound,
        shot.notes,
      ]);
    }

    return '\uFEFF${rows.map(_csvRow).join('\r\n')}';
  }

  String _csvRow(List<String> cells) {
    return cells.map(_escapeCsv).join(';');
  }

  String _escapeCsv(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return '${value.toInt()}';
    }

    return value.toStringAsFixed(2);
  }
}
