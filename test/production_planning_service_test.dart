import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/production/production_planning.dart';
import 'package:filmsoz_studio/features/screenplay/production/production_planning_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = ProductionPlanningService();

  test('suggested breakdown extracts cast and location from screenplay', () {
    final document = _document();
    final scene = document.sceneSections.first;
    final breakdown = service.suggestedBreakdown(document, scene);

    expect(breakdown.cast, <String>['АННА', 'ФАРХОД']);
    expect(breakdown.locations, <String>['ДОМ']);
    expect(breakdown.estimatedShootMinutes, greaterThanOrEqualTo(5));
  });

  test('summary counts scheduled and broken down scenes', () {
    final document = _document();
    document.sceneProduction['s1'] = const SceneProductionData(
      props: <String>['Письмо'],
      estimatedSetupMinutes: 20,
      estimatedShootMinutes: 40,
    );
    document.shootingDays.add(
      const ShootingDayPlan(
        id: 'day1',
        title: 'День 1',
        sceneIds: <String>['s1'],
      ),
    );

    final summary = service.summarize(document);

    expect(summary.sceneCount, 2);
    expect(summary.brokenDownSceneCount, 1);
    expect(summary.scheduledSceneCount, 1);
    expect(summary.totalSetupMinutes, 20);
    expect(summary.totalShootMinutes, 40);
  });

  test('schedule and call sheet CSV contain production details', () {
    final document = _document();
    document.sceneProduction['s1'] = const SceneProductionData(
      cast: <String>['ФАРХОД', 'АННА'],
      props: <String>['Письмо'],
      vehicles: <String>['Такси'],
      estimatedShootMinutes: 60,
    );
    const day = ShootingDayPlan(
      id: 'day1',
      title: 'День 1',
      date: '2026-08-15',
      location: 'Худжанд',
      sceneIds: <String>['s1'],
    );
    document.shootingDays.add(day);

    final schedule = service.buildScheduleCsv(
      document,
      projectName: 'Ҳушвора',
    );
    final callSheet = service.buildCallSheetCsv(
      document,
      projectName: 'Ҳушвора',
      day: day,
    );

    expect(schedule, contains('FILMSOZ SHOOTING SCHEDULE'));
    expect(schedule, contains('Ҳушвора'));
    expect(schedule, contains('Худжанд'));
    expect(callSheet, contains('FILMSOZ CALL SHEET'));
    expect(callSheet, contains('Письмо'));
    expect(callSheet, contains('Такси'));
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
      FilmBlock(id: 'd1', type: BlockType.dialogue, text: 'Привет.'),
      FilmBlock(id: 'c2', type: BlockType.character, text: 'АННА'),
      FilmBlock(id: 'd2', type: BlockType.dialogue, text: 'Здравствуйте.'),
      FilmBlock(
        id: 's2',
        type: BlockType.sceneHeading,
        text: 'НАТ. ДВОР - НОЧЬ',
      ),
      FilmBlock(id: 'a2', type: BlockType.action, text: 'Машина уезжает.'),
    ],
  );
}
