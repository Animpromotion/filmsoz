import 'dart:async';
import 'package:flutter/material.dart';
import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/storage/local_storage_service.dart';

class ScreenplayEditorController extends ChangeNotifier {
  final LocalStorageService _storageService = LocalStorageService();
  late FilmDocument _document;
  Timer? _autoSaveTimer;

  FilmDocument get document => _document;

  ScreenplayEditorController() {
    _document = FilmDocument.empty();
    _startAutoSaveTimer();
  }

  void _startAutoSaveTimer() {
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      saveDocument();
    });
  }

  void updateBlockText(String id, String text) {
    final index = _document.blocks.indexWhere((b) => b.id == id);
    if (index != -1) {
      _document.blocks[index].text = text;
      notifyListeners();
    }
  }

  void setBlockType(String id, BlockType type) {
    final index = _document.blocks.indexWhere((b) => b.id == id);
    if (index != -1) {
      _document.blocks[index].type = type;
      notifyListeners();
    }
  }

  void addBlockAfter(String id, BlockType type) {
    final index = _document.blocks.indexWhere((b) => b.id == id);
    final newBlock = FilmBlock(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: type,
      text: '',
    );

    if (index != -1) {
      _document.blocks.insert(index + 1, newBlock);
    } else {
      _document.blocks.add(newBlock);
    }
    notifyListeners();
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
