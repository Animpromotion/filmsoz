import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/formatting/screenplay_editing_flow_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = ScreenplayEditingFlowService();

  group('expectedNextType', () {
    test('uses professional Enter sequence', () {
      expect(
        service.expectedNextType(BlockType.sceneHeading),
        BlockType.action,
      );
      expect(service.expectedNextType(BlockType.action), BlockType.action);
      expect(
        service.expectedNextType(BlockType.character),
        BlockType.dialogue,
      );
      expect(service.expectedNextType(BlockType.dialogue), BlockType.action);
      expect(
        service.expectedNextType(BlockType.parenthetical),
        BlockType.dialogue,
      );
      expect(
        service.expectedNextType(BlockType.transition),
        BlockType.sceneHeading,
      );
    });
  });

  group('planEnter', () {
    test('creates action after completed dialogue', () {
      final plan = service.planEnter(
        currentType: BlockType.dialogue,
        textBeforeCursor: 'Я вернусь завтра.',
        textAfterCursor: '',
      );

      expect(plan.shouldSplit, isTrue);
      expect(plan.currentType, BlockType.dialogue);
      expect(plan.nextType, BlockType.action);
    });

    test('double Enter ends an empty dialogue without another blank block', () {
      final plan = service.planEnter(
        currentType: BlockType.dialogue,
        textBeforeCursor: '',
        textAfterCursor: '',
      );

      expect(plan.shouldSplit, isFalse);
      expect(plan.currentType, BlockType.action);
    });

    test('empty parenthetical returns to dialogue', () {
      final plan = service.planEnter(
        currentType: BlockType.parenthetical,
        textBeforeCursor: '',
        textAfterCursor: '',
      );

      expect(plan.shouldSplit, isFalse);
      expect(plan.currentType, BlockType.dialogue);
    });

    test('splitting text in the middle preserves the block type', () {
      final plan = service.planEnter(
        currentType: BlockType.dialogue,
        textBeforeCursor: 'Первая часть',
        textAfterCursor: 'вторая часть',
      );

      expect(plan.shouldSplit, isTrue);
      expect(plan.nextType, BlockType.dialogue);
    });

    test('empty action does not create repeated empty blocks', () {
      final plan = service.planEnter(
        currentType: BlockType.action,
        textBeforeCursor: '   ',
        textAfterCursor: '',
      );

      expect(plan.shouldSplit, isFalse);
      expect(plan.currentType, BlockType.action);
    });
  });

  group('cycleType', () {
    test('Tab moves forward and wraps', () {
      expect(
        service.cycleType(BlockType.sceneHeading, reverse: false),
        BlockType.action,
      );
      expect(
        service.cycleType(BlockType.transition, reverse: false),
        BlockType.sceneHeading,
      );
    });

    test('Shift Tab moves backward and wraps', () {
      expect(
        service.cycleType(BlockType.action, reverse: true),
        BlockType.sceneHeading,
      );
      expect(
        service.cycleType(BlockType.sceneHeading, reverse: true),
        BlockType.transition,
      );
    });
  });

  test('hint describes the expected next block', () {
    expect(
      service.nextBlockHint(BlockType.character),
      contains('диалог'),
    );
    expect(
      service.nextBlockHint(BlockType.dialogue),
      contains('завершает диалог'),
    );
  });
}
