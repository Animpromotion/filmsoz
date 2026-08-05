import 'package:filmsoz_studio/features/screenplay/creative/creative_material.dart';
import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creative material survives FilmDocument JSON round trip', () {
    final document = FilmDocument(
      blocks: <FilmBlock>[
        FilmBlock(
            id: 'scene_1',
            type: BlockType.sceneHeading,
            text: 'ИНТ. ДОМ - ДЕНЬ'),
      ],
      creativeMaterials: const <CreativeMaterial>[
        CreativeMaterial(
          id: 'material_1',
          type: CreativeMaterialType.quote,
          title: 'Главная цитата',
          body: 'История начинается с выбора.',
          source: 'Автор',
          folder: 'Драматургия',
          tags: <String>['тема', 'выбор'],
          linkedSceneIds: <String>['scene_1'],
          linkedCharacterNames: <String>['ФАРХОД'],
          createdAt: '2026-08-06T00:00:00Z',
          updatedAt: '2026-08-06T00:00:00Z',
        ),
      ],
    );

    final restored = FilmDocument.fromJson(document.toJson());
    final material = restored.creativeMaterials.single;

    expect(material.type, CreativeMaterialType.quote);
    expect(material.title, 'Главная цитата');
    expect(material.tags, containsAll(<String>['тема', 'выбор']));
    expect(material.linkedSceneIds, <String>['scene_1']);
  });

  test('orphan scene and block links are removed during load', () {
    final document = FilmDocument.fromJson(<String, dynamic>{
      'blocks': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'scene_1',
          'type': 'sceneHeading',
          'text': 'ИНТ. ДОМ - ДЕНЬ',
        },
      ],
      'creativeMaterials': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'material_1',
          'type': 'idea',
          'title': 'Идея',
          'linkedSceneIds': <String>['scene_1', 'missing_scene'],
          'usedBlockIds': <String>['scene_1', 'missing_block'],
        },
      ],
    });

    final material = document.creativeMaterials.single;
    expect(material.linkedSceneIds, <String>['scene_1']);
    expect(material.usedBlockIds, <String>['scene_1']);
  });
}
