import 'package:filmsoz_studio/core/release/project_diagnostics_service.dart';
import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('diagnostics finds duplicate IDs and optimizer repairs them', () {
    final document = FilmDocument(
      blocks: <FilmBlock>[
        FilmBlock(
          id: 'repaired_scene_1',
          type: BlockType.action,
          text: 'До сцены',
        ),
        FilmBlock(
          id: 'repaired_scene_1',
          type: BlockType.sceneHeading,
          text: 'ИНТ. ДОМ',
        ),
      ],
      sceneNotes: const <String, String>{'missing_scene': 'Старая заметка'},
    );
    final service = const FilmsozProjectDiagnosticsService();
    final report = service.inspect(document);

    expect(report.hasIssues, isTrue);
    expect(report.orphanRecordCount, 1);
    expect(
      report.issues.any((issue) => issue.code == 'duplicate_block_ids'),
      isTrue,
    );

    final optimized = service.optimize(document);
    final ids = optimized.document.blocks.map((block) => block.id).toSet();

    expect(ids.length, optimized.document.blocks.length);
    expect(optimized.document.blocks.first.type, BlockType.sceneHeading);
    expect(optimized.document.sceneNotes, isEmpty);
    expect(optimized.removedRecords, greaterThanOrEqualTo(1));
  });
}
