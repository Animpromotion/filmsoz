import 'dart:convert';

import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';

class FilmsozProjectIssue {
  const FilmsozProjectIssue({
    required this.code,
    required this.message,
    this.isError = false,
  });

  final String code;
  final String message;
  final bool isError;
}

class FilmsozProjectDiagnosticReport {
  const FilmsozProjectDiagnosticReport({
    required this.issues,
    required this.blockCount,
    required this.sceneCount,
    required this.approximateBytes,
    required this.orphanRecordCount,
  });

  final List<FilmsozProjectIssue> issues;
  final int blockCount;
  final int sceneCount;
  final int approximateBytes;
  final int orphanRecordCount;

  bool get isHealthy => issues.every((issue) => !issue.isError);
  bool get hasIssues => issues.isNotEmpty;
}

class FilmsozProjectOptimizationResult {
  const FilmsozProjectOptimizationResult({
    required this.document,
    required this.beforeBytes,
    required this.afterBytes,
    required this.removedRecords,
    required this.messages,
  });

  final FilmDocument document;
  final int beforeBytes;
  final int afterBytes;
  final int removedRecords;
  final List<String> messages;

  int get savedBytes => beforeBytes - afterBytes;
}

class FilmsozProjectDiagnosticsService {
  const FilmsozProjectDiagnosticsService();

  FilmsozProjectDiagnosticReport inspect(FilmDocument document) {
    final issues = <FilmsozProjectIssue>[];
    final seenIds = <String>{};
    var duplicateIds = 0;

    for (final block in document.blocks) {
      if (block.id.trim().isEmpty || !seenIds.add(block.id)) {
        duplicateIds++;
      }
    }

    if (duplicateIds > 0) {
      issues.add(
        FilmsozProjectIssue(
          code: 'duplicate_block_ids',
          message: 'Найдены повторяющиеся или пустые ID блоков: $duplicateIds.',
          isError: true,
        ),
      );
    }

    if (document.blocks.isEmpty) {
      issues.add(
        const FilmsozProjectIssue(
          code: 'empty_document',
          message: 'В проекте нет сценарных блоков.',
          isError: true,
        ),
      );
    }

    if (document.blocks.isNotEmpty &&
        document.blocks.first.type != BlockType.sceneHeading) {
      issues.add(
        const FilmsozProjectIssue(
          code: 'missing_first_scene',
          message: 'Проект начинается не с заголовка сцены.',
        ),
      );
    }

    final emptySceneHeadings = document.sceneSections
        .where((scene) => scene.heading.text.trim().isEmpty)
        .length;

    if (emptySceneHeadings > 0) {
      issues.add(
        FilmsozProjectIssue(
          code: 'empty_scene_headings',
          message: 'Пустые заголовки сцен: $emptySceneHeadings.',
        ),
      );
    }

    final validSceneIds =
        document.sceneSections.map((scene) => scene.id).toSet();
    final validDayIds = document.shootingDays.map((day) => day.id).toSet();
    final validShotIds = <String>{
      for (final shots in document.storyboardShots.values)
        for (final shot in shots) shot.id,
    };
    var orphanRecords = 0;

    orphanRecords += document.sceneNotes.keys
        .where((id) => !validSceneIds.contains(id))
        .length;
    orphanRecords += document.sceneDevelopment.keys
        .where((id) => !validSceneIds.contains(id))
        .length;
    orphanRecords += document.sceneProduction.keys
        .where((id) => !validSceneIds.contains(id))
        .length;
    orphanRecords += document.storyboardShots.keys
        .where((id) => !validSceneIds.contains(id))
        .length;
    orphanRecords += document.scenePostProduction.keys
        .where((id) => !validSceneIds.contains(id))
        .length;
    orphanRecords += document.shotTakes.keys
        .where((id) => !validShotIds.contains(id))
        .length;
    orphanRecords += document.shootingDayJournals.keys
        .where((id) => !validDayIds.contains(id))
        .length;

    if (orphanRecords > 0) {
      issues.add(
        FilmsozProjectIssue(
          code: 'orphan_records',
          message: 'Найдены устаревшие связанные записи: $orphanRecords.',
        ),
      );
    }

    if (document.projectCheckpoints.length > 50) {
      issues.add(
        FilmsozProjectIssue(
          code: 'many_checkpoints',
          message: 'Контрольных версий слишком много: '
              '${document.projectCheckpoints.length}.',
        ),
      );
    }

    final approximateBytes = utf8.encode(jsonEncode(document.toJson())).length;

    if (approximateBytes > 50 * 1024 * 1024) {
      issues.add(
        const FilmsozProjectIssue(
          code: 'large_project',
          message: 'Размер проекта превышает 50 МБ. Рекомендуется оптимизация.',
        ),
      );
    }

    if (issues.isEmpty) {
      issues.add(
        const FilmsozProjectIssue(
          code: 'healthy',
          message: 'Структура проекта выглядит исправной.',
        ),
      );
    }

    return FilmsozProjectDiagnosticReport(
      issues: List<FilmsozProjectIssue>.unmodifiable(issues),
      blockCount: document.blocks.length,
      sceneCount: document.sceneSections.length,
      approximateBytes: approximateBytes,
      orphanRecordCount: orphanRecords,
    );
  }

