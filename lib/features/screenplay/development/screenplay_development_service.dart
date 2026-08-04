import 'dart:math' as math;

import 'package:filmsoz_studio/features/screenplay/development/scene_development.dart';
import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/document/scene_section.dart';

class CharacterDevelopmentStat {
  const CharacterDevelopmentStat({
    required this.name,
    required this.sceneCount,
    required this.dialogueCount,
    required this.dialogueWords,
  });

  final String name;
  final int sceneCount;
  final int dialogueCount;
  final int dialogueWords;
}

class LocationDevelopmentStat {
  const LocationDevelopmentStat({
    required this.location,
    required this.sceneCount,
    required this.estimatedMinutes,
  });

  final String location;
  final int sceneCount;
  final double estimatedMinutes;
}

class ScreenplayDevelopmentSummary {
  const ScreenplayDevelopmentSummary({
    required this.sceneCount,
    required this.wordCount,
    required this.estimatedPages,
    required this.estimatedMinutes,
    required this.readySceneCount,
  });

  final int sceneCount;
  final int wordCount;
  final double estimatedPages;
  final double estimatedMinutes;
  final int readySceneCount;
}

class ScreenplayDevelopmentService {
  const ScreenplayDevelopmentService();

  static const double wordsPerEstimatedPage = 180;
  static const double wordsPerEstimatedMinute = 135;

  String locationForScene(SceneSection scene) {
    var value = scene.title.trim();
    value = value.replaceFirst(
      RegExp(
        r'^(?:\.?)(?:ИНТ\.?/НАТ\.?|ИНТ\.?/ЭКСТ\.?|INT\.?/EXT\.?|ИНТ\.?|НАТ\.?|ЭКСТ\.?|INT\.?|EXT\.?)\s*',
        caseSensitive: false,
      ),
      '',
    );

    final dashMatch = RegExp(r'\s+(?:-|—|–)\s+').firstMatch(value);

    if (dashMatch != null) {
      value = value.substring(0, dashMatch.start);
    }

    value = value.trim();
    return value.isEmpty ? 'БЕЗ ЛОКАЦИИ' : value.toUpperCase();
  }

  List<String> charactersForScene(SceneSection scene) {
    final result = <String>{};

    for (final block in scene.blocks) {
      if (block.type != BlockType.character) {
        continue;
      }

      final name = normalizeCharacterName(block.text);

      if (name.isNotEmpty) {
        result.add(name);
      }
    }

    final sorted = result.toList(growable: false)..sort();
    return sorted;
  }

  String normalizeCharacterName(String value) {
    var normalized = value.trim().toUpperCase();
    normalized = normalized.replaceFirst(RegExp(r'^@'), '');
    normalized = normalized.replaceFirst(RegExp(r'\s*\([^)]*\)\s*$'), '');
    return normalized.trim();
  }

  double estimatedMinutesForScene(SceneSection scene) {
    if (scene.wordCount <= 0) {
      return 0;
    }

    return math.max(0.1, scene.wordCount / wordsPerEstimatedMinute);
  }

  double estimatedPagesForScene(SceneSection scene) {
    if (scene.wordCount <= 0) {
      return 0;
    }

    return math.max(0.1, scene.wordCount / wordsPerEstimatedPage);
  }

  ScreenplayDevelopmentSummary summarize(FilmDocument document) {
    final scenes = document.sceneSections;
    final words = scenes.fold<int>(
      0,
      (total, scene) => total + scene.wordCount,
    );
    final readyCount = scenes.where((scene) {
      return document.sceneDevelopmentFor(scene.id).status ==
          SceneWorkStatus.ready;
    }).length;

    return ScreenplayDevelopmentSummary(
      sceneCount: scenes.length,
      wordCount: words,
      estimatedPages: scenes.fold<double>(
        0,
        (total, scene) => total + estimatedPagesForScene(scene),
      ),
      estimatedMinutes: scenes.fold<double>(
        0,
        (total, scene) => total + estimatedMinutesForScene(scene),
      ),
      readySceneCount: readyCount,
    );
  }

  List<CharacterDevelopmentStat> characterReport(FilmDocument document) {
    final sceneIdsByCharacter = <String, Set<String>>{};
    final dialogueCount = <String, int>{};
    final dialogueWords = <String, int>{};

    for (final scene in document.sceneSections) {
      String? currentCharacter;

      for (final block in scene.blocks) {
        if (block.type == BlockType.character) {
          final name = normalizeCharacterName(block.text);
          currentCharacter = name.isEmpty ? null : name;

          if (currentCharacter != null) {
            sceneIdsByCharacter
                .putIfAbsent(currentCharacter, () => <String>{})
                .add(scene.id);
          }
          continue;
        }

        if (block.type == BlockType.dialogue && currentCharacter != null) {
          dialogueCount.update(
            currentCharacter,
            (value) => value + 1,
            ifAbsent: () => 1,
          );
          dialogueWords.update(
            currentCharacter,
            (value) => value + _wordCount(block.text),
            ifAbsent: () => _wordCount(block.text),
          );
          continue;
        }

        if (block.type != BlockType.parenthetical) {
          currentCharacter = null;
        }
      }
    }

    final names = <String>{
      ...sceneIdsByCharacter.keys,
      ...dialogueCount.keys,
    }.toList(growable: false)
      ..sort();

    return names
        .map(
          (name) => CharacterDevelopmentStat(
            name: name,
            sceneCount: sceneIdsByCharacter[name]?.length ?? 0,
            dialogueCount: dialogueCount[name] ?? 0,
            dialogueWords: dialogueWords[name] ?? 0,
          ),
        )
        .toList(growable: false);
  }

