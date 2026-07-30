import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';

class CharacterStatistic {
  const CharacterStatistic({
    required this.name,
    required this.characterBlocks,
    required this.dialogueBlocks,
    required this.dialogueWords,
    required this.firstBlockId,
  });

  final String name;
  final int characterBlocks;
  final int dialogueBlocks;
  final int dialogueWords;
  final String firstBlockId;
}

class ScreenplayProductivityService {
  const ScreenplayProductivityService();

  List<CharacterStatistic> characterStatistics(FilmDocument document) {
    final mutable = <String, _MutableCharacterStatistic>{};

    for (var index = 0; index < document.blocks.length; index++) {
      final block = document.blocks[index];

      if (block.type != BlockType.character) {
        continue;
      }

      final name = normalizeCharacterName(block.text);

      if (name.isEmpty) {
        continue;
      }

      final statistic = mutable.putIfAbsent(
        name,
        () => _MutableCharacterStatistic(
          name: name,
          firstBlockId: block.id,
        ),
      );

      statistic.characterBlocks++;

      var nextIndex = index + 1;

      while (nextIndex < document.blocks.length &&
          document.blocks[nextIndex].type == BlockType.parenthetical) {
        nextIndex++;
      }

      if (nextIndex < document.blocks.length &&
          document.blocks[nextIndex].type == BlockType.dialogue) {
        statistic.dialogueBlocks++;
        statistic.dialogueWords += _wordCount(document.blocks[nextIndex].text);
      }
    }

    final result = mutable.values
        .map(
          (value) => CharacterStatistic(
            name: value.name,
            characterBlocks: value.characterBlocks,
            dialogueBlocks: value.dialogueBlocks,
            dialogueWords: value.dialogueWords,
            firstBlockId: value.firstBlockId,
          ),
        )
        .toList(growable: false);

    result.sort((first, second) {
      final dialogueComparison = second.dialogueBlocks.compareTo(
        first.dialogueBlocks,
      );

      if (dialogueComparison != 0) {
        return dialogueComparison;
      }

      return first.name.compareTo(second.name);
    });

    return result;
  }

  List<String> characterSuggestions(
    FilmDocument document, {
    String query = '',
    String? excludeBlockId,
    int limit = 5,
  }) {
    final normalizedQuery = normalizeCharacterName(query);
    final names = <String>[];

    for (final statistic in characterStatistics(document)) {
      if (normalizedQuery.isNotEmpty &&
          !statistic.name.startsWith(normalizedQuery) &&
          !statistic.name.contains(normalizedQuery)) {
        continue;
      }

      if (statistic.name == normalizedQuery) {
        continue;
      }

      names.add(statistic.name);

      if (names.length >= limit) {
        break;
      }
    }

    return names;
  }

  List<String> locationSuggestions(
    FilmDocument document, {
    String query = '',
    String? excludeBlockId,
    int limit = 5,
  }) {
    final normalizedQuery = query.trim().toUpperCase();
    final frequency = <String, int>{};

    for (final block in document.blocks) {
      if (block.type != BlockType.sceneHeading || block.id == excludeBlockId) {
        continue;
      }

      final location = extractLocation(block.text);

      if (location.isEmpty) {
        continue;
      }

      frequency[location] = (frequency[location] ?? 0) + 1;
    }

    final locations = frequency.keys.where((location) {
      if (normalizedQuery.isEmpty) {
        return true;
      }

      return location.startsWith(normalizedQuery) ||
          location.contains(normalizedQuery);
    }).toList(growable: false)
      ..sort((first, second) {
        final frequencyComparison = (frequency[second] ?? 0).compareTo(
          frequency[first] ?? 0,
        );

        if (frequencyComparison != 0) {
          return frequencyComparison;
        }

        return first.compareTo(second);
      });

    return locations.take(limit).toList(growable: false);
  }

  String normalizeCharacterName(String value) {
    var result = value.trim().replaceFirst(RegExp(r'^@+'), '');
    result = result.replaceFirst(RegExp(r'\s*\([^)]*\)\s*$'), '');
    result = result.replaceAll(RegExp(r'\s+'), ' ');
    return result.toUpperCase();
  }

  String extractLocation(String heading) {
    final parts = _sceneHeadingParts(heading);
    return parts.location.trim().toUpperCase();
  }

  String locationQuery(String heading) {
    final query = _sceneHeadingParts(heading).location.trim().toUpperCase();

    if (query == 'ЛОКАЦИЯ' || query == 'LOCATION') {
      return '';
    }

    return query;
  }

  String applyLocationSuggestion(String heading, String location) {
    final parts = _sceneHeadingParts(heading);
    final normalizedLocation = location.trim().toUpperCase();

    if (normalizedLocation.isEmpty) {
      return heading;
    }

    final prefix = parts.prefix.isEmpty ? 'ИНТ. ' : parts.prefix;
    final suffix = parts.suffix.isEmpty ? ' - ДЕНЬ' : parts.suffix;
    return '$prefix$normalizedLocation$suffix';
  }

  int countMatches(
    FilmDocument document,
    String query, {
    bool matchCase = false,
  }) {
    final normalizedQuery = query.trim();

    if (normalizedQuery.isEmpty) {
      return 0;
    }

    final expression = RegExp(
      RegExp.escape(normalizedQuery),
      caseSensitive: matchCase,
    );
    var count = 0;

    for (final block in document.blocks) {
      count += expression.allMatches(block.text).length;
    }

    return count;
  }

  _SceneHeadingParts _sceneHeadingParts(String heading) {
    final normalized = heading.trim();
    final prefixExpression = RegExp(
      r'^(?:(?:ИНТ|НАТ|ЭКСТ|INT|EXT)\.?(?:\s*/\s*(?:ИНТ|НАТ|ЭКСТ|INT|EXT)\.?)?)\s*',
      caseSensitive: false,
    );
    final prefixMatch = prefixExpression.firstMatch(normalized);
    final prefix = prefixMatch?.group(0) ?? '';
    final bodyStart = prefixMatch?.end ?? 0;
    final body = normalized.substring(bodyStart);
    final separatorExpression = RegExp(r'\s+[-—–]\s+');
    final separators = separatorExpression.allMatches(body).toList();

    if (separators.isEmpty) {
      return _SceneHeadingParts(
        prefix: prefix,
        location: body,
        suffix: '',
      );
    }

    final separator = separators.last;

    return _SceneHeadingParts(
      prefix: prefix,
      location: body.substring(0, separator.start),
      suffix: body.substring(separator.start),
    );
  }

  int _wordCount(String text) {
    return RegExp(r'\S+').allMatches(text.trim()).length;
  }
}

class _MutableCharacterStatistic {
  _MutableCharacterStatistic({
    required this.name,
    required this.firstBlockId,
  });

  final String name;
  final String firstBlockId;
  int characterBlocks = 0;
  int dialogueBlocks = 0;
  int dialogueWords = 0;
}

class _SceneHeadingParts {
  const _SceneHeadingParts({
    required this.prefix,
    required this.location,
    required this.suffix,
  });

  final String prefix;
  final String location;
  final String suffix;
}
