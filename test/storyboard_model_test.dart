import 'dart:convert';

import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/storyboard/storyboard_shot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('storyboard shots survive project JSON round trip', () {
    final image = base64Encode(<int>[1, 2, 3, 4]);
    final document = FilmDocument(
      blocks: <FilmBlock>[
        FilmBlock(
          id: 's1',
          type: BlockType.sceneHeading,
          text: 'ИНТ. ДОМ - ДЕНЬ',
        ),
      ],
      storyboardShots: <String, List<StoryboardShot>>{
        's1': <StoryboardShot>[
          StoryboardShot(
            id: 'shot1',
            title: 'Вход героя',
            shotSize: ShotSize.wide,
            cameraAngle: CameraAngle.low,
            cameraMovement: CameraMovement.dolly,
            lens: '35 мм',
            fps: 48,
            durationSeconds: 6.5,
            equipment: <String>['Рельсы', 'Дым-машина'],
            visualDescription: 'Силуэт в дверях.',
            imageFileName: 'frame.png',
            imageMimeType: 'image/png',
            imageBase64: image,
          ),
        ],
      },
    );

    final restored = FilmDocument.fromJson(document.toJson());
    final shot = restored.storyboardShotsFor('s1').single;

    expect(shot.title, 'Вход героя');
    expect(shot.shotSize, ShotSize.wide);
    expect(shot.cameraAngle, CameraAngle.low);
    expect(shot.cameraMovement, CameraMovement.dolly);
    expect(shot.durationSeconds, 6.5);
    expect(shot.equipment, <String>['Рельсы', 'Дым-машина']);
    expect(shot.imageBytes, <int>[1, 2, 3, 4]);
  });

  test('old projects load with empty storyboard data', () {
    final document = FilmDocument.fromJson(<String, dynamic>{
      'blocks': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 's1',
          'type': 'sceneHeading',
          'text': 'НАТ. ДВОР - ДЕНЬ',
        },
      ],
    });

    expect(document.storyboardShots, isEmpty);
    expect(document.storyboardShotsFor('s1'), isEmpty);
  });

  test('shots linked to missing scenes are removed on load', () {
    final document = FilmDocument.fromJson(<String, dynamic>{
      'blocks': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 's1',
          'type': 'sceneHeading',
          'text': 'НАТ. ДВОР - ДЕНЬ',
        },
      ],
      'storyboardShots': <String, dynamic>{
        'missing': <Map<String, dynamic>>[
          <String, dynamic>{'id': 'shot1'},
        ],
      },
    });

    expect(document.storyboardShots, isEmpty);
  });
}
