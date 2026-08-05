import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/document/scene_section.dart';
import 'package:filmsoz_studio/features/screenplay/production/production_planning.dart';
import 'package:filmsoz_studio/features/screenplay/shooting_control/shooting_control.dart';
import 'package:filmsoz_studio/features/screenplay/storyboard/storyboard_shot.dart';

class NumberedShotTake {
  const NumberedShotTake({
    required this.scene,
    required this.shot,
    required this.shotIndex,
    required this.take,
  });

  final SceneSection scene;
  final StoryboardShot shot;
  final int shotIndex;
  final ShotTake take;

  String get shotNumber => '${scene.number}.$shotIndex';
  String get takeLabel => '$shotNumber / Дубль ${take.takeNumber}';
}

class ShootingControlSummary {
  const ShootingControlSummary({
    required this.shotCount,
    required this.takeCount,
    required this.recordedCount,
    required this.rejectedCount,
    required this.selectedCount,
    required this.totalRecordedSeconds,
    required this.shotsWithoutSelectedTake,
  });

  final int shotCount;
  final int takeCount;
  final int recordedCount;
  final int rejectedCount;
  final int selectedCount;
  final double totalRecordedSeconds;
  final int shotsWithoutSelectedTake;
}

class ShootingControlService {
  const ShootingControlService();

  List<NumberedShotTake> numberedTakes(FilmDocument document) {
    final result = <NumberedShotTake>[];

    for (final scene in document.sceneSections) {
      final shots = document.storyboardShotsFor(scene.id);

      for (var shotIndex = 0; shotIndex < shots.length; shotIndex++) {
        final shot = shots[shotIndex];

        for (final take in document.shotTakesFor(shot.id)) {
          result.add(
            NumberedShotTake(
              scene: scene,
              shot: shot,
              shotIndex: shotIndex + 1,
              take: take,
            ),
          );
        }
      }
    }

    return result;
  }

  List<NumberedShotTake> filterTakes(
    FilmDocument document, {
    String query = '',
    ShotTakeStatus? status,
    String? shootingDayId,
  }) {
    final normalizedQuery = query.trim().toLowerCase();

    return numberedTakes(document).where((entry) {
      if (status != null && entry.take.status != status) {
        return false;
      }

      if (shootingDayId != null && entry.take.shootingDayId != shootingDayId) {
        return false;
      }

      if (normalizedQuery.isEmpty) {
        return true;
      }

      final take = entry.take;
      final searchable = <String>[
        entry.shotNumber,
        '${take.takeNumber}',
        entry.scene.title,
        entry.shot.title,
        take.status.label,
        take.timecode,
        take.mediaCard,
        take.camera,
        take.fileName,
        take.directorNotes,
        take.cameraNotes,
        take.soundNotes,
        take.rejectionReason,
        take.costumeContinuity,
        take.makeupContinuity,
        take.propsContinuity,
        take.actorPositions,
      ].join('\n').toLowerCase();

      return searchable.contains(normalizedQuery);
    }).toList(growable: false);
  }

  ShootingControlSummary summarize(FilmDocument document) {
    final shots = <StoryboardShot>[
      for (final scene in document.sceneSections)
        ...document.storyboardShotsFor(scene.id),
    ];
    final takes = numberedTakes(document);
    var recorded = 0;
    var rejected = 0;
    var selected = 0;
    var seconds = 0.0;
    var shotsWithoutSelectedTake = 0;

    for (final entry in takes) {
      final take = entry.take;

      if (take.status != ShotTakeStatus.planned) {
        seconds += take.durationSeconds;
      }

      switch (take.status) {
        case ShotTakeStatus.planned:
          break;
        case ShotTakeStatus.recorded:
          recorded++;
          break;
        case ShotTakeStatus.rejected:
          rejected++;
          break;
        case ShotTakeStatus.selected:
          selected++;
          break;
      }
    }

    for (final shot in shots) {
      final hasSelected = document
          .shotTakesFor(shot.id)
          .any((take) => take.status == ShotTakeStatus.selected);

      if (!hasSelected) {
        shotsWithoutSelectedTake++;
      }
    }

    return ShootingControlSummary(
      shotCount: shots.length,
      takeCount: takes.length,
      recordedCount: recorded,
      rejectedCount: rejected,
      selectedCount: selected,
      totalRecordedSeconds: seconds,
      shotsWithoutSelectedTake: shotsWithoutSelectedTake,
    );
  }

