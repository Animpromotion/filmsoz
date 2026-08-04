import 'dart:io';

import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/pdf/screenplay_pdf_options.dart';
import 'package:filmsoz_studio/features/screenplay/pdf/screenplay_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScreenplayPdfService', () {
    test('builds a multi-page compatible PDF document', () async {
      final service = ScreenplayPdfService(
        fontLoader: () async => ScreenplayPdfFonts.type1ForTests(),
      );
      final document = FilmDocument(
        blocks: <FilmBlock>[
          _block('scene-1', BlockType.sceneHeading, 'INT. ROOM - DAY'),
          _block('action-1', BlockType.action, 'A screenplay lies on a desk.'),
          _block('character-1', BlockType.character, 'FARHOD'),
          _block('dialogue-1', BlockType.dialogue, 'We continue the work.'),
          _block('transition-1', BlockType.transition, 'CUT TO:'),
        ],
      );

      final bytes = await service.buildPdf(
        document,
        options: const ScreenplayPdfOptions(
          title: 'Filmsoz PDF test',
          author: 'Filmsoz',
          includeTitlePage: false,
        ),
      );

      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('throws when selected scene scope is empty', () async {
      final service = ScreenplayPdfService(
        fontLoader: () async => ScreenplayPdfFonts.type1ForTests(),
      );
      final document = FilmDocument(
        blocks: <FilmBlock>[
          _block('scene-1', BlockType.sceneHeading, 'INT. ROOM - DAY'),
        ],
      );

      await expectLater(
        service.buildPdf(
          document,
          options: const ScreenplayPdfOptions(
            title: 'Empty selection',
            scope: ScreenplayPdfScope.selectedScenes,
          ),
        ),
        throwsStateError,
      );
    });

    test(
      'Windows system fonts generate Cyrillic PDF text',
      () async {
        final service = ScreenplayPdfService();
        final document = FilmDocument(
          blocks: <FilmBlock>[
            _block('scene-1', BlockType.sceneHeading, 'ИНТ. КОМНАТА - ДЕНЬ'),
            _block('action-1', BlockType.action, 'Фарҳод сценарий менависад.'),
          ],
        );

        final bytes = await service.buildPdf(
          document,
          options: const ScreenplayPdfOptions(title: 'Филмсоз'),
        );

        expect(bytes.length, greaterThan(1000));
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      },
      skip: !Platform.isWindows,
    );
  });
}

FilmBlock _block(String id, BlockType type, String text) {
  return FilmBlock(id: id, type: type, text: text);
}
