import 'dart:math' as math;

import 'package:filmsoz_studio/features/screenplay/development/screenplay_development_service.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/document/scene_section.dart';
import 'package:filmsoz_studio/features/screenplay/production/production_planning.dart';

class ProductionPlanSummary {
  const ProductionPlanSummary({
    required this.sceneCount,
    required this.brokenDownSceneCount,
    required this.shootingDayCount,
    required this.scheduledSceneCount,
    required this.totalSetupMinutes,
    required this.totalShootMinutes,
  });

  final int sceneCount;
  final int brokenDownSceneCount;
  final int shootingDayCount;
  final int scheduledSceneCount;
  final int totalSetupMinutes;
  final int totalShootMinutes;
}

class ProductionPlanningService {
  const ProductionPlanningService();

  final ScreenplayDevelopmentService _developmentService =
      const ScreenplayDevelopmentService();

  SceneProductionData suggestedBreakdown(
    FilmDocument document,
    SceneSection scene,
  ) {
    final stored = document.sceneProductionFor(scene.id);

    return stored.copyWith(
      cast: stored.cast.isEmpty
          ? _developmentService.charactersForScene(scene)
          : stored.cast,
      locations: stored.locations.isEmpty
          ? <String>[_developmentService.locationForScene(scene)]
          : stored.locations,
      estimatedShootMinutes: stored.estimatedShootMinutes <= 0
          ? math.max(
              5,
              (_developmentService.estimatedMinutesForScene(scene) * 30)
                  .round(),
            )
          : stored.estimatedShootMinutes,
    );
  }

  ProductionPlanSummary summarize(FilmDocument document) {
    final validSceneIds =
        document.sceneSections.map((scene) => scene.id).toSet();
    final scheduledSceneIds = <String>{};

    for (final day in document.shootingDays) {
      scheduledSceneIds.addAll(
        day.sceneIds.where(validSceneIds.contains),
      );
    }

    var setupMinutes = 0;
    var shootMinutes = 0;

    for (final data in document.sceneProduction.values) {
      setupMinutes += data.estimatedSetupMinutes;
      shootMinutes += data.estimatedShootMinutes;
    }

    return ProductionPlanSummary(
      sceneCount: validSceneIds.length,
      brokenDownSceneCount: document.sceneProduction.entries
          .where(
            (entry) =>
                validSceneIds.contains(entry.key) && !entry.value.isDefault,
          )
          .length,
      shootingDayCount: document.shootingDays.length,
      scheduledSceneCount: scheduledSceneIds.length,
      totalSetupMinutes: setupMinutes,
      totalShootMinutes: shootMinutes,
    );
  }

  List<String> unassignedSceneIds(FilmDocument document) {
    final assigned = <String>{
      for (final day in document.shootingDays) ...day.sceneIds,
    };

    return document.sceneSections
        .where((scene) => !assigned.contains(scene.id))
        .map((scene) => scene.id)
        .toList(growable: false);
  }

  List<String> castForDay(FilmDocument document, ShootingDayPlan day) {
    final result = <String>{};

    for (final sceneId in day.sceneIds) {
      final scene = document.sceneById(sceneId);

      if (scene == null) {
        continue;
      }

      final data = suggestedBreakdown(document, scene);
      result.addAll(data.cast);
    }

    final sorted = result.toList(growable: false)..sort();
    return sorted;
  }

  List<String> propsForDay(FilmDocument document, ShootingDayPlan day) {
    final result = <String>{};

    for (final sceneId in day.sceneIds) {
      final scene = document.sceneById(sceneId);

      if (scene != null) {
        result.addAll(document.sceneProductionFor(scene.id).props);
      }
    }

    final sorted = result.toList(growable: false)..sort();
    return sorted;
  }

  int estimatedMinutesForDay(FilmDocument document, ShootingDayPlan day) {
    var total = 0;

    for (final sceneId in day.sceneIds) {
      final scene = document.sceneById(sceneId);

      if (scene == null) {
        continue;
      }

      final data = suggestedBreakdown(document, scene);
      total += data.estimatedSetupMinutes + data.estimatedShootMinutes;
    }

    return total;
  }

