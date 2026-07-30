import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';

class SmartFormattingResult {
  const SmartFormattingResult({
    required this.text,
    required this.type,
  });

  final String text;
  final BlockType type;
}

class SmartFormattingService {
  const SmartFormattingService();

  static const List<String> _scenePrefixes = <String>[
    'INT./EXT.',
    'EXT./INT.',
    'ИНТ./НАТ.',
    'НАТ./ИНТ.',
    'ИНТ/НАТ.',
    'НАТ/ИНТ.',
    'INT.',
    'EXT.',
    'I/E.',
    'ИНТ.',
    'НАТ.',
    'ЭКСТ.',
    'СЦЕНА ',
  ];

  static const Set<String> _knownTransitions = <String>{
    'CUT TO:',
    'SMASH CUT TO:',
    'MATCH CUT TO:',
    'DISSOLVE TO:',
    'FADE IN:',
    'FADE OUT:',
    'FADE TO BLACK:',
    'СКЛЕЙКА:',
    'ПЕРЕХОД:',
    'ЗАТЕМНЕНИЕ:',
    'НАПЛЫВ:',
  };

  BlockType detectLiveType({
    required String text,
    required BlockType currentType,
    BlockType? previousType,
  }) {
    final trimmed = text.trimLeft();

    if (trimmed.isEmpty) {
      return currentType;
    }

    final forcedType = _forcedType(trimmed);
    if (forcedType != null) {
      return forcedType;
    }

    if (_looksLikeSceneHeading(trimmed)) {
      return BlockType.sceneHeading;
    }

    if (trimmed.startsWith('(')) {
      return BlockType.parenthetical;
    }

    if (_looksLikeTransition(trimmed)) {
      return BlockType.transition;
    }

    if (currentType == BlockType.action &&
        (previousType == BlockType.character ||
            previousType == BlockType.parenthetical)) {
      return BlockType.dialogue;
    }

    return currentType;
  }

  SmartFormattingResult finalizeBlock({
    required String text,
    required BlockType currentType,
    BlockType? previousType,
  }) {
    var normalizedText = text.trimRight();
    var resolvedType = currentType;

    final trimmedLeft = normalizedText.trimLeft();
    final forcedType = _forcedType(trimmedLeft);

    if (forcedType != null) {
      resolvedType = forcedType;
      normalizedText = _removeForcedMarker(trimmedLeft);
    } else if (_looksLikeSceneHeading(trimmedLeft)) {
      resolvedType = BlockType.sceneHeading;
      normalizedText = trimmedLeft;
    } else if (trimmedLeft.startsWith('(')) {
      resolvedType = BlockType.parenthetical;
      normalizedText = trimmedLeft;
    } else if (_looksLikeTransition(trimmedLeft)) {
      resolvedType = BlockType.transition;
      normalizedText = trimmedLeft;
    } else if (currentType == BlockType.action &&
        (previousType == BlockType.character ||
            previousType == BlockType.parenthetical)) {
      resolvedType = BlockType.dialogue;
      normalizedText = trimmedLeft;
    } else if (currentType == BlockType.action &&
        _looksLikeCharacter(trimmedLeft)) {
      resolvedType = BlockType.character;
      normalizedText = trimmedLeft;
    }

    normalizedText = _normalizeForType(
      normalizedText,
      resolvedType,
    );

    return SmartFormattingResult(
      text: normalizedText,
      type: resolvedType,
    );
  }

  BlockType? _forcedType(String text) {
    if (text.startsWith('@')) {
      return BlockType.character;
    }

    if (text.startsWith('!')) {
      return BlockType.action;
    }

    if (text.startsWith('>')) {
      return BlockType.transition;
    }

    if (text.startsWith('.') && text.length > 1) {
      return BlockType.sceneHeading;
    }

    return null;
  }

  String _removeForcedMarker(String text) {
    if (text.isEmpty) {
      return text;
    }

    final firstCharacter = text[0];

    if (firstCharacter == '@' ||
        firstCharacter == '!' ||
        firstCharacter == '>' ||
        firstCharacter == '.') {
      return text.substring(1).trimLeft();
    }

    return text;
  }

  bool _looksLikeSceneHeading(String text) {
    final upper = text.trimLeft().toUpperCase();

    return _scenePrefixes.any(upper.startsWith);
  }

  bool _looksLikeTransition(String text) {
    final trimmed = text.trim();

    if (trimmed.isEmpty) {
      return false;
    }

    final upper = trimmed.toUpperCase();

    if (_knownTransitions.contains(upper)) {
      return true;
    }

    return trimmed.endsWith(':') &&
        _containsLetters(trimmed) &&
        _isUppercase(trimmed);
  }

  bool _looksLikeCharacter(String text) {
    final trimmed = text.trim();

    if (trimmed.isEmpty || trimmed.length > 40) {
      return false;
    }

    if (_looksLikeSceneHeading(trimmed) ||
        _looksLikeTransition(trimmed) ||
        trimmed.startsWith('(')) {
      return false;
    }

    if (RegExp(r'[.!?:;]$').hasMatch(trimmed)) {
      return false;
    }

    final words = trimmed
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);

    if (words.length > 5) {
      return false;
    }

    return _containsLetters(trimmed) && _isUppercase(trimmed);
  }

  bool _containsLetters(String text) {
    return text.toUpperCase() != text.toLowerCase();
  }

  bool _isUppercase(String text) {
    return text == text.toUpperCase();
  }

  String _normalizeForType(String text, BlockType type) {
    var normalized = text.trim();

    switch (type) {
      case BlockType.sceneHeading:
        return normalized.toUpperCase();

      case BlockType.character:
        return normalized.toUpperCase();

      case BlockType.parenthetical:
        if (normalized.isEmpty) {
          return normalized;
        }

        if (!normalized.startsWith('(')) {
          normalized = '($normalized';
        }

        if (!normalized.endsWith(')')) {
          normalized = '$normalized)';
        }

        return normalized;

      case BlockType.transition:
        normalized = normalized.toUpperCase();

        if (normalized.isNotEmpty && !normalized.endsWith(':')) {
          normalized = '$normalized:';
        }

        return normalized;

      case BlockType.action:
      case BlockType.dialogue:
        return normalized;
    }
  }
}
