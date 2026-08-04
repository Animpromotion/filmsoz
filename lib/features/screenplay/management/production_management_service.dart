import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/management/production_management.dart';
import 'package:filmsoz_studio/features/screenplay/production/production_planning.dart';

class BudgetTotals {
  const BudgetTotals({
    required this.planned,
    required this.actual,
    required this.paid,
  });

  final double planned;
  final double actual;
  final double paid;

  double get outstanding => actual > paid ? actual - paid : 0.0;
  double get variance => planned - actual;
}

class AvailabilityConflict {
  const AvailabilityConflict({
    required this.person,
    required this.day,
    required this.reasons,
  });

  final ProductionPerson person;
  final ShootingDayPlan day;
  final List<String> reasons;
}

class ShootingDayTeamSummary {
  const ShootingDayTeamSummary({
    required this.day,
    required this.people,
    required this.characters,
    required this.budget,
  });

  final ShootingDayPlan day;
  final List<ProductionPerson> people;
  final List<String> characters;
  final BudgetTotals budget;
}

class ProductionManagementService {
  const ProductionManagementService();

  List<String> screenplayCharacters(FilmDocument document) {
    final result = <String>[];
    final seen = <String>{};

    for (final block in document.blocks) {
      if (block.type != BlockType.character) {
        continue;
      }

      final name = _normalizeCharacter(block.text);

      if (name.isNotEmpty && seen.add(name)) {
        result.add(name);
      }
    }

    result.sort();
    return result;
  }

  List<String> charactersForScene(FilmDocument document, String sceneId) {
    final production = document.sceneProductionFor(sceneId);
    final result = <String>[];
    final seen = <String>{};

    for (final value in production.cast) {
      final name = _normalizeCharacter(value);
      if (name.isNotEmpty && seen.add(name)) {
        result.add(name);
      }
    }

    final scene = document.sceneById(sceneId);

    if (scene != null) {
      for (final block in scene.blocks) {
        if (block.type != BlockType.character) {
          continue;
        }

        final name = _normalizeCharacter(block.text);
        if (name.isNotEmpty && seen.add(name)) {
          result.add(name);
        }
      }
    }

    result.sort();
    return result;
  }

  List<String> charactersForDay(
    FilmDocument document,
    ShootingDayPlan day,
  ) {
    final result = <String>[];
    final seen = <String>{};

    for (final sceneId in day.sceneIds) {
      for (final character in charactersForScene(document, sceneId)) {
        if (seen.add(character)) {
          result.add(character);
        }
      }
    }

    result.sort();
    return result;
  }

  List<ProductionPerson> peopleForDay(
    FilmDocument document,
    ShootingDayPlan day,
  ) {
    final characters = charactersForDay(document, day).toSet();
    final people = document.productionPeople.where((person) {
      if (person.type == ProductionPersonType.crew) {
        return true;
      }

      return person.linkedCharacters
          .map(_normalizeCharacter)
          .any(characters.contains);
    }).toList(growable: false);

    people.sort((first, second) {
      final departmentCompare = first.department.index.compareTo(
        second.department.index,
      );
      if (departmentCompare != 0) {
        return departmentCompare;
      }
      return first.name.toLowerCase().compareTo(second.name.toLowerCase());
    });
    return people;
  }

  List<AvailabilityConflict> availabilityConflicts(FilmDocument document) {
    final result = <AvailabilityConflict>[];

    for (final day in document.shootingDays) {
      final date = day.date.trim();

      if (date.isEmpty) {
        continue;
      }

      final requiredCharacters = charactersForDay(document, day).toSet();

      for (final person in peopleForDay(document, day)) {
        if (!person.unavailableDates.contains(date)) {
          continue;
        }

        final reasons = <String>[];

        if (person.type == ProductionPersonType.crew) {
          reasons.add(person.department.label);
        } else {
          for (final character in person.linkedCharacters) {
            final normalized = _normalizeCharacter(character);
            if (requiredCharacters.contains(normalized)) {
              reasons.add(normalized);
            }
          }
        }

        result.add(
          AvailabilityConflict(
            person: person,
            day: day,
            reasons: reasons,
          ),
        );
      }
    }

    result.sort((first, second) {
      final dateCompare = first.day.date.compareTo(second.day.date);
      if (dateCompare != 0) {
        return dateCompare;
      }
      return first.person.name.compareTo(second.person.name);
    });
    return result;
  }

  BudgetTotals budgetTotals(FilmDocument document) {
    return _totals(document.budgetItems);
  }

  BudgetTotals budgetForScene(FilmDocument document, String sceneId) {
    return _totals(
      document.budgetItems.where((item) => item.sceneId == sceneId),
    );
  }

  BudgetTotals budgetForDay(FilmDocument document, String dayId) {
    return _totals(
      document.budgetItems.where((item) => item.shootingDayId == dayId),
    );
  }

  Map<BudgetCategory, BudgetTotals> budgetByCategory(FilmDocument document) {
    return <BudgetCategory, BudgetTotals>{
      for (final category in BudgetCategory.values)
        category: _totals(
          document.budgetItems.where((item) => item.category == category),
        ),
    };
  }

  ShootingDayTeamSummary summarizeDay(
    FilmDocument document,
    ShootingDayPlan day,
  ) {
    return ShootingDayTeamSummary(
      day: day,
      people: peopleForDay(document, day),
      characters: charactersForDay(document, day),
      budget: budgetForDay(document, day.id),
    );
  }

