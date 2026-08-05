import 'package:filmsoz_studio/core/release/app_info.dart';
import 'package:filmsoz_studio/core/release/project_migration_service.dart';
import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('old bare screenplay is migrated to current Filmsoz format', () {
    final result = const FilmsozProjectMigrationService().migrate(
      <String, dynamic>{
        'scriptBlocks': <Map<String, dynamic>>[
          <String, dynamic>{
            'blockType': 'scene',
            'content': 'ИНТ. ДОМ - ДЕНЬ',
          },
          <String, dynamic>{
            'blockType': 'dialog',
            'content': 'Салом!',
          },
        ],
      },
    );

    expect(result.targetVersion, FilmsozAppInfo.projectFormatVersion);
    expect(result.wasMigrated, isTrue);
    expect(result.root['format'], 'filmsoz');

    final document = FilmDocument.fromJson(
      Map<String, dynamic>.from(result.root['document'] as Map),
    );

    expect(document.blocks, hasLength(2));
    expect(document.blocks.first.type, BlockType.sceneHeading);
    expect(document.blocks.last.type, BlockType.dialogue);
  });

  test('newer project format is rejected instead of being downgraded', () {
    expect(
      () => const FilmsozProjectMigrationService().migrate(
        <String, dynamic>{
          'format': 'filmsoz',
          'version': FilmsozAppInfo.projectFormatVersion + 1,
          'document': <String, dynamic>{
            'blocks': <Map<String, dynamic>>[],
          },
        },
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
