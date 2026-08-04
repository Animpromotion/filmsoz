import 'dart:typed_data';

import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/pdf/screenplay_pdf_service.dart';
import 'package:filmsoz_studio/features/screenplay/storyboard/storyboard_pdf_service.dart';
import 'package:filmsoz_studio/features/screenplay/storyboard/storyboard_shot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds storyboard PDF document', () async {
    final service = StoryboardPdfService(
      fontLoader: () async => ScreenplayPdfFonts.type1ForTests(),
    );
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
          StoryboardShot(
            id: 'shot1',
            title: 'Hero enters',
            visualDescription: 'Wide composition.',
            durationSeconds: 5,
          ),
        ],
      },
    );

    final bytes = await service.buildPdf(
      document,
      projectName: 'Test project',
    );

    expect(bytes, isA<Uint8List>());
    expect(bytes.length, greaterThan(500));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
