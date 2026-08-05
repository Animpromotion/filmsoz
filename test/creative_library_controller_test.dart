import 'package:filmsoz_studio/features/screenplay/creative/creative_material.dart';
import 'package:filmsoz_studio/features/screenplay/editor/controller/screenplay_editor_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('controller creates edits duplicates and deletes materials', () {
    final controller = ScreenplayEditorController();
    addTearDown(controller.dispose);

    const material = CreativeMaterial(
      id: 'material_1',
      type: CreativeMaterialType.idea,
      title: 'Начальная идея',
      body: 'Герой получает письмо.',
      createdAt: '2026-08-06T00:00:00Z',
      updatedAt: '2026-08-06T00:00:00Z',
    );

    controller.upsertCreativeMaterial(material);
    expect(controller.document.creativeMaterials, hasLength(1));

    controller.upsertCreativeMaterial(material.copyWith(title: 'Новая идея'));
    expect(controller.document.creativeMaterials.single.title, 'Новая идея');

    final duplicate = controller.duplicateCreativeMaterial('material_1');
    expect(duplicate, isNotNull);
    expect(controller.document.creativeMaterials, hasLength(2));

    expect(controller.deleteCreativeMaterial(duplicate!.id), isTrue);
    expect(controller.document.creativeMaterials, hasLength(1));
  });

  test('inserting a material creates one action block and is undoable', () {
    final controller = ScreenplayEditorController();
    addTearDown(controller.dispose);
    final originalBlockCount = controller.document.blocks.length;

    controller.upsertCreativeMaterial(
      const CreativeMaterial(
        id: 'material_1',
        type: CreativeMaterialType.idea,
        title: 'Идея',
        body: 'Герой входит в комнату.',
        createdAt: '2026-08-06T00:00:00Z',
        updatedAt: '2026-08-06T00:00:00Z',
      ),
    );

    final result = controller.insertCreativeMaterialText(
      materialId: 'material_1',
      text: 'Герой входит в комнату.',
      afterBlockId: controller.document.blocks.last.id,
    );

    expect(result, isNotNull);
    expect(controller.document.blocks, hasLength(originalBlockCount + 1));
    expect(
      controller.document.creativeMaterials.single.usedBlockIds,
      contains(result!.focusBlockId),
    );

    expect(controller.undo(), isTrue);
    expect(controller.document.blocks, hasLength(originalBlockCount));
    expect(controller.document.creativeMaterials.single.usedBlockIds, isEmpty);
  });
}
