import 'dart:typed_data';

import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/pdf/screenplay_pdf_service.dart';
import 'package:filmsoz_studio/features/screenplay/postproduction/postproduction.dart';
import 'package:filmsoz_studio/features/screenplay/postproduction/postproduction_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds post-production readiness PDF', () async {
    final document = FilmDocument(
      blocks: <FilmBlock>[
        FilmBlock(
          id: 's1',
          type: BlockType.sceneHeading,
          text: 'INT. EDIT SUITE - DAY',
        ),
      ],
      scenePostProduction: const <String, ScenePostProductionData>{
        's1': ScenePostProductionData(
          status: PostSceneStatus.editing,
          progress: 45,
        ),
      },
      postProductionTasks: const <PostProductionTask>[
        PostProductionTask(
          id: 't1',
          title: 'Picture edit',
          progress: 45,
        ),
      ],
    );

    final service = PostProductionPdfService(
      fontLoader: () async => ScreenplayPdfFonts.type1ForTests(),
    );
    final bytes = await service.buildReadinessPdf(
      document,
      projectName: 'Filmsoz',
    );

    expect(bytes, isA<Uint8List>());
    expect(bytes.length, greaterThan(500));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
