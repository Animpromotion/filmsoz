import 'dart:convert';

import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/production/production_planning.dart';
import 'package:filmsoz_studio/features/screenplay/shooting_control/shooting_control.dart';
import 'package:filmsoz_studio/features/screenplay/storyboard/storyboard_shot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('takes continuity photos and journals survive JSON round trip', () {
    final image = base64Encode(<int>[1, 2, 3, 4]);
    final document = FilmDocument(
      blocks: <FilmBlock>[
        FilmBlock(
          id: 's1',
          type: BlockType.sceneHeading,
          text: 'ИНТ. ДОМ - ДЕНЬ',
        ),
      ],
      storyboardShots: const <String, List<StoryboardShot>>{
        's1': <StoryboardShot>[StoryboardShot(id: 'shot1')],
      },
      shootingDays: const <ShootingDayPlan>[
        ShootingDayPlan(id: 'day1', title: 'День 1'),
      ],
      shotTakes: <String, List<ShotTake>>{
        'shot1': <ShotTake>[
          ShotTake(
            id: 'take1',
            takeNumber: 3,
            status: ShotTakeStatus.selected,
            shootingDayId: 'day1',
            fileName: 'A001.mov',
            rating: 5,
            continuityPhotos: <ContinuityPhoto>[
              ContinuityPhoto(
                id: 'photo1',
                fileName: 'continuity.jpg',
                mimeType: 'image/jpeg',
                base64Data: image,
              ),
            ],
          ),
        ],
      },
      shootingDayJournals: const <String, ShootingDayJournal>{
        'day1': ShootingDayJournal(
          actualCrewCall: '07:10',
          summary: 'Сцена снята.',
        ),
      },
    );

    final restored = FilmDocument.fromJson(document.toJson());
    final take = restored.shotTakesFor('shot1').single;

    expect(take.takeNumber, 3);
    expect(take.status, ShotTakeStatus.selected);
    expect(take.shootingDayId, 'day1');
    expect(take.continuityPhotos.single.bytes, <int>[1, 2, 3, 4]);
    expect(restored.shootingDayJournalFor('day1').actualCrewCall, '07:10');
  });

  test('orphaned takes and journals are removed on load', () {
    final document = FilmDocument.fromJson(<String, dynamic>{
      'blocks': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 's1',
          'type': 'sceneHeading',
          'text': 'НАТ. ДВОР - ДЕНЬ',
        },
      ],
      'shotTakes': <String, dynamic>{
        'missingShot': <Map<String, dynamic>>[
          <String, dynamic>{'id': 'take1'},
        ],
      },
      'shootingDayJournals': <String, dynamic>{
        'missingDay': <String, dynamic>{'summary': 'Текст'},
      },
    });

    expect(document.shotTakes, isEmpty);
    expect(document.shootingDayJournals, isEmpty);
  });

  test('invalid shooting day is cleared from a valid take', () {
    final document = FilmDocument.fromJson(<String, dynamic>{
      'blocks': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 's1',
          'type': 'sceneHeading',
          'text': 'НАТ. ДВОР - ДЕНЬ',
        },
      ],
      'storyboardShots': <String, dynamic>{
        's1': <Map<String, dynamic>>[
          <String, dynamic>{'id': 'shot1'},
        ],
      },
      'shotTakes': <String, dynamic>{
        'shot1': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'take1',
            'shootingDayId': 'missingDay',
          },
        ],
      },
    });

    expect(document.shotTakesFor('shot1').single.shootingDayId, isNull);
  });
}
