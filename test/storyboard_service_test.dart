import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/storyboard/storyboard_service.dart';
import 'package:filmsoz_studio/features/screenplay/storyboard/storyboard_shot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = StoryboardService();

  test('numbers shots and calculates duration in scene order', () {
    final document = _document();
    final shots = service.numberedShots(document);

    expect(shots.map((entry) => entry.number), <String>['1.1', '1.2', '2.1']);
    expect(service.totalDurationSeconds(document), 12);
    expect(service.sceneDurationSeconds(document, 's1'), 9);
    expect(service.formatDuration(72), '01:12');
  });

  test('filters by query shot size and equipment', () {
    final document = _document();

    expect(
      service.filterShots(document, query: 'телефон'),
      hasLength(1),
    );
    expect(
      service.filterShots(
        document,
        shotSizes: const <ShotSize>{ShotSize.closeUp},
      ),
      hasLength(1),
    );
    expect(
      service.filterShots(document, equipment: 'штатив'),
      hasLength(2),
    );
  });

  test('exports shot list CSV', () {
    final csv = service.buildShotListCsv(
      _document(),
      projectName: 'Ҳушвора',
    );

    expect(csv, contains('FILMSOZ SHOT LIST'));
    expect(csv, contains('Ҳушвора'));
    expect(csv, contains('1.1'));
    expect(csv, contains('Крупный'));
    expect(csv, contains('Оборудование'));
  });
}

FilmDocument _document() {
  return FilmDocument(
    blocks: <FilmBlock>[
      FilmBlock(
        id: 's1',
        type: BlockType.sceneHeading,
        text: 'ИНТ. ДОМ - ДЕНЬ',
      ),
      FilmBlock(
        id: 's2',
        type: BlockType.sceneHeading,
        text: 'НАТ. ДВОР - НОЧЬ',
      ),
    ],
    storyboardShots: const <String, List<StoryboardShot>>{
      's1': <StoryboardShot>[
        StoryboardShot(
          id: 'shot1',
          title: 'Телефон героя',
          shotSize: ShotSize.closeUp,
          durationSeconds: 4,
          equipment: <String>['Штатив'],
          visualDescription: 'Телефон светится в темноте.',
        ),
        StoryboardShot(
          id: 'shot2',
          title: 'Герой у окна',
          durationSeconds: 5,
          equipment: <String>['Стедикам'],
        ),
      ],
      's2': <StoryboardShot>[
        StoryboardShot(
          id: 'shot3',
          title: 'Общий двор',
          durationSeconds: 3,
          equipment: <String>['Штатив'],
        ),
      ],
    },
  );
}