  String buildScheduleCsv(
    FilmDocument document, {
    required String projectName,
  }) {
    final lines = <String>[
      _csvRow(<Object?>['FILMSOZ SHOOTING SCHEDULE']),
      _csvRow(<Object?>['Проект', projectName]),
      '',
      _csvRow(<Object?>[
        'День',
        'Дата',
        'Статус',
        'Локация',
        'Сбор группы',
        'Первый кадр',
        'Окончание',
        'Сцены',
        'Персонажи',
        'Оценка минут',
        'Примечания',
      ]),
    ];

    for (final day in document.shootingDays) {
      final sceneNumbers = day.sceneIds.map((sceneId) {
        return document.sceneById(sceneId)?.number.toString() ?? '';
      }).where((value) => value.isNotEmpty);

      lines.add(
        _csvRow(<Object?>[
          day.title,
          day.date,
          day.status.label,
          day.location,
          day.crewCall,
          day.firstShot,
          day.estimatedWrap,
          sceneNumbers.join(', '),
          castForDay(document, day).join(', '),
          estimatedMinutesForDay(document, day),
          day.notes,
        ]),
      );
    }

    return '\uFEFF${lines.join('\r\n')}\r\n';
  }

  String buildCallSheetCsv(
    FilmDocument document, {
    required String projectName,
    required ShootingDayPlan day,
  }) {
    final lines = <String>[
      _csvRow(<Object?>['FILMSOZ CALL SHEET']),
      _csvRow(<Object?>['Проект', projectName]),
      _csvRow(<Object?>['Съёмочный день', day.title]),
      _csvRow(<Object?>['Дата', day.date]),
      _csvRow(<Object?>['Локация', day.location]),
      _csvRow(<Object?>['Сбор группы', day.crewCall]),
      _csvRow(<Object?>['Первый кадр', day.firstShot]),
      _csvRow(<Object?>['Плановое окончание', day.estimatedWrap]),
      _csvRow(<Object?>['Статус', day.status.label]),
      _csvRow(<Object?>['Примечания', day.notes]),
      '',
      _csvRow(<Object?>[
        '№ сцены',
        'Заголовок',
        'Локации',
        'Актёры',
        'Массовка',
        'Реквизит',
        'Костюмы',
        'Грим',
        'Транспорт',
        'Спецоборудование',
        'Подготовка, мин',
        'Съёмка, мин',
        'Приоритет',
        'Примечания',
      ]),
    ];

    for (final sceneId in day.sceneIds) {
      final scene = document.sceneById(sceneId);

      if (scene == null) {
        continue;
      }

      final data = suggestedBreakdown(document, scene);
      lines.add(
        _csvRow(<Object?>[
          scene.number,
          scene.title,
          data.locations.join(', '),
          data.cast.join(', '),
          data.extras,
          data.props.join(', '),
          data.costumes.join(', '),
          data.makeup.join(', '),
          data.vehicles.join(', '),
          data.specialEquipment.join(', '),
          data.estimatedSetupMinutes,
          data.estimatedShootMinutes,
          data.priority.label,
          data.notes,
        ]),
      );
    }

    lines
      ..add('')
      ..add(_csvRow(<Object?>['АКТЁРЫ ДНЯ']))
      ..add(_csvRow(<Object?>[castForDay(document, day).join(', ')]))
      ..add('')
      ..add(_csvRow(<Object?>['РЕКВИЗИТ ДНЯ']))
      ..add(_csvRow(<Object?>[propsForDay(document, day).join(', ')]));

    return '\uFEFF${lines.join('\r\n')}\r\n';
  }

  String _csvRow(List<Object?> values) {
    return values.map((value) {
      final text = value?.toString() ?? '';
      return '"${text.replaceAll('"', '""')}"';
    }).join(';');
  }
}
