import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';

class SceneSection {
  const SceneSection({
    required this.number,
    required this.startIndex,
    required this.endIndexExclusive,
    required this.heading,
    required this.blocks,
  });

  final int number;
  final int startIndex;
  final int endIndexExclusive;
  final FilmBlock heading;
  final List<FilmBlock> blocks;

  String get id => heading.id;

  String get title {
    final value = heading.text.trim();
    return value.isEmpty ? 'БЕЗ НАЗВАНИЯ' : value;
  }

  int get blockCount => blocks.length;

  int get contentBlockCount => blocks.length > 1 ? blocks.length - 1 : 0;

  int get wordCount {
    var count = 0;

    for (final block in blocks) {
      count += RegExp(r'\S+').allMatches(block.text.trim()).length;
    }

    return count;
  }

  int get characterCount {
    var count = 0;

    for (final block in blocks) {
      count += block.text.length;
    }

    return count;
  }

  List<String> get blockIds {
    return blocks.map((block) => block.id).toList(growable: false);
  }

  String get searchableText {
    return <String>[
      number.toString(),
      ...blocks.map((block) => block.text),
    ].join('\n').toLowerCase();
  }

  bool matchesQuery(String query) {
    final normalizedQuery = query.trim().toLowerCase();

    if (normalizedQuery.isEmpty) {
      return true;
    }

    return searchableText.contains(normalizedQuery);
  }
}
