import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/production/production_planning.dart';
import 'package:filmsoz_studio/features/screenplay/shooting_control/shooting_control.dart';
import 'package:filmsoz_studio/features/screenplay/shooting_control/shooting_control_service.dart';
import 'package:filmsoz_studio/features/screenplay/storyboard/storyboard_shot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = ShootingControlService();

  test('summarizes recorded rejected and selected takes', () {
    final summary = service.summarize(_document());

    expect(summary.shotCount, 2);
    expect(summary.takeCount, 3);
    expect(summary.recordedCount, 1);
    expect(summary.rejectedCount, 1);
    expect(summary.selectedCount, 1);
    expect(summary.totalRecordedSeconds, 15);
    expect(summary.shotsWithoutSelectedTake, 1);
  });

  test('filters and numbers takes in screenplay order', () {
    final entries = service.numberedTakes(_document());

    expect(entries.map((entry) => entry.takeLabel), <String>[
      '1.1 / Дубль 1',
      '1.1 / Дубль 2',
      '1.2 / Дубль 1',
    ]);
    expect(
      service.filterTakes(
        _document(),
        status: ShotTakeStatus.rejected,
      ),
      hasLength(1),
    );
    expect(service.filterTakes(_document(), query: 'a002.mov'), hasLength(1));
  });

  test('exports editing log and shooting journal CSV', () {
    final editingCsv = service.buildEditingLogCsv(
      _document(),
      projectName: 'Ҳушвора',
    );
    final journalCsv = service.buildShootingDayJournalCsv(
      _document(),
      projectName: 'Ҳушвора',
    );

    expect(editingCsv, contains('FILMSOZ EDITING LOG'));
    expect(editingCsv, contains('A002.mov'));
    expect(editingCsv, contains('Выбран'));
    expect(journalCsv, contains('FILMSOZ SHOOTING DAY JOURNAL'));
    expect(journalCsv, contains('Смена завершена'));
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
    ],
    storyboardShots: const <String, List<StoryboardShot>>{
      's1': <StoryboardShot>[
        StoryboardShot(id: 'shot1', title: 'Вход героя'),
        StoryboardShot(id: 'shot2', title: 'Крупный план'),
      ],
    },
    shootingDays: const <ShootingDayPlan>[
      ShootingDayPlan(id: 'day1', title: 'День 1', date: '2026-08-05'),
    ],
    shotTakes: const <String, List<ShotTake>>{
      'shot1': <ShotTake>[
        ShotTake(
          id: 'take1',
          takeNumber: 1,
          status: ShotTakeStatus.recorded,
          durationSeconds: 5,
          fileName: 'A001.mov',
          shootingDayId: 'day1',
        ),
        ShotTake(
          id: 'take2',
          takeNumber: 2,
          status: ShotTakeStatus.selected,
          durationSeconds: 6,
          fileName: 'A002.mov',
          shootingDayId: 'day1',
        ),
      ],
      'shot2': <ShotTake>[
        ShotTake(
          id: 'take3',
          takeNumber: 1,
          status: ShotTakeStatus.rejected,
          durationSeconds: 4,
          rejectionReason: 'Фокус',
          shootingDayId: 'day1',
        ),
      ],
    },
    shootingDayJournals: const <String, ShootingDayJournal>{
      'day1': ShootingDayJournal(summary: 'Смена завершена'),
    },
  );
}
