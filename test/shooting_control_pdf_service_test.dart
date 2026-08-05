import 'dart:typed_data';

import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/shooting_control/shooting_control.dart';
import 'package:filmsoz_studio/features/screenplay/shooting_control/shooting_control_pdf_service.dart';
import 'package:filmsoz_studio/features/screenplay/storyboard/storyboard_shot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds shooting report PDF', () async {
    final service = ShootingControlPdfService();
    final document = FilmDocument(
      blocks: <FilmBlock>[
        FilmBlock(
          id: 's1',
          type: BlockType.sceneHeading,
          text: 'INT. ROOM - DAY',
        ),
      ],
      storyboardShots: const <String, List<StoryboardShot>>{
        's1': <StoryboardShot>[
          StoryboardShot(id: 'shot1', title: 'Hero enters'),
        ],
      },
      shotTakes: const <String, List<ShotTake>>{
        'shot1': <ShotTake>[
          ShotTake(
            id: 'take1',
            status: ShotTakeStatus.selected,
            fileName: 'A001.mov',
            durationSeconds: 5,
          ),
        ],
      },
    );

    final bytes = await service.buildPdf(document, projectName: 'Filmsoz');

    expect(bytes, isA<Uint8List>());
    expect(bytes.length, greaterThan(500));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