  List<NumberedShotTake> selectedTakes(FilmDocument document) {
    return numberedTakes(document)
        .where((entry) => entry.take.status == ShotTakeStatus.selected)
        .toList(growable: false);
  }

  List<NumberedShotTake> takesForDay(
    FilmDocument document,
    String dayId,
  ) {
    return numberedTakes(document)
        .where((entry) => entry.take.shootingDayId == dayId)
        .toList(growable: false);
  }

  String buildEditingLogCsv(
    FilmDocument document, {
    required String projectName,
  }) {
    final rows = <List<Object?>>[
      <Object?>['FILMSOZ EDITING LOG'],
      <Object?>['Проект', projectName],
      <Object?>['Всего дублей', numberedTakes(document).length],
      <Object?>['Выбрано', selectedTakes(document).length],
      const <Object?>[],
      <Object?>[
        'Кадр',
        'Сцена',
        'Название кадра',
        'Дубль',
        'Статус',
        'Съёмочный день',
        'Таймкод',
        'Длительность, сек',
        'Карта памяти',
        'Камера',
        'Имя файла',
        'Оценка',
        'Заметки режиссёра',
        'Заметки оператора',
        'Заметки звука',
        'Причина брака',
        'Костюм',
        'Грим',
        'Реквизит',
        'Положение актёров',
        'Фото непрерывности',
      ],
    ];

    for (final entry in numberedTakes(document)) {
      final take = entry.take;
      final day = take.shootingDayId == null
          ? null
          : document.shootingDayById(take.shootingDayId!);

      rows.add(<Object?>[
        entry.shotNumber,
        entry.scene.title,
        entry.shot.title,
        take.takeNumber,
        take.status.label,
        day?.title ?? '',
        take.timecode,
        _formatNumber(take.durationSeconds),
        take.mediaCard,
        take.camera,
        take.fileName,
        take.rating,
        take.directorNotes,
        take.cameraNotes,
        take.soundNotes,
        take.rejectionReason,
        take.costumeContinuity,
        take.makeupContinuity,
        take.propsContinuity,
        take.actorPositions,
        take.continuityPhotos.length,
      ]);
    }

    return '\uFEFF${rows.map(_csvRow).join('\r\n')}\r\n';
  }

  String buildShootingDayJournalCsv(
    FilmDocument document, {
    required String projectName,
  }) {
    final rows = <List<Object?>>[
      <Object?>['FILMSOZ SHOOTING DAY JOURNAL'],
      <Object?>['Проект', projectName],
      const <Object?>[],
      <Object?>[
        'Съёмочный день',
        'Дата',
        'Статус',
        'Фактический сбор',
        'Первый кадр',
        'Окончание',
        'Погода',
        'Снято дублей',
        'Выбрано дублей',
        'Итог дня',
        'Инциденты',
        'Резервные копии',
        'Отчёт камеры',
        'Отчёт звука',
        'Примечания',
      ],
    ];

    for (final day in document.shootingDays) {
      final journal = document.shootingDayJournalFor(day.id);
      final takes = takesForDay(document, day.id);
      rows.add(<Object?>[
        day.title,
        day.date,
        day.status.label,
        journal.actualCrewCall,
        journal.actualFirstShot,
        journal.actualWrap,
        journal.weather,
        takes
            .where((entry) => entry.take.status != ShotTakeStatus.planned)
            .length,
        takes
            .where((entry) => entry.take.status == ShotTakeStatus.selected)
            .length,
        journal.summary,
        journal.incidents,
        journal.mediaBackup,
        journal.cameraReport,
        journal.soundReport,
        journal.notes,
      ]);
    }

    return '\uFEFF${rows.map(_csvRow).join('\r\n')}\r\n';
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

  String shootingDayLabel(FilmDocument document, String? dayId) {
    if (dayId == null) {
      return 'Не назначен';
    }

    final day = document.shootingDayById(dayId);
    return day == null ? 'Не назначен' : day.title;
  }

  String _csvRow(List<Object?> cells) {
    return cells.map((cell) {
      final value = cell?.toString() ?? '';
      return '"${value.replaceAll('"', '""')}"';
    }).join(';');
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return '${value.toInt()}';
    }

    return value.toStringAsFixed(2);
  }
}
