import 'package:filmsoz_studio/features/screenplay/creative/creative_library_service.dart';
import 'package:filmsoz_studio/features/screenplay/creative/creative_material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = CreativeLibraryService();
  const materials = <CreativeMaterial>[
    CreativeMaterial(
      id: 'idea_1',
      type: CreativeMaterialType.idea,
      title: 'Финал фильма',
      body: 'Герой возвращается домой.',
      folder: 'Сюжет',
      tags: <String>['финал'],
      createdAt: '2026-08-01T00:00:00Z',
      updatedAt: '2026-08-01T00:00:00Z',
    ),
    CreativeMaterial(
      id: 'quote_1',
      type: CreativeMaterialType.quote,
      title: 'Цитата об ответственности',
      body: 'Каждый выбор имеет цену.',
      source: 'Неизвестный автор',
      folder: 'Цитаты',
      tags: <String>['тема'],
      usedBlockIds: <String>['block_1'],
      createdAt: '2026-08-02T00:00:00Z',
      updatedAt: '2026-08-02T00:00:00Z',
    ),
  ];

  test('filters by query type folder and unused state', () {
    expect(
      service.filter(materials, const CreativeLibraryFilter(query: 'домой')),
      hasLength(1),
    );
    expect(
      service.filter(
        materials,
        const CreativeLibraryFilter(type: CreativeMaterialType.quote),
      ),
      hasLength(1),
    );
    expect(
      service
          .filter(
            materials,
            const CreativeLibraryFilter(folder: 'Сюжет', onlyUnused: true),
          )
          .single
          .id,
      'idea_1',
    );
  });

  test('builds screenplay insertion text for quote and link', () {
    expect(
      service.insertionText(materials[1]),
      '«Каждый выбор имеет цену.»\n— Неизвестный автор',
    );

    const link = CreativeMaterial(
      id: 'link_1',
      type: CreativeMaterialType.link,
      title: 'Интервью',
      url: 'https://example.com',
      createdAt: '2026-08-02T00:00:00Z',
      updatedAt: '2026-08-02T00:00:00Z',
    );
    expect(service.insertionText(link), 'Интервью\nhttps://example.com');
  });
}
