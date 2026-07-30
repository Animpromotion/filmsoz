import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/storage/local_storage_service.dart';
import 'package:path/path.dart' as path;

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
  bool _hasPendingAutosave = false;
  bool _saveRequestedWhileSaving = false;
  bool _isDisposed = false;

  int _idCounter = 0;
  int _revision = 0;
  String? _typingBlockId;

  DateTime? _lastSavedAt;
  DateTime? _lastProjectSavedAt;
  String? _lastError;
  String? _storagePath;
  String? _projectPath;
  String _projectName = 'Без названия';

  FilmDocument get document => _document;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isDirty => _isDirty;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  bool get hasProjectPath => _projectPath != null;
  DateTime? get lastSavedAt => _lastSavedAt;
  DateTime? get lastProjectSavedAt => _lastProjectSavedAt;
  String? get lastError => _lastError;
  String? get storagePath => _storagePath;
  String? get projectPath => _projectPath;
  String get projectName => _projectName;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    _isLoading = true;
    _lastError = null;
    _notifySafely();

    try {
      final storedState = await _storageService.loadAutosaveState();

      if (storedState != null) {
        _document = storedState.document;
        _isDirty = storedState.isDirty;

        final restoredPath = storedState.projectPath;

        if (restoredPath != null && await File(restoredPath).exists()) {
          _projectPath = restoredPath;
          _projectName = storedState.projectName?.trim().isNotEmpty == true
              ? storedState.projectName!.trim()
              : path.basenameWithoutExtension(restoredPath);
          _storagePath = restoredPath;
        } else {
          _projectPath = null;
          _projectName = storedState.projectName?.trim().isNotEmpty == true
              ? storedState.projectName!.trim()
              : 'Восстановленный сценарий';
        }
      }

      _storagePath ??= await _storageService.autosavePath;
    } catch (error) {
      _lastError = 'Не удалось загрузить автосохранение: $error';
    } finally {
      _clearHistory();
      _isInitialized = true;
      _isLoading = false;
      _hasPendingAutosave = false;
      _startPeriodicSave();
      _notifySafely();
    }
  }

  void updateBlockText(String id, String text) {
    updateBlockContent(id, text: text);
  }

  void updateBlockContent(
    String id, {
    required String text,
    BlockType? inferredType,
  }) {
    final index = _document.blocks.indexWhere((block) => block.id == id);

    if (index == -1) {
      return;
    }

    final block = _document.blocks[index];
    final nextType = inferredType ?? block.type;

    if (block.text == text && block.type == nextType) {
      return;
    }

    _recordTypingHistory(id);
    block
      ..text = text
      ..type = nextType;
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
    BlockType? currentType,
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
      _document.blocks[index]
        ..text = textBeforeCursor
        ..type = currentType ?? _document.blocks[index].type;
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

  void createNewProject() {
    _finishTypingGroup();
    _document = FilmDocument.empty();
    _projectPath = null;
    _projectName = 'Без названия';
    _storagePath = null;
    _lastProjectSavedAt = null;
    _lastError = null;
    _isDirty = false;
    _hasPendingAutosave = true;
    _revision++;
    _clearHistory();
    _notifySafely();
    _scheduleDebouncedSave(delay: const Duration(milliseconds: 100));
  }

  void replaceWithImportedDocument(
    FilmDocument document, {
    String? sourceName,
  }) {
    _finishTypingGroup();

    _document = _cloneDocument(document);
    _projectPath = null;
    _projectName = sourceName?.trim().isNotEmpty == true
        ? sourceName!.trim()
        : 'Импортированный сценарий';
    _storagePath = null;
    _lastProjectSavedAt = null;
    _lastError = null;
    _isDirty = true;
    _hasPendingAutosave = true;
    _revision++;
    _clearHistory();
    _notifySafely();
    _scheduleDebouncedSave(delay: const Duration(milliseconds: 100));
  }

  Future<bool> openProjectFromPath(String filePath) async {
    await _waitForActiveSave();

    if (_isDisposed) {
      return false;
    }

    _isLoading = true;
    _lastError = null;
    _notifySafely();

    try {
      final normalizedPath = _storageService.normalizeProjectPath(filePath);
      final loadedDocument = await _storageService.loadProjectFromPath(
        normalizedPath,
      );

      _document = loadedDocument;
      _projectPath = normalizedPath;
      _projectName = path.basenameWithoutExtension(normalizedPath);
      _storagePath = normalizedPath;
      _lastProjectSavedAt = DateTime.now();
      _isDirty = false;
      _hasPendingAutosave = true;
      _revision++;
      _clearHistory();

      await _storageService.saveToLocal(
        _cloneDocument(_document),
        projectPath: _projectPath,
        projectName: _projectName,
        isDirty: false,
      );

      _lastSavedAt = DateTime.now();
      _hasPendingAutosave = false;
      return true;
    } catch (error) {
      _lastError = 'Не удалось открыть проект: $error';
      return false;
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<bool> saveProjectToPath(String filePath) async {
    await _waitForActiveSave();

    if (_isDisposed) {
      return false;
    }

    _debouncedSaveTimer?.cancel();
    _isSaving = true;
    _lastError = null;

    final savedRevision = _revision;
    final documentSnapshot = _cloneDocument(_document);
    _notifySafely();

    try {
      final normalizedPath = await _storageService.saveProjectToPath(
        documentSnapshot,
        filePath,
      );

      _projectPath = normalizedPath;
      _projectName = path.basenameWithoutExtension(normalizedPath);
      _storagePath = normalizedPath;
      _lastProjectSavedAt = DateTime.now();

      if (_revision == savedRevision) {
        _isDirty = false;
      }

      final autosaveRevision = _revision;
      final autosaveSnapshot = _cloneDocument(_document);

      await _storageService.saveToLocal(
        autosaveSnapshot,
        projectPath: _projectPath,
        projectName: _projectName,
        isDirty: _isDirty,
      );

      _lastSavedAt = DateTime.now();
      _hasPendingAutosave = _revision != autosaveRevision;
      return true;
    } catch (error) {
      _lastError = 'Ошибка сохранения проекта: $error';
      _isDirty = true;
      _hasPendingAutosave = true;
      return false;
    } finally {
      _isSaving = false;
      _notifySafely();

      if (_revision != savedRevision && !_isDisposed) {
        _scheduleDebouncedSave(
          delay: const Duration(milliseconds: 350),
        );
      }
    }
  }

  Future<bool> saveCurrentProject() async {
    final currentPath = _projectPath;

    if (currentPath == null) {
      return false;
    }

    return saveProjectToPath(currentPath);
  }

  Future<void> saveDocument({bool force = false}) async {
    if (_isDisposed || !_isInitialized) {
      return;
    }

    if (_isSaving) {
      _saveRequestedWhileSaving = true;
      return;
    }

    if (!force && !_hasPendingAutosave) {
      return;
    }

    _debouncedSaveTimer?.cancel();
    _isSaving = true;
    _lastError = null;

    final savedRevision = _revision;
    final documentSnapshot = _cloneDocument(_document);
    _notifySafely();

    try {
      await _storageService.saveToLocal(
        documentSnapshot,
        projectPath: _projectPath,
        projectName: _projectName,
        isDirty: _isDirty,
      );

      _storagePath ??= _projectPath ?? await _storageService.autosavePath;
      _lastSavedAt = DateTime.now();

      if (_revision == savedRevision) {
        _hasPendingAutosave = false;
      }
    } catch (error) {
      _lastError = 'Ошибка автосохранения: $error';
      _hasPendingAutosave = true;
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
    _hasPendingAutosave = true;
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

  Future<void> _waitForActiveSave() async {
    while (_isSaving && !_isDisposed) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
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
