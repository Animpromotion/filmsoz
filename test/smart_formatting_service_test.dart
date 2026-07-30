import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/formatting/smart_formatting_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = SmartFormattingService();

  group('SmartFormattingService.detectLiveType', () {
    test('detects Russian scene heading', () {
      final type = service.detectLiveType(
        text: 'ИНТ. КОМНАТА - НОЧЬ',
        currentType: BlockType.action,
      );

      expect(type, BlockType.sceneHeading);
    });

    test('detects Tajik/Russian exterior scene heading', () {
      final type = service.detectLiveType(
        text: 'НАТ. КУЧА - РУЗ',
        currentType: BlockType.action,
      );

      expect(type, BlockType.sceneHeading);
    });

    test('detects parenthetical', () {
      final type = service.detectLiveType(
        text: '(тихо',
        currentType: BlockType.dialogue,
      );

      expect(type, BlockType.parenthetical);
    });

    test('detects forced Fountain markers', () {
      expect(
        service.detectLiveType(
          text: '@ФАРХОД',
          currentType: BlockType.action,
        ),
        BlockType.character,
      );
      expect(
        service.detectLiveType(
          text: '>СКЛЕЙКА:',
          currentType: BlockType.action,
        ),
        BlockType.transition,
      );
      expect(
        service.detectLiveType(
          text: '!Описание действия',
          currentType: BlockType.character,
        ),
        BlockType.action,
      );
    });

    test('uses dialogue context after character', () {
      final type = service.detectLiveType(
        text: 'Ман туро интизор будам.',
        currentType: BlockType.action,
        previousType: BlockType.character,
      );

      expect(type, BlockType.dialogue);
    });
  });

  group('SmartFormattingService.finalizeBlock', () {
    test('normalizes scene heading to uppercase', () {
      final result = service.finalizeBlock(
        text: 'инт. хона - шаб',
        currentType: BlockType.action,
      );

      expect(result.type, BlockType.sceneHeading);
      expect(result.text, 'ИНТ. ХОНА - ШАБ');
    });

    test('recognizes and normalizes character', () {
      final result = service.finalizeBlock(
        text: 'ФАРХОД',
        currentType: BlockType.action,
      );

      expect(result.type, BlockType.character);
      expect(result.text, 'ФАРХОД');
    });

    test('does not turn a normal action into character', () {
      final result = service.finalizeBlock(
        text: 'Фарход входит в комнату.',
        currentType: BlockType.action,
      );

      expect(result.type, BlockType.action);
      expect(result.text, 'Фарход входит в комнату.');
    });

    test('closes parenthetical automatically', () {
      final result = service.finalizeBlock(
        text: '(шепотом',
        currentType: BlockType.parenthetical,
      );

      expect(result.type, BlockType.parenthetical);
      expect(result.text, '(шепотом)');
    });

    test('removes forced marker and adds transition colon', () {
      final result = service.finalizeBlock(
        text: '>затемнение',
        currentType: BlockType.action,
      );

      expect(result.type, BlockType.transition);
      expect(result.text, 'ЗАТЕМНЕНИЕ:');
    });

    test('removes forced character marker', () {
      final result = service.finalizeBlock(
        text: '@фарход',
        currentType: BlockType.action,
      );

      expect(result.type, BlockType.character);
      expect(result.text, 'ФАРХОД');
    });
  });
}