  FilmsozProjectOptimizationResult optimize(
    FilmDocument document, {
    int maxCheckpoints = 30,
    int maxChangeLogEntries = 300,
  }) {
    final beforeJson = document.toJson();
    final beforeBytes = utf8.encode(jsonEncode(beforeJson)).length;
    final json = _deepCopy(beforeJson);
    final messages = <String>[];
    var removed = 0;

    final blocks = _mapList(json['blocks']);
    final seenBlockIds = <String>{};
    var generatedId = 0;

    for (final block in blocks) {
      final currentId = block['id']?.toString().trim() ?? '';

      if (currentId.isEmpty || !seenBlockIds.add(currentId)) {
        String replacement;

        do {
          generatedId++;
          replacement = 'repaired_block_$generatedId';
        } while (!seenBlockIds.add(replacement));

        block['id'] = replacement;
        messages.add('Исправлен ID сценарного блока.');
      }
    }

    if (blocks.isEmpty || blocks.first['type']?.toString() != 'sceneHeading') {
      var sceneIdIndex = 1;
      var sceneId = 'repaired_scene_$sceneIdIndex';

      while (seenBlockIds.contains(sceneId)) {
        sceneIdIndex++;
        sceneId = 'repaired_scene_$sceneIdIndex';
      }

      seenBlockIds.add(sceneId);
      blocks.insert(0, <String, dynamic>{
        'id': sceneId,
        'type': 'sceneHeading',
        'text': 'ИНТ. СТУДИЯ - ДЕНЬ',
      });
      messages.add('Добавлен стартовый заголовок сцены.');
    }

    json['blocks'] = blocks;
    final validSceneIds = blocks
        .where((block) => block['type']?.toString() == 'sceneHeading')
        .map((block) => block['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    for (final key in <String>[
      'sceneNotes',
      'sceneDevelopment',
      'sceneProduction',
      'storyboardShots',
      'scenePostProduction',
    ]) {
      final map = _stringMap(json[key]);
      final staleKeys = map.keys
          .where((sceneId) => !validSceneIds.contains(sceneId))
          .toList(growable: false);
      removed += staleKeys.length;

      for (final staleKey in staleKeys) {
        map.remove(staleKey);
      }

      json[key] = map;
    }

    final shotsMap = _stringMap(json['storyboardShots']);
    final validShotIds = <String>{};

    for (final entry in shotsMap.entries) {
      final shots = _mapList(entry.value);

      for (final shot in shots) {
        final shotId = shot['id']?.toString().trim() ?? '';

        if (shotId.isNotEmpty) {
          validShotIds.add(shotId);
        }

        final image = shot['imageBase64']?.toString();

        if (image != null && image.isNotEmpty && !_isValidBase64(image)) {
          shot.remove('imageBase64');
          shot.remove('imageFileName');
          shot.remove('imageMimeType');
          removed++;
          messages.add('Удалено повреждённое изображение раскадровки.');
        }
      }

      shotsMap[entry.key] = shots;
    }

    json['storyboardShots'] = shotsMap;
    final takesMap = _stringMap(json['shotTakes']);
    final staleTakeKeys = takesMap.keys
        .where((shotId) => !validShotIds.contains(shotId))
        .toList(growable: false);
    removed += staleTakeKeys.length;

    for (final staleKey in staleTakeKeys) {
      takesMap.remove(staleKey);
    }

    for (final entry in takesMap.entries) {
      final takes = _mapList(entry.value);

      for (final take in takes) {
        final photos = _mapList(take['continuityPhotos']);
        final validPhotos = photos.where((photo) {
          final data = photo['base64Data']?.toString() ?? '';
          final valid = data.isEmpty || _isValidBase64(data);

          if (!valid) {
            removed++;
          }

          return valid;
        }).toList(growable: false);
        take['continuityPhotos'] = validPhotos;
      }

      takesMap[entry.key] = takes;
    }

    json['shotTakes'] = takesMap;
    final validDayIds = _mapList(json['shootingDays'])
        .map((day) => day['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final journals = _stringMap(json['shootingDayJournals']);
    final staleJournalKeys = journals.keys
        .where((dayId) => !validDayIds.contains(dayId))
        .toList(growable: false);
    removed += staleJournalKeys.length;

    for (final staleKey in staleJournalKeys) {
      journals.remove(staleKey);
    }

    json['shootingDayJournals'] = journals;
    final checkpoints = _mapList(json['projectCheckpoints']);
    final safeCheckpointLimit = maxCheckpoints.clamp(1, 100).toInt();

    if (checkpoints.length > safeCheckpointLimit) {
      removed += checkpoints.length - safeCheckpointLimit;
      json['projectCheckpoints'] = checkpoints
          .skip(checkpoints.length - safeCheckpointLimit)
          .toList(growable: false);
      messages.add('Старые контрольные версии сокращены.');
    }

    final changeLog = _mapList(json['projectChangeLog']);
    final safeLogLimit = maxChangeLogEntries.clamp(20, 500).toInt();

    if (changeLog.length > safeLogLimit) {
      removed += changeLog.length - safeLogLimit;
      json['projectChangeLog'] = changeLog
          .skip(changeLog.length - safeLogLimit)
          .toList(growable: false);
      messages.add('Старые записи журнала изменений сокращены.');
    }

    final optimized = FilmDocument.fromJson(json);
    final afterBytes = utf8.encode(jsonEncode(optimized.toJson())).length;

    if (messages.isEmpty) {
      messages.add('Оптимизация не обнаружила лишних данных.');
    }

    return FilmsozProjectOptimizationResult(
      document: optimized,
      beforeBytes: beforeBytes,
      afterBytes: afterBytes,
      removedRecords: removed,
      messages: List<String>.unmodifiable(messages),
    );
  }

  Map<String, dynamic> _deepCopy(Map<String, dynamic> json) {
    final decoded = jsonDecode(jsonEncode(json));
    return (decoded as Map).map(
      (key, value) => MapEntry(key.toString(), value),
    );
  }

  Map<String, dynamic> _stringMap(Object? value) {
    if (value is! Map) {
      return <String, dynamic>{};
    }

    return value.map(
      (key, item) => MapEntry(key.toString(), item),
    );
  }

  List<Map<String, dynamic>> _mapList(Object? value) {
    if (value is! List) {
      return <Map<String, dynamic>>[];
    }

    return value.whereType<Map>().map((item) {
      return item.map(
        (key, data) => MapEntry(key.toString(), data),
      );
    }).toList(growable: true);
  }

  bool _isValidBase64(String value) {
    try {
      base64Decode(value);
      return true;
    } on FormatException {
      return false;
    }
  }
}