  List<LocationDevelopmentStat> locationReport(FilmDocument document) {
    final sceneCount = <String, int>{};
    final minutes = <String, double>{};

    for (final scene in document.sceneSections) {
      final location = locationForScene(scene);
      sceneCount.update(location, (value) => value + 1, ifAbsent: () => 1);
      minutes.update(
        location,
        (value) => value + estimatedMinutesForScene(scene),
        ifAbsent: () => estimatedMinutesForScene(scene),
      );
    }

    final locations = sceneCount.keys.toList(growable: false)..sort();

    return locations
        .map(
          (location) => LocationDevelopmentStat(
            location: location,
            sceneCount: sceneCount[location] ?? 0,
            estimatedMinutes: minutes[location] ?? 0,
          ),
        )
        .toList(growable: false);
  }

  List<SceneSection> filterScenes(
    FilmDocument document, {
    String query = '',
    SceneWorkStatus? status,
    SceneColorTag? colorTag,
    String? character,
    String? location,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final normalizedCharacter = character?.trim().toUpperCase();
    final normalizedLocation = location?.trim().toUpperCase();

    return document.sceneSections.where((scene) {
      final metadata = document.sceneDevelopmentFor(scene.id);
      final sceneCharacters = charactersForScene(scene);
      final sceneLocation = locationForScene(scene);

      if (normalizedQuery.isNotEmpty) {
        final searchText = <String>[
          scene.number.toString(),
          scene.title,
          metadata.summary,
          sceneLocation,
          ...sceneCharacters,
          ...scene.blocks.map((block) => block.text),
        ].join('\n').toLowerCase();

        if (!searchText.contains(normalizedQuery)) {
          return false;
        }
      }

      if (status != null && metadata.status != status) {
        return false;
      }

      if (colorTag != null && metadata.colorTag != colorTag) {
        return false;
      }

      if (normalizedCharacter != null &&
          normalizedCharacter.isNotEmpty &&
          !sceneCharacters.contains(normalizedCharacter)) {
        return false;
      }

      if (normalizedLocation != null &&
          normalizedLocation.isNotEmpty &&
          sceneLocation != normalizedLocation) {
        return false;
      }

      return true;
    }).toList(growable: false);
  }

  String buildProductionReportCsv(
    FilmDocument document, {
    required String projectName,
  }) {
    final summary = summarize(document);
    final lines = <String>[
      _csvRow(<Object?>['FILMSOZ PRODUCTION REPORT']),
      _csvRow(<Object?>['Проект', projectName]),
      _csvRow(<Object?>['Сцен', summary.sceneCount]),
      _csvRow(<Object?>['Слов', summary.wordCount]),
      _csvRow(<Object?>['Оценка страниц', _decimal(summary.estimatedPages)]),
      _csvRow(<Object?>['Оценка минут', _decimal(summary.estimatedMinutes)]),
      _csvRow(<Object?>['Готовых сцен', summary.readySceneCount]),
      '',
      _csvRow(<Object?>[
        '№',
        'Заголовок',
        'Локация',
        'Статус',
        'Сюжетная линия',
        'Краткое описание',
        'Слов',
        'Оценка минут',
        'Персонажи',
      ]),
    ];

    for (final scene in document.sceneSections) {
      final metadata = document.sceneDevelopmentFor(scene.id);
      lines.add(
        _csvRow(<Object?>[
          scene.number,
          scene.title,
          locationForScene(scene),
          metadata.status.label,
          metadata.colorTag.label,
          metadata.summary,
          scene.wordCount,
          _decimal(estimatedMinutesForScene(scene)),
          charactersForScene(scene).join(', '),
        ]),
      );
    }

    lines
      ..add('')
      ..add(_csvRow(<Object?>['ПЕРСОНАЖИ']))
      ..add(
        _csvRow(<Object?>[
          'Персонаж',
          'Сцен',
          'Реплик',
          'Слов в репликах',
        ]),
      );

    for (final stat in characterReport(document)) {
      lines.add(
        _csvRow(<Object?>[
          stat.name,
          stat.sceneCount,
          stat.dialogueCount,
          stat.dialogueWords,
        ]),
      );
    }

    lines
      ..add('')
      ..add(_csvRow(<Object?>['ЛОКАЦИИ']))
      ..add(
        _csvRow(<Object?>[
          'Локация',
          'Сцен',
          'Оценка минут',
        ]),
      );

    for (final stat in locationReport(document)) {
      lines.add(
        _csvRow(<Object?>[
          stat.location,
          stat.sceneCount,
          _decimal(stat.estimatedMinutes),
        ]),
      );
    }

    return '\uFEFF${lines.join('\r\n')}\r\n';
  }

  int _wordCount(String value) {
    return RegExp(r'\S+').allMatches(value.trim()).length;
  }

  String _decimal(double value) =>
      value.toStringAsFixed(1).replaceAll('.', ',');

  String _csvRow(List<Object?> values) {
    return values.map((value) {
      final text = value?.toString() ?? '';
      final escaped = text.replaceAll('"', '""');
      return '"$escaped"';
    }).join(';');
  }
}
