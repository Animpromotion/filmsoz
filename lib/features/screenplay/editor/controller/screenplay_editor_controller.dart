import 'dart:async';

import 'package:flutter/material.dart';
import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/storage/local_storage_service.dart';

class ScreenplayEditorController extends ChangeNotifier {
  ScreenplayEditorController({LocalStorageService? storageService})
      : _storageService = storageService ?? LocalStorageService();

  static const int _historyLimit = 100;
  static const Duration _typingGroupDelay = Duration(milliseconds: 850);

  final LocalStorageService _storageService;

  FilmDocument _document = FilmDocument.empty();
  final List<FilmDocument> _undoStack = <FilmDocument>[];
  final List<FilmDocument> _redoStack = <FilmDocument>[];

  Timer? _periodicSaveTimer;
  Timer? _debouncedSaveTimer;
  Timer? _typingGroupTimer;

  bool _isInitialized = false;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDirty = false;
  bool _saveRequestedWhileSaving = false;
  bool _isDisposed = false;

  int _idCounter = 0;
  int _revision = 0;
  String? _typingBlockId;

  DateTime? _lastSavedAt;
  String? _lastError;
  String? _storagePath;

  FilmDocument get document => _document;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isDirty => _isDirty;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  DateTime? get lastSavedAt => _lastSavedAt;
  String? get lastError => _lastError;
  String? get storagePath => _storagePath;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    _isLoading = true;
    _lastError = null;
    _notifySafely();

    try {
      final loadedDocument = await _storageService.loadFromLocal();

      if (loadedDocument != null) {
        _document = loadedDocument;
      }

      _storagePath = await _storageService.autosavePath;
    } catch (error) {
      _lastError = 'Не удалось загрузить автосохранение: $error';
    } finally {
      _clearHistory();
      _isInitialized = true;
      _isLoading = false;
      _isDirty = false;
      _startPeriodicSave();
      _notifySafely();
    }
  }

  void updateBlockText(String id, String text) {
    final index = _document.blocks.indexWhere((block) => block.id == id);

    if (index == -1 || _document.blocks[index].text == text) {
      return;
    }

    _recordTypingHistory(id);
    _document.blocks[index].text = text;
    _markDocumentChanged();
  }

  void setBlockType(String id, BlockType type) {
    final index = _document.blocks.indexWhere((block) => block.id == id);

    if (index == -1 || _document.blocks[index].type == type) {
      return;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();
    _document.blocks[index].type = type;
    _markDocumentChanged();
  }

  FilmBlock splitBlock({
    required String id,
    required String textBeforeCursor,
    required String textAfterCursor,
    required BlockType nextType,
  }) {
    _finishTypingGroup();
    _pushUndoSnapshot();

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

    _markDocumentChanged();
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

    _finishTypingGroup();
    _pushUndoSnapshot();
    _document.blocks.removeAt(index);
    _markDocumentChanged();
  }

  bool undo() {
    _finishTypingGroup();

    if (_undoStack.isEmpty) {
      return false;
    }

    _redoStack.add(_cloneDocument(_document));
    _trimHistory(_redoStack);
    _document = _undoStack.removeLast();
    _markDocumentChanged();
    return true;
  }

  bool redo() {
    _finishTypingGroup();

    if (_redoStack.isEmpty) {
      return false;
    }

    _undoStack.add(_cloneDocument(_document));
    _trimHistory(_undoStack);
    _document = _redoStack.removeLast();
    _markDocumentChanged();
    return true;
  }

  Future<void> saveDocument({bool force = false}) async {
    if (_isDisposed || !_isInitialized) {
      return;
    }

    if (_isSaving) {
      _saveRequestedWhileSaving = true;
      return;
    }

    if (!force && !_isDirty) {
      return;
    }

    _debouncedSaveTimer?.cancel();
    _isSaving = true;
    _lastError = null;

    final savedRevision = _revision;
    _notifySafely();

    try {
      await _storageService.saveToLocal(_document);
      _storagePath ??= await _storageService.autosavePath;
      _lastSavedAt = DateTime.now();

      if (_revision == savedRevision) {
        _isDirty = false;
      }
    } catch (error) {
      _lastError = 'Ошибка сохранения: $error';
      _isDirty = true;
    } finally {
      _isSaving = false;

      final shouldSaveAgain =
          _saveRequestedWhileSaving || _revision != savedRevision;

      _saveRequestedWhileSaving = false;
      _notifySafely();

      if (shouldSaveAgain && !_isDisposed) {
        _scheduleDebouncedSave(
          delay: const Duration(milliseconds: 350),
        );
      }
    }
  }

  void _recordTypingHistory(String blockId) {
    if (_typingBlockId != blockId || _typingGroupTimer == null) {
      _pushUndoSnapshot();
      _typingBlockId = blockId;
    }

    _typingGroupTimer?.cancel();
    _typingGroupTimer = Timer(
      _typingGroupDelay,
      _finishTypingGroup,
    );
  }

  void _finishTypingGroup() {
    _typingGroupTimer?.cancel();
    _typingGroupTimer = null;
    _typingBlockId = null;
  }

  void _pushUndoSnapshot() {
    _undoStack.add(_cloneDocument(_document));
    _trimHistory(_undoStack);
    _redoStack.clear();
  }

  void _trimHistory(List<FilmDocument> stack) {
    while (stack.length > _historyLimit) {
      stack.removeAt(0);
    }
  }

  void _clearHistory() {
    _finishTypingGroup();
    _undoStack.clear();
    _redoStack.clear();
  }

  FilmDocument _cloneDocument(FilmDocument source) {
    return FilmDocument(
      blocks: source.blocks
          .map(
            (block) => FilmBlock(
              id: block.id,
              type: block.type,
              text: block.text,
            ),
          )
          .toList(growable: true),
    );
  }

  void _markDocumentChanged() {
    _revision++;
    _isDirty = true;
    _lastError = null;
    _scheduleDebouncedSave();
    _notifySafely();
  }

  void _scheduleDebouncedSave({
    Duration delay = const Duration(milliseconds: 900),
  }) {
    _debouncedSaveTimer?.cancel();
    _debouncedSaveTimer = Timer(
      delay,
      () => unawaited(saveDocument()),
    );
  }

  void _startPeriodicSave() {
    _periodicSaveTimer?.cancel();
    _periodicSaveTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(saveDocument()),
    );
  }

  String _generateBlockId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return '${timestamp}_${_idCounter++}';
  }

  void _notifySafely() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _periodicSaveTimer?.cancel();
    _debouncedSaveTimer?.cancel();
    _typingGroupTimer?.cancel();
    super.dispose();
  }
}
