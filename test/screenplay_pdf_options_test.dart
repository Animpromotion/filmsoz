import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/pdf/screenplay_pdf_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScreenplayPdfOptions', () {
    final document = FilmDocument(
      blocks: <FilmBlock>[
        _block('scene-1', BlockType.sceneHeading, 'ИНТ. ДОМ - ДЕНЬ'),
        _block('action-1', BlockType.action, 'Герой входит.'),
        _block('scene-2', BlockType.sceneHeading, 'НАТ. ДВОР - ВЕЧЕР'),
        _block('action-2', BlockType.action, 'Идёт дождь.'),
      ],
    );

    test('entire document includes every scene', () {
      const options = ScreenplayPdfOptions(title: 'Тест');

      expect(options.resolveScenes(document), hasLength(2));
    });

    test('selected scope keeps original scene numbers', () {
      const options = ScreenplayPdfOptions(
        title: 'Тест',
        scope: ScreenplayPdfScope.selectedScenes,
        selectedSceneIds: <String>{'scene-2'},
      );

      final scenes = options.resolveScenes(document);

      expect(scenes, hasLength(1));
      expect(scenes.single.id, 'scene-2');
      expect(scenes.single.number, 2);
    });
  });
}

FilmBlock _block(String id, BlockType type, String text) {
  return FilmBlock(id: id, type: type, text: text);
}
