import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/management/production_management.dart';
import 'package:filmsoz_studio/features/screenplay/production/production_planning.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('people and budget survive project JSON round trip', () {
    final document = FilmDocument(
      blocks: <FilmBlock>[
        FilmBlock(
          id: 's1',
          type: BlockType.sceneHeading,
          text: 'ИНТ. ДОМ - ДЕНЬ',
        ),
      ],
      shootingDays: const <ShootingDayPlan>[
        ShootingDayPlan(
          id: 'day1',
          title: 'День 1',
          date: '2026-08-15',
          sceneIds: <String>['s1'],
        ),
      ],
      productionPeople: const <ProductionPerson>[
        ProductionPerson(
          id: 'p1',
          name: 'Алишер Каримов',
          type: ProductionPersonType.cast,
          department: CrewDepartment.cast,
          phone: '+992900000000',
          linkedCharacters: <String>['ФАРХОД'],
          unavailableDates: <String>['2026-08-15'],
          dailyRate: 500,
        ),
      ],
      budgetItems: const <BudgetItem>[
        BudgetItem(
          id: 'b1',
          title: 'Гонорар актёра',
          category: BudgetCategory.cast,
          plannedAmount: 1000,
          actualAmount: 900,
          paidAmount: 400,
          payee: 'Алишер Каримов',
          sceneId: 's1',
          shootingDayId: 'day1',
        ),
      ],
      budgetCurrency: 'tjs',
    );

    final restored = FilmDocument.fromJson(document.toJson());

    expect(restored.budgetCurrency, 'TJS');
    expect(restored.productionPeople.single.name, 'Алишер Каримов');
    expect(
      restored.productionPeople.single.linkedCharacters,
      <String>['ФАРХОД'],
    );
    expect(restored.budgetItems.single.outstandingAmount, 500);
    expect(restored.budgetItems.single.sceneId, 's1');
    expect(restored.budgetItems.single.shootingDayId, 'day1');
  });

  test('old projects load with empty management data', () {
    final document = FilmDocument.fromJson(<String, dynamic>{
      'blocks': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 's1',
          'type': 'sceneHeading',
          'text': 'НАТ. ДВОР - ДЕНЬ',
        },
      ],
    });

    expect(document.productionPeople, isEmpty);
    expect(document.budgetItems, isEmpty);
    expect(document.budgetCurrency, 'TJS');
  });

  test('invalid budget scene and day references are cleared', () {
    final document = FilmDocument.fromJson(<String, dynamic>{
      'blocks': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 's1',
          'type': 'sceneHeading',
          'text': 'НАТ. ДВОР - ДЕНЬ',
        },
      ],
      'budgetItems': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'b1',
          'title': 'Транспорт',
          'sceneId': 'missing',
          'shootingDayId': 'missingDay',
        },
      ],
    });

    expect(document.budgetItems.single.sceneId, isNull);
    expect(document.budgetItems.single.shootingDayId, isNull);
  });
}
