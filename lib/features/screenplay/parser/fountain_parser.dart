import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';

/// Converts between Filmsoz screenplay blocks and the Fountain text format.
///
/// V8.1 covers the block types that currently exist in Filmsoz:
/// scene headings, action, character cues, dialogue, parentheticals,
/// and transitions.
class FountainParser {
  FountainParser._();

  static final RegExp _sceneHeadingPattern = RegExp(
    r'^(?:INT\.?/EXT|EXT\.?/INT|I/E|ИНТ\.?/НАТ|НАТ\.?/ИНТ|INT|EXT|EST|ИНТ|НАТ|ЭКСТ)(?:\.|\s)',
    caseSensitive: false,
    unicode: true,
  );

  static final RegExp _transitionPattern = RegExp(
    r'^(CUT TO:|SMASH CUT TO:|DISSOLVE TO:|FADE IN:|FADE OUT:|'
    r'MATCH CUT TO:|ПЕРЕХОД:|СКЛЕЙКА:|ЗАТЕМНЕНИЕ:)$',
    caseSensitive: false,
    unicode: true,
  );

  static final RegExp _titlePagePattern = RegExp(
    r'^(title|credit|author|authors|source|draft date|contact|copyright|'
    r'notes):\s*',
    caseSensitive: false,
  );

  static FilmDocument parse(String source) {
    final normalizedSource = _normalizeSource(source);
    final lines = normalizedSource.split('\n');
    final blocks = <FilmBlock>[];

    var dialogueMode = false;
    var previousWasBlank = true;
    var inBoneyard = false;
    var inTitlePage = true;
    var idCounter = 0;
    final idSeed = DateTime.now().microsecondsSinceEpoch;

    FilmBlock newBlock(BlockType type, String text) {
      return FilmBlock(
        id: '${idSeed}_${idCounter++}',
        type: type,
        text: text,
      );
    }

    void addActionLine(String text) {
      if (blocks.isNotEmpty &&
          blocks.last.type == BlockType.action &&
          !previousWasBlank) {
        blocks.last.text = '${blocks.last.text}\n$text';
      } else {
        blocks.add(newBlock(BlockType.action, text));
      }
    }

    void addDialogueLine(String text) {
      if (blocks.isNotEmpty && blocks.last.type == BlockType.dialogue) {
        blocks.last.text = '${blocks.last.text}\n$text';
      } else {
        blocks.add(newBlock(BlockType.dialogue, text));
      }
    }

    for (var index = 0; index < lines.length; index++) {
      final rawLine = lines[index].replaceFirst(RegExp(r'\s+$'), '');
      final line = rawLine.trim();

      if (inBoneyard) {
        if (line.contains('*/')) {
          inBoneyard = false;
        }
        continue;
      }

      if (line.startsWith('/*')) {
        if (!line.contains('*/') || line.indexOf('*/') < line.indexOf('/*')) {
          inBoneyard = true;
        }
        continue;
      }

      if (line.startsWith('//')) {
        continue;
      }

      if (line.isEmpty) {
        dialogueMode = false;
        previousWasBlank = true;
        inTitlePage = false;
        continue;
      }

      if (inTitlePage && _titlePagePattern.hasMatch(line)) {
        previousWasBlank = false;
        continue;
      }
      inTitlePage = false;

      if (dialogueMode) {
        if (_isParenthetical(line)) {
          blocks.add(newBlock(BlockType.parenthetical, line));
        } else {
          addDialogueLine(_stripForcedAction(line));
        }
        previousWasBlank = false;
        continue;
      }

      if (_isSceneHeading(line)) {
        blocks.add(
          newBlock(
            BlockType.sceneHeading,
            _cleanSceneHeading(line),
          ),
        );
        previousWasBlank = false;
        continue;
      }

      if (_isTransition(line)) {
        blocks.add(
          newBlock(
            BlockType.transition,
            _cleanTransition(line),
          ),
        );
        previousWasBlank = false;
        continue;
      }

      if (_isCharacterCue(line, lines, index)) {
        blocks.add(
          newBlock(
            BlockType.character,
            _cleanCharacterCue(line),
          ),
        );
        dialogueMode = true;
        previousWasBlank = false;
        continue;
      }

      if (_isParenthetical(line)) {
        blocks.add(newBlock(BlockType.parenthetical, line));
        previousWasBlank = false;
        continue;
      }

      addActionLine(_stripForcedAction(line));
      previousWasBlank = false;
    }

    if (blocks.isEmpty) {
      return FilmDocument.empty();
    }

    return FilmDocument(blocks: blocks);
  }

