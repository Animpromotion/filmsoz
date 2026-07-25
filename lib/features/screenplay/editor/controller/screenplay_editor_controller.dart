import 'dart:async';

import 'package:flutter/material.dart';
import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/storage/local_storage_service.dart';

class ScreenplayEditorController extends ChangeNotifier {
  ScreenplayEditorController() {
    _document = FilmDocument.empty();
    _startAutoSaveTimer();
  }

  final LocalStorageService _storageService = LocalStorageService();

  late FilmDocument _document;
  Timer? _autoSaveTimer;
  int _idCounter = 0;

  FilmDocument get document => _document;

  void _startAutoSaveTimer() {
    _autoSaveTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(saveDocument()),
    );
  }

  void updateBlockText(String id, String text) {
    final index = _document.blocks.indexWhere((block) => block.id == id);

    if (index == -1 || _document.blocks[index].text == text) {
      return;
    }

    _document.blocks[index].text = text;
    notifyListeners();
  }

  void setBlockType(String id, BlockType type) {
    final index = _document.blocks.indexWhere((block) => block.id == id);

    if (index == -1 || _document.blocks[index].type == type) {
      return;
    }

    _document.blocks[index].type = type;
    notifyListeners();
  }

  FilmBlock splitBlock({
    required String id,
    required String textBeforeCursor,
    required String textAfterCursor,
    required BlockType nextType,
  }) {
    final index = _document.blocks.indexWhere((block) => block.id == id);

    final newBlock = FilmBlock(
      id: _generateBlockId(),
      type: nextType,
      text: textAfterCursor,
    );

    if (index == -1) {
      _document.blocks.add(newBlock);
    } else {
      _document.blocks[index].text = textBeforeCursor;
      _document.blocks.insert(index + 1, newBlock);
    }

    notifyListeners();
    return newBlock;
  }

  void deleteBlock(String id) {
    if (_document.blocks.length <= 1) {
      return;
    }

    final index = _document.blocks.indexWhere((block) => block.id == id);

    if (index == -1) {
      return;
    }

    _document.blocks.removeAt(index);
    notifyListeners();
  }

  String _generateBlockId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return '${timestamp}_${_idCounter++}';
  }

  Future<void> saveDocument() async {
    await _storageService.saveToLocal(_document);
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    super.dispose();
  }
}
