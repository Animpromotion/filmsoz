import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/management/production_management.dart';
import 'package:filmsoz_studio/features/screenplay/management/production_management_service.dart';
import 'package:filmsoz_studio/features/screenplay/production/production_planning.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = ProductionManagementService();

  test('detects cast availability conflict for shooting day', () {
    final document = _document();

    final conflicts = service.availabilityConflicts(document);

    expect(conflicts, hasLength(1));
    expect(conflicts.single.person.name, 'Алишер');
    expect(conflicts.single.day.id, 'day1');
    expect(conflicts.single.reasons, contains('ФАРХОД'));
  });

  test('calculates total, scene and day budgets', () {
    final document = _document();

    final total = service.budgetTotals(document);
    final scene = service.budgetForScene(document, 's1');
    final day = service.budgetForDay(document, 'day1');

    expect(total.planned, 3000);
    expect(total.actual, 2700);
    expect(total.paid, 1700);
    expect(total.outstanding, 1000);
    expect(scene.actual, 900);
    expect(day.actual, 1800);
  });

  test('exports budget, people and day summary CSV', () {
    final document = _document();
    final budget = service.buildBudgetCsv(
      document,
      projectName: 'Ҳушвора',
    );
    final people = service.buildPeopleCsv(
      document,
      projectName: 'Ҳушвора',
    );
    final day = service.buildDaySummaryCsv(
      document,
      projectName: 'Ҳушвора',
      day: document.shootingDays.single,
    );

    expect(budget, contains('FILMSOZ BUDGET'));
    expect(budget, contains('Гонорар'));
    expect(budget, contains('Задолженность'));
    expect(people, contains('FILMSOZ CAST AND CREW'));
    expect(people, contains('Алишер'));
    expect(day, contains('FILMSOZ SHOOTING DAY SUMMARY'));
    expect(day, contains('КОНФЛИКТЫ ДОСТУПНОСТИ'));
  });

  test('day summary includes crew and only required cast', () {
    final document = _document();
    final day = document.shootingDays.single;
    final people = service.peopleForDay(document, day);

    expect(people.map((person) => person.name), contains('Алишер'));
    expect(people.map((person) => person.name), contains('Саид'));
    expect(people.map((person) => person.name), isNot(contains('Мадина')));
  });
}

FilmDocument _document() {
  return FilmDocument(
    blocks: <FilmBlock>[
      FilmBlock(
        id: 's1',
        type: BlockType.sceneHeading,
        text: 'ИНТ. ДОМ - ДЕНЬ',
      ),
      FilmBlock(id: 'c1', type: BlockType.character, text: 'ФАРХОД'),
      FilmBlock(id: 'd1', type: BlockType.dialogue, text: 'Я готов.'),
      FilmBlock(
        id: 's2',
        type: BlockType.sceneHeading,
        text: 'НАТ. ДВОР - НОЧЬ',
      ),
      FilmBlock(id: 'c2', type: BlockType.character, text: 'АННА'),
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
        name: 'Алишер',
        type: ProductionPersonType.cast,
        department: CrewDepartment.cast,
        linkedCharacters: <String>['ФАРХОД'],
        unavailableDates: <String>['2026-08-15'],
      ),
      ProductionPerson(
        id: 'p2',
        name: 'Мадина',
        type: ProductionPersonType.cast,
        department: CrewDepartment.cast,
        linkedCharacters: <String>['АННА'],
      ),
      ProductionPerson(
        id: 'p3',
        name: 'Саид',
        type: ProductionPersonType.crew,
        department: CrewDepartment.camera,
        jobTitle: 'Оператор',
      ),
    ],
    budgetItems: const <BudgetItem>[
      BudgetItem(
        id: 'b1',
        title: 'Гонорар',
        category: BudgetCategory.cast,
        plannedAmount: 1000,
        actualAmount: 900,
        paidAmount: 400,
        sceneId: 's1',
      ),
      BudgetItem(
        id: 'b2',
        title: 'Камера',
        category: BudgetCategory.equipment,
        plannedAmount: 2000,
        actualAmount: 1800,
        paidAmount: 1300,
        shootingDayId: 'day1',
      ),
    ],
  );
}
