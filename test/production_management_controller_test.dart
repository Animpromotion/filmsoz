import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/editor/controller/screenplay_editor_controller.dart';
import 'package:filmsoz_studio/features/screenplay/management/production_management.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScreenplayEditorController production management', () {
    late ScreenplayEditorController controller;

    setUp(() {
      controller = ScreenplayEditorController();
      controller.replaceWithImportedDocument(
        FilmDocument(
          blocks: <FilmBlock>[
            FilmBlock(
              id: 's1',
              type: BlockType.sceneHeading,
              text: 'ИНТ. ДОМ - ДЕНЬ',
            ),
          ],
        ),
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('creates and updates person with undo and redo', () {
      final id = controller.createProductionPerson(
        name: 'Алишер',
        type: ProductionPersonType.cast,
      );
      final person = controller.document.productionPersonById(id)!;

      expect(
        controller.updateProductionPerson(
          person.copyWith(
            linkedCharacters: const <String>['фарход'],
            phone: ' 12345 ',
            dailyRate: 500,
          ),
        ),
        isTrue,
      );
      expect(
        controller.document.productionPersonById(id)!.linkedCharacters,
        <String>['ФАРХОД'],
      );
      expect(controller.undo(), isTrue);
      expect(
        controller.document.productionPersonById(id)!.linkedCharacters,
        isEmpty,
      );
      expect(controller.redo(), isTrue);
      expect(controller.document.productionPersonById(id)!.dailyRate, 500);
    });

    test('creates and updates budget item and currency', () {
      final id = controller.createBudgetItem(
        title: 'Аренда камеры',
        category: BudgetCategory.equipment,
      );
      final item = controller.document.budgetItemById(id)!;

      expect(
        controller.updateBudgetItem(
          item.copyWith(
            plannedAmount: 2000,
            actualAmount: 1800,
            paidAmount: 1000,
            sceneId: 's1',
          ),
        ),
        isTrue,
      );
      expect(controller.setBudgetCurrency('usd'), isTrue);
      expect(controller.document.budgetCurrency, 'USD');
      expect(controller.document.budgetItemById(id)!.outstandingAmount, 800);
      expect(controller.document.budgetItemById(id)!.sceneId, 's1');
    });

    test('deleting scene clears budget scene reference', () {
      final id = controller.createBudgetItem(title: 'Реквизит');
      final item = controller.document.budgetItemById(id)!;
      controller.updateBudgetItem(item.copyWith(sceneId: 's1'));

      controller.deleteScene('s1');

      expect(controller.document.budgetItemById(id)!.sceneId, isNull);
    });
  });
}
