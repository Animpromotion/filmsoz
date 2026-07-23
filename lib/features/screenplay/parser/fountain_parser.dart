import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';

class FountainParser {
  static final RegExp _sceneHeaderRegExp = RegExp(
    r'^(INT|EXT|EST|INT\./EXT|EXT\./INT|ИНТ|ЭКСТ)\.?',
    caseSensitive: false,
  );

  static final RegExp _transitionRegExp = RegExp(
    r'^(CUT TO:|FADE IN:|FADE OUT:|ПЕРЕХОД:)',
    caseSensitive: false,
  );

  static FilmDocument parse(String text) {
    final lines = text.split('\n');
    final List<FilmBlock> blocks = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      BlockType type = BlockType.action;

      if (_sceneHeaderRegExp.hasMatch(line) || line.startsWith('.')) {
        type = BlockType.sceneHeading;
      } else if (_transitionRegExp.hasMatch(line) || line.startsWith('>')) {
        type = BlockType.transition;
      } else if (line == line.toUpperCase() &&
          !line.startsWith('.') &&
          line.length > 1) {
        type = BlockType.character;
      } else if (line.startsWith('(') && line.endsWith(')')) {
        type = BlockType.parenthetical;
      } else if (blocks.isNotEmpty &&
          (blocks.last.type == BlockType.character ||
              blocks.last.type == BlockType.parenthetical)) {
        type = BlockType.dialogue;
      }

      blocks.add(FilmBlock(
        id: '${i}_${DateTime.now().microsecondsSinceEpoch}',
        type: type,
        text: line.startsWith('.') || line.startsWith('>')
            ? line.substring(1).trim()
            : line,
      ));
    }

    return FilmDocument(blocks: blocks);
  }

  static String exportToFountain(FilmDocument document) {
    final buffer = StringBuffer();
    for (final block in document.blocks) {
      switch (block.type) {
        case BlockType.sceneHeading:
          buffer.writeln('\n${block.text.toUpperCase()}');
          break;
        case BlockType.character:
          buffer.writeln('\n${block.text.toUpperCase()}');
          break;
        case BlockType.parenthetical:
          buffer.writeln('(${block.text})');
          break;
        case BlockType.transition:
          buffer.writeln('\n> ${block.text.toUpperCase()}');
          break;
        default:
          buffer.writeln(block.text);
      }
    }
    return buffer.toString();
  }
}
