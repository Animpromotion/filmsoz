import 'dart:io';

import 'package:filmsoz_studio/core/release/app_settings.dart';
import 'package:filmsoz_studio/core/release/app_settings_service.dart';
import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/editor/controller/screenplay_editor_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScreenplayEditorController history', () {
    test('undo and redo restore typed text', () {
      final controller = ScreenplayEditorController();
      addTearDown(controller.dispose);

      final block = controller.document.blocks.first;
      final originalText = block.text;

      controller.updateBlockText(block.id, 'Новый текст');

      expect(controller.canUndo, isTrue);
      expect(controller.document.blocks.first.text, 'Новый текст');

      expect(controller.undo(), isTrue);
      expect(controller.document.blocks.first.text, originalText);
      expect(controller.canRedo, isTrue);

      expect(controller.redo(), isTrue);
      expect(controller.document.blocks.first.text, 'Новый текст');
    });

    test('undo restores document after block split', () {
      final controller = ScreenplayEditorController();
      addTearDown(controller.dispose);

      final block = controller.document.blocks.first;
      final originalText = block.text;

      controller.splitBlock(
        id: block.id,
        textBeforeCursor: originalText,
        textAfterCursor: '',
        nextType: BlockType.action,
      );

      expect(controller.document.blocks, hasLength(2));

      expect(controller.undo(), isTrue);
      expect(controller.document.blocks, hasLength(1));
      expect(controller.document.blocks.first.text, originalText);

      expect(controller.redo(), isTrue);
      expect(controller.document.blocks, hasLength(2));
    });

    test('new change after undo clears redo history', () {
      final controller = ScreenplayEditorController();
      addTearDown(controller.dispose);

      final block = controller.document.blocks.first;

      controller.updateBlockText(block.id, 'Первая версия');
      expect(controller.undo(), isTrue);
      expect(controller.canRedo, isTrue);

      controller.setBlockType(block.id, BlockType.action);

      expect(controller.canRedo, isFalse);
    });
  });

  group('ScreenplayEditorController application settings', () {
    test('reloadApplicationSettings loads saved autosave interval', () async {
      final directory = await Directory.systemTemp.createTemp(
        'filmsoz_controller_settings_',
      );
      addTearDown(() => directory.delete(recursive: true));

      final settingsService = FilmsozAppSettingsService(
        rootDirectoryPath: directory.path,
      );
      await settingsService.save(
        const FilmsozAppSettings(autosaveSeconds: 120),
      );

      final controller = ScreenplayEditorController(
        settingsService: settingsService,
      );
      addTearDown(controller.dispose);

      await controller.reloadApplicationSettings();

      expect(controller.applicationSettings.autosaveSeconds, 120);
    });
  });
}
