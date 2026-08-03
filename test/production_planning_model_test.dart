import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/production/production_planning.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production metadata survives project JSON round trip', () {
    final document = FilmDocument(
      blocks: <FilmBlock>[
        FilmBlock(
          id: 's1',
          type: BlockType.sceneHeading,
          text: 'ИНТ. ДОМ - ДЕНЬ',
        ),
      ],
      sceneProduction: <String, SceneProductionData>{
        's1': const SceneProductionData(
          cast: <String>['ФАРХОД', 'АННА'],
          extras: 5,
          locations: <String>['Дом'],
          props: <String>['Письмо'],
          costumes: <String>['Пальто'],
          makeup: <String>['Синяк'],
          vehicles: <String>['Такси'],
          specialEquipment: <String>['Дым-машина'],
          notes: 'Снять до заката.',
          estimatedSetupMinutes: 30,
          estimatedShootMinutes: 75,
          priority: ProductionPriority.high,
        ),
      },
      shootingDays: const <ShootingDayPlan>[
        ShootingDayPlan(
          id: 'd1',
          title: 'День 1',
          date: '2026-08-15',
          location: 'Худжанд',
          crewCall: '07:00',
          firstShot: '08:00',
          estimatedWrap: '18:00',
          sceneIds: <String>['s1'],
          notes: 'Натура после обеда.',
          status: ShootingDayStatus.confirmed,
        ),
      ],
    );

    final restored = FilmDocument.fromJson(document.toJson());
    final data = restored.sceneProductionFor('s1');
    final day = restored.shootingDays.single;

    expect(data.cast, <String>['ФАРХОД', 'АННА']);
    expect(data.extras, 5);
    expect(data.props, <String>['Письмо']);
    expect(data.priority, ProductionPriority.high);
    expect(day.id, 'd1');
    expect(day.sceneIds, <String>['s1']);
    expect(day.status, ShootingDayStatus.confirmed);
  });

  test('old project JSON loads with empty production plan', () {
    final document = FilmDocument.fromJson(<String, dynamic>{
      'blocks': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 's1',
          'type': 'sceneHeading',
          'text': 'НАТ. ДВОР - ДЕНЬ',
        },
      ],
    });

    expect(document.sceneProduction, isEmpty);
    expect(document.shootingDays, isEmpty);
  });

  test('orphaned production scene ids are removed while loading', () {
    final document = FilmDocument.fromJson(<String, dynamic>{
      'blocks': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 's1',
          'type': 'sceneHeading',
          'text': 'НАТ. ДВОР - ДЕНЬ',
        },
      ],
      'sceneProduction': <String, dynamic>{
        'missing': <String, dynamic>{
          'props': <String>['Мяч'],
        },
      },
      'shootingDays': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'd1',
          'title': 'День 1',
          'sceneIds': <String>['s1', 'missing'],
        },
      ],
    });

    expect(document.sceneProduction, isEmpty);
    expect(document.shootingDays.single.sceneIds, <String>['s1']);
  });
}