  static String exportToFountain(FilmDocument document) {
    final lines = <String>[];
    BlockType? previousType;

    void appendBlankLine() {
      if (lines.isNotEmpty && lines.last.isNotEmpty) {
        lines.add('');
      }
    }

    void appendTextLines(String text) {
      lines.addAll(
          text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n'));
    }

    for (final block in document.blocks) {
      final text = block.text.trim();
      if (text.isEmpty) {
        continue;
      }

      switch (block.type) {
        case BlockType.sceneHeading:
          appendBlankLine();
          appendTextLines(_sceneHeadingForExport(text));
          appendBlankLine();
          break;

        case BlockType.action:
          appendBlankLine();
          final actionLines = text.split('\n');
          for (final actionLine in actionLines) {
            lines.add(_actionLineForExport(actionLine));
          }
          appendBlankLine();
          break;

        case BlockType.character:
          appendBlankLine();
          lines.add(_characterForExport(text));
          break;

        case BlockType.parenthetical:
          if (previousType != BlockType.character &&
              previousType != BlockType.parenthetical) {
            appendBlankLine();
          }
          lines.add(_parentheticalForExport(text));
          break;

        case BlockType.dialogue:
          if (previousType != BlockType.character &&
              previousType != BlockType.parenthetical &&
              previousType != BlockType.dialogue) {
            appendBlankLine();
          }
          appendTextLines(text);
          break;

        case BlockType.transition:
          appendBlankLine();
          lines.add('>${_cleanTransition(text).toUpperCase()}');
          appendBlankLine();
          break;
      }

      previousType = block.type;
    }

    while (lines.isNotEmpty && lines.first.isEmpty) {
      lines.removeAt(0);
    }
    while (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }

    return lines.isEmpty ? '' : '${lines.join('\n')}\n';
  }

  static String _normalizeSource(String source) {
    return source
        .replaceFirst('\uFEFF', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
  }

  static bool _isSceneHeading(String line) {
    if (line.startsWith('.') && !line.startsWith('..')) {
      return true;
    }
    return _sceneHeadingPattern.hasMatch(line);
  }

  static String _cleanSceneHeading(String line) {
    final cleaned = line.startsWith('.') ? line.substring(1).trim() : line;
    return cleaned.toUpperCase();
  }

  static bool _isTransition(String line) {
    if (line.startsWith('>') && !line.endsWith('<')) {
      return true;
    }
    return _transitionPattern.hasMatch(line.toUpperCase()) ||
        (line == line.toUpperCase() && line.endsWith(' TO:'));
  }

  static String _cleanTransition(String line) {
    var cleaned = line.trim();
    if (cleaned.startsWith('>')) {
      cleaned = cleaned.substring(1).trimLeft();
    }
    return cleaned;
  }

  static bool _isCharacterCue(
    String line,
    List<String> lines,
    int currentIndex,
  ) {
    if (line.startsWith('@')) {
      return line.length > 1;
    }

    if (line.length < 2 || line.length > 45) {
      return false;
    }

    if (line != line.toUpperCase()) {
      return false;
    }

    if (line.endsWith(':') ||
        _isSceneHeading(line) ||
        _isTransition(line) ||
        line.startsWith('!') ||
        line.startsWith('#') ||
        line.startsWith('=')) {
      return false;
    }

    final nextLine = _nextNonEmptyLine(lines, currentIndex + 1);
    if (nextLine == null) {
      return false;
    }

    return !_isSceneHeading(nextLine) && !_isTransition(nextLine);
  }

  static String? _nextNonEmptyLine(List<String> lines, int startIndex) {
    for (var index = startIndex; index < lines.length; index++) {
      final candidate = lines[index].trim();
      if (candidate.isNotEmpty) {
        return candidate;
      }
    }
    return null;
  }

  static String _cleanCharacterCue(String line) {
    var cleaned = line.trim();
    if (cleaned.startsWith('@')) {
      cleaned = cleaned.substring(1).trimLeft();
    }
    if (cleaned.endsWith('^')) {
      cleaned = cleaned.substring(0, cleaned.length - 1).trimRight();
    }
    return cleaned;
  }

  static bool _isParenthetical(String line) {
    return line.length >= 2 && line.startsWith('(') && line.endsWith(')');
  }

  static String _stripForcedAction(String line) {
    return line.startsWith('!') ? line.substring(1).trimLeft() : line;
  }

  static String _sceneHeadingForExport(String text) {
    final clean = text.trim();
    if (_sceneHeadingPattern.hasMatch(clean)) {
      return clean.toUpperCase();
    }
    return '.${clean.toUpperCase()}';
  }

  static String _characterForExport(String text) {
    var clean = text.trim();
    if (clean.startsWith('@')) {
      clean = clean.substring(1).trimLeft();
    }
    return clean.toUpperCase();
  }

  static String _parentheticalForExport(String text) {
    final clean = text.trim();
    if (_isParenthetical(clean)) {
      return clean;
    }
    return '($clean)';
  }

  static String _actionLineForExport(String text) {
    final clean = text.trimRight();
    if (clean.isEmpty) {
      return '';
    }

    final trimmed = clean.trimLeft();
    final mayBeMisread = _isSceneHeading(trimmed) ||
        _isTransition(trimmed) ||
        trimmed.startsWith('@') ||
        trimmed.startsWith('.') ||
        trimmed.startsWith('>') ||
        (trimmed.length <= 45 &&
            trimmed.length > 1 &&
            trimmed == trimmed.toUpperCase());

    return mayBeMisread ? '!$clean' : clean;
  }
}
