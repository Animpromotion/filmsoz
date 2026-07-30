import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';

class EnterKeyPlan {
  const EnterKeyPlan({
    required this.shouldSplit,
    required this.currentType,
    required this.nextType,
  });

  final bool shouldSplit;
  final BlockType currentType;
  final BlockType nextType;
}

class ScreenplayEditingFlowService {
  const ScreenplayEditingFlowService();

  static const List<BlockType> _tabOrder = <BlockType>[
    BlockType.sceneHeading,
    BlockType.action,
    BlockType.character,
    BlockType.dialogue,
    BlockType.parenthetical,
    BlockType.transition,
  ];

  EnterKeyPlan planEnter({
    required BlockType currentType,
    required String textBeforeCursor,
    required String textAfterCursor,
  }) {
    final beforeIsEmpty = textBeforeCursor.trim().isEmpty;
    final afterIsEmpty = textAfterCursor.trim().isEmpty;

    if (beforeIsEmpty && afterIsEmpty) {
      final replacementType = _typeForEmptyEnter(currentType);

      return EnterKeyPlan(
        shouldSplit: false,
        currentType: replacementType,
        nextType: expectedNextType(replacementType),
      );
    }

    if (!afterIsEmpty) {
      return EnterKeyPlan(
        shouldSplit: true,
        currentType: currentType,
        nextType: currentType,
      );
    }

    return EnterKeyPlan(
      shouldSplit: true,
      currentType: currentType,
      nextType: expectedNextType(currentType),
    );
  }

  BlockType expectedNextType(BlockType currentType) {
    switch (currentType) {
      case BlockType.sceneHeading:
        return BlockType.action;
      case BlockType.action:
        return BlockType.action;
      case BlockType.character:
        return BlockType.dialogue;
      case BlockType.dialogue:
        return BlockType.action;
      case BlockType.parenthetical:
        return BlockType.dialogue;
      case BlockType.transition:
        return BlockType.sceneHeading;
    }
  }

  BlockType cycleType(
    BlockType currentType, {
    required bool reverse,
  }) {
    final currentIndex = _tabOrder.indexOf(currentType);

    if (currentIndex == -1) {
      return BlockType.action;
    }

    final offset = reverse ? -1 : 1;
    final nextIndex =
        (currentIndex + offset + _tabOrder.length) % _tabOrder.length;

    return _tabOrder[nextIndex];
  }

  String nextBlockHint(BlockType currentType) {
    final nextType = expectedNextType(currentType);
    final nextLabel = blockTypeLabel(nextType);

    if (currentType == BlockType.dialogue) {
      return 'Enter → $nextLabel • повторный Enter завершает диалог';
    }

    return 'Enter → $nextLabel • Tab / Shift+Tab — тип блока';
  }

  String blockTypeLabel(BlockType type) {
    switch (type) {
      case BlockType.sceneHeading:
        return 'заголовок сцены';
      case BlockType.action:
        return 'действие';
      case BlockType.character:
        return 'персонаж';
      case BlockType.dialogue:
        return 'диалог';
      case BlockType.parenthetical:
        return 'ремарка';
      case BlockType.transition:
        return 'переход';
    }
  }

  BlockType _typeForEmptyEnter(BlockType currentType) {
    switch (currentType) {
      case BlockType.sceneHeading:
      case BlockType.character:
      case BlockType.dialogue:
      case BlockType.action:
        return BlockType.action;
      case BlockType.parenthetical:
        return BlockType.dialogue;
      case BlockType.transition:
        return BlockType.sceneHeading;
    }
  }
}
