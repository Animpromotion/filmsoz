import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/editor/controller/screenplay_editor_controller.dart';
import 'package:filmsoz_studio/features/screenplay/production/production_planning.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScreenplayEditorController production planning', () {
    late ScreenplayEditorController controller;

    setUp(() {
      controller = ScreenplayEditorController();
      controller.replaceWithImportedDocument(
        FilmDocument(
          blocks: <FilmBlock>[
            _block('s1', BlockType.sceneHeading, 'ИНТ. ДОМ - ДЕНЬ'),
            _block('c1', BlockType.character, 'ФАРХОД'),
            _block('d1', BlockType.dialogue, 'Я готов.'),
            _block('s2', BlockType.sceneHeading, 'НАТ. ДВОР - НОЧЬ'),
            _block('a2', BlockType.action, 'Подъезжает машина.'),
          ],
        ),
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('stores scene breakdown with undo and redo', () {
      expect(
        controller.setSceneProduction(
          's1',
          const SceneProductionData(
            cast: <String>['ФАРХОД'],
            props: <String>['Письмо'],
            estimatedShootMinutes: 45,
          ),
        ),
        isTrue,
      );

      expect(controller.document.sceneProductionFor('s1').props,
          <String>['Письмо']);
      expect(controller.undo(), isTrue);
      expect(controller.document.sceneProductionFor('s1').isDefault, isTrue);
      expect(controller.redo(), isTrue);
      expect(controller.document.sceneProductionFor('s1').estimatedShootMinutes,
          45);
    });

    test('creates, updates, moves and deletes shooting days', () {
      final firstId = controller.createShootingDay(title: 'День А');
      final secondId = controller.createShootingDay(title: 'День Б');
      final first = controller.document.shootingDayById(firstId)!;

      expect(
        controller.updateShootingDay(
          first.copyWith(
            date: '2026-08-15',
            sceneIds: const <String>['s1', 's2'],
            status: ShootingDayStatus.confirmed,
          ),
        ),
        isTrue,
      );
      expect(controller.document.shootingDays.first.sceneIds,
          <String>['s1', 's2']);
      expect(controller.moveShootingDay(secondId, -1), isTrue);
      expect(controller.document.shootingDays.first.id, secondId);
      expect(controller.deleteShootingDay(secondId), isTrue);
      expect(controller.document.shootingDays.single.id, firstId);
      expect(controller.undo(), isTrue);
      expect(controller.document.shootingDays.length, 2);
    });

    test('duplicates breakdown and removes schedule references on scene delete',
        () {
      controller.setSceneProduction(
        's1',
        const SceneProductionData(props: <String>['Ключ']),
      );
      final dayId = controller.createShootingDay();
      final day = controller.document.shootingDayById(dayId)!;
      controller
          .updateShootingDay(day.copyWith(sceneIds: const <String>['s1']));

      final duplicated = controller.duplicateScene('s1')!;
      expect(
        controller.document.sceneProductionFor(duplicated.sceneId).props,
        <String>['Ключ'],
      );

      controller.deleteScene('s1');
      expect(controller.document.sceneProduction.containsKey('s1'), isFalse);
      expect(controller.document.shootingDays.single.sceneIds, isEmpty);
    });
  });
}

FilmBlock _block(String id, BlockType type, String text) {
  return FilmBlock(id: id, type: type, text: text);
}