  String buildBudgetCsv(
    FilmDocument document, {
    required String projectName,
  }) {
    final buffer = StringBuffer('\uFEFF');
    final totals = budgetTotals(document);

    buffer.writeln('FILMSOZ BUDGET');
    buffer.writeln('Проект;${_csv(projectName)}');
    buffer.writeln('Валюта;${_csv(document.budgetCurrency)}');
    buffer.writeln('План;${_money(totals.planned)}');
    buffer.writeln('Факт;${_money(totals.actual)}');
    buffer.writeln('Оплачено;${_money(totals.paid)}');
    buffer.writeln('Задолженность;${_money(totals.outstanding)}');
    buffer.writeln();
    buffer.writeln(
      'Категория;Статья;Получатель;План;Факт;Оплачено;Задолженность;Сцена;Съёмочный день;Примечание',
    );

    for (final item in document.budgetItems) {
      final scene =
          item.sceneId == null ? null : document.sceneById(item.sceneId!);
      final day = item.shootingDayId == null
          ? null
          : document.shootingDayById(item.shootingDayId!);

      buffer.writeln(<String>[
        _csv(item.category.label),
        _csv(item.title),
        _csv(item.payee),
        _money(item.plannedAmount),
        _money(item.actualAmount),
        _money(item.paidAmount),
        _money(item.outstandingAmount),
        _csv(scene == null ? '' : '${scene.number}. ${scene.title}'),
        _csv(day?.title ?? ''),
        _csv(item.notes),
      ].join(';'));
    }

    return buffer.toString();
  }

  String buildPeopleCsv(
    FilmDocument document, {
    required String projectName,
  }) {
    final buffer = StringBuffer('\uFEFF');
    buffer.writeln('FILMSOZ CAST AND CREW');
    buffer.writeln('Проект;${_csv(projectName)}');
    buffer.writeln();
    buffer.writeln(
      'Имя;Тип;Отдел;Должность;Персонажи;Телефон;Почта;Недоступные даты;Ставка за день;Примечание',
    );

    for (final person in document.productionPeople) {
      buffer.writeln(<String>[
        _csv(person.name),
        _csv(person.type.label),
        _csv(person.department.label),
        _csv(person.jobTitle),
        _csv(person.linkedCharacters.join(', ')),
        _csv(person.phone),
        _csv(person.email),
        _csv(person.unavailableDates.join(', ')),
        _money(person.dailyRate),
        _csv(person.notes),
      ].join(';'));
    }

    return buffer.toString();
  }

  String buildDaySummaryCsv(
    FilmDocument document, {
    required String projectName,
    required ShootingDayPlan day,
  }) {
    final summary = summarizeDay(document, day);
    final conflicts = availabilityConflicts(document)
        .where((conflict) => conflict.day.id == day.id)
        .toList(growable: false);
    final buffer = StringBuffer('\uFEFF');

    buffer.writeln('FILMSOZ SHOOTING DAY SUMMARY');
    buffer.writeln('Проект;${_csv(projectName)}');
    buffer.writeln('День;${_csv(day.title)}');
    buffer.writeln('Дата;${_csv(day.date)}');
    buffer.writeln('Локация;${_csv(day.location)}');
    buffer.writeln('Сбор группы;${_csv(day.crewCall)}');
    buffer.writeln('Первый кадр;${_csv(day.firstShot)}');
    buffer.writeln('Окончание;${_csv(day.estimatedWrap)}');
    buffer.writeln('Персонажи;${_csv(summary.characters.join(', '))}');
    buffer.writeln('Бюджет дня;${_money(summary.budget.actual)}');
    buffer.writeln('Оплачено;${_money(summary.budget.paid)}');
    buffer.writeln('Задолженность;${_money(summary.budget.outstanding)}');
    buffer.writeln();
    buffer.writeln('КОМАНДА И АКТЁРЫ');
    buffer.writeln('Имя;Отдел;Должность;Телефон;Персонажи');

    for (final person in summary.people) {
      buffer.writeln(<String>[
        _csv(person.name),
        _csv(person.department.label),
        _csv(person.jobTitle),
        _csv(person.phone),
        _csv(person.linkedCharacters.join(', ')),
      ].join(';'));
    }

    buffer.writeln();
    buffer.writeln('КОНФЛИКТЫ ДОСТУПНОСТИ');
    buffer.writeln('Имя;Причина');

    for (final conflict in conflicts) {
      buffer.writeln(
        '${_csv(conflict.person.name)};${_csv(conflict.reasons.join(', '))}',
      );
    }

    return buffer.toString();
  }

  BudgetTotals _totals(Iterable<BudgetItem> items) {
    var planned = 0.0;
    var actual = 0.0;
    var paid = 0.0;

    for (final item in items) {
      planned += item.plannedAmount;
      actual += item.actualAmount;
      paid += item.paidAmount;
    }

    return BudgetTotals(planned: planned, actual: actual, paid: paid);
  }

  String _normalizeCharacter(String value) {
    return value
        .replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '')
        .trim()
        .toUpperCase();
  }

  String _money(double value) => value.toStringAsFixed(2);

  String _csv(String value) {
    final normalized = value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    if (normalized.contains(';') ||
        normalized.contains('"') ||
        normalized.contains('\n')) {
      return '"${normalized.replaceAll('"', '""')}"';
    }

    return normalized;
  }
}
