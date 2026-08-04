import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:filmsoz_studio/features/screenplay/development/scene_development.dart';
import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/storage/local_storage_service.dart';
import 'package:filmsoz_studio/features/screenplay/production/production_planning.dart';
import 'package:filmsoz_studio/features/screenplay/management/production_management.dart';
import 'package:path/path.dart' as path;

class BlockMergeResult {
  const BlockMergeResult({
    required this.blockId,
    required this.cursorOffset,
  });

  final String blockId;
  final int cursorOffset;
}

class BlockDeletionResult {
  const BlockDeletionResult({
    required this.focusBlockId,
    required this.cursorOffset,
  });

  final String focusBlockId;
  final int cursorOffset;
}

class BlockInsertionResult {
  const BlockInsertionResult({
    required this.insertedBlockIds,
    required this.focusBlockId,
  });

  final List<String> insertedBlockIds;
  final String focusBlockId;
}

class BlockMoveResult {
  const BlockMoveResult({
    required this.movedBlockIds,
    required this.focusBlockId,
    required this.firstIndex,
  });

  final List<String> movedBlockIds;
  final String focusBlockId;
  final int firstIndex;
}

class SceneMoveResult {
  const SceneMoveResult({
    required this.sceneId,
    required this.sceneNumber,
    required this.blockIds,
  });

  final String sceneId;
  final int sceneNumber;
  final List<String> blockIds;
}

class SceneDuplicateResult {
  const SceneDuplicateResult({
    required this.sceneId,
    required this.sceneNumber,
    required this.blockIds,
  });

  final String sceneId;
  final int sceneNumber;
  final List<String> blockIds;
}

class SceneDeletionResult {
  const SceneDeletionResult({
    required this.focusBlockId,
    required this.activeSceneId,
  });

  final String focusBlockId;
  final String? activeSceneId;
}

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

  List<FilmBlock> copyBlocksByIds(Iterable<String> blockIds) {
    final selectedIds = blockIds.toSet();

    return _document.blocks
        .where((block) => selectedIds.contains(block.id))
        .map(
          (block) => FilmBlock(
            id: block.id,
            type: block.type,
            text: block.text,
          ),
        )
        .toList(growable: false);
  }

  BlockDeletionResult? deleteBlocks(Iterable<String> blockIds) {
    final selectedIds = blockIds.toSet();
    final selectedIndexes = <int>[];

    for (var index = 0; index < _document.blocks.length; index++) {
      if (selectedIds.contains(_document.blocks[index].id)) {
        selectedIndexes.add(index);
      }
    }

    if (selectedIndexes.isEmpty) {
      return null;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();

    final firstSelectedIndex = selectedIndexes.first;
    _document.blocks.removeWhere(
      (block) => selectedIds.contains(block.id),
    );

    if (_document.blocks.isEmpty) {
      _document.blocks.add(
        FilmBlock(
          id: _generateBlockId(),
          type: BlockType.action,
          text: '',
        ),
      );
    }

    final focusIndex = firstSelectedIndex >= _document.blocks.length
        ? _document.blocks.length - 1
        : firstSelectedIndex;
    final focusBlock = _document.blocks[focusIndex];

    _markDocumentChanged();

    return BlockDeletionResult(
      focusBlockId: focusBlock.id,
      cursorOffset: focusBlock.text.length,
    );
  }

  BlockInsertionResult? insertBlocksAfter({
    required String? afterBlockId,
    required Iterable<FilmBlock> blocks,
  }) {
    final sourceBlocks = blocks.toList(growable: false);

    if (sourceBlocks.isEmpty) {
      return null;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();

    final afterIndex = afterBlockId == null
        ? -1
        : _document.blocks.indexWhere((block) => block.id == afterBlockId);
    final insertionIndex =
        afterIndex == -1 ? _document.blocks.length : afterIndex + 1;
    final insertedBlocks = sourceBlocks
        .map(
          (block) => FilmBlock(
            id: _generateBlockId(),
            type: block.type,
            text: block.text,
          ),
        )
        .toList(growable: false);

    _document.blocks.insertAll(insertionIndex, insertedBlocks);
    _markDocumentChanged();

    return BlockInsertionResult(
      insertedBlockIds:
          insertedBlocks.map((block) => block.id).toList(growable: false),
      focusBlockId: insertedBlocks.first.id,
    );
  }

  BlockMoveResult? moveBlocksByOffset({
    required Iterable<String> blockIds,
    required int offset,
    String? focusBlockId,
  }) {
    final requestedIds = blockIds.toSet();
    final selectedIds = _document.blocks
        .where((block) => requestedIds.contains(block.id))
        .map((block) => block.id)
        .toSet();

    if (selectedIds.isEmpty ||
        offset == 0 ||
        _containsSceneHeading(selectedIds)) {
      return null;
    }

    final nextBlocks = List<FilmBlock>.of(_document.blocks);
    var changed = false;

    if (offset < 0) {
      for (var index = 1; index < nextBlocks.length; index++) {
        final currentIsSelected = selectedIds.contains(nextBlocks[index].id);
        final previousIsSelected =
            selectedIds.contains(nextBlocks[index - 1].id);

        if (currentIsSelected && !previousIsSelected) {
          final previousBlock = nextBlocks[index - 1];
          nextBlocks[index - 1] = nextBlocks[index];
          nextBlocks[index] = previousBlock;
          changed = true;
        }
      }
    } else {
      for (var index = nextBlocks.length - 2; index >= 0; index--) {
        final currentIsSelected = selectedIds.contains(nextBlocks[index].id);
        final nextIsSelected = selectedIds.contains(nextBlocks[index + 1].id);

        if (currentIsSelected && !nextIsSelected) {
          final nextBlock = nextBlocks[index + 1];
          nextBlocks[index + 1] = nextBlocks[index];
          nextBlocks[index] = nextBlock;
          changed = true;
        }
      }
    }

    if (!changed) {
      return null;
    }

    return _applyMovedBlockOrder(
      nextBlocks: nextBlocks,
      movedIds: selectedIds,
      focusBlockId: focusBlockId,
    );
  }

  BlockMoveResult? moveBlocksRelativeToTarget({
    required Iterable<String> blockIds,
    required String targetBlockId,
    required bool placeAfter,
    String? focusBlockId,
  }) {
    final requestedIds = blockIds.toSet();
    final selectedIds = _document.blocks
        .where((block) => requestedIds.contains(block.id))
        .map((block) => block.id)
        .toSet();

    if (selectedIds.isEmpty ||
        selectedIds.contains(targetBlockId) ||
        _containsSceneHeading(selectedIds)) {
      return null;
    }

    final movedBlocks = _document.blocks
        .where((block) => selectedIds.contains(block.id))
        .toList(growable: false);

    if (movedBlocks.isEmpty) {
      return null;
    }

    final remainingBlocks = _document.blocks
        .where((block) => !selectedIds.contains(block.id))
        .toList(growable: true);
    final targetIndex = remainingBlocks.indexWhere(
      (block) => block.id == targetBlockId,
    );

    if (targetIndex == -1) {
      return null;
    }

    final insertionIndex = targetIndex + (placeAfter ? 1 : 0);
    remainingBlocks.insertAll(insertionIndex, movedBlocks);

    final currentOrder = _document.blocks.map((block) => block.id).toList();
    final nextOrder = remainingBlocks.map((block) => block.id).toList();

    if (_sameBlockOrder(currentOrder, nextOrder)) {
      return null;
    }

    return _applyMovedBlockOrder(
      nextBlocks: remainingBlocks,
      movedIds: selectedIds,
      focusBlockId: focusBlockId,
    );
  }

  SceneMoveResult? moveSceneByOffset({
    required String sceneId,
    required int offset,
  }) {
    final sceneGroups = _sceneGroups();
    final sceneIndex = sceneGroups.indexWhere(
      (group) => group.first.id == sceneId,
    );

    if (sceneIndex == -1 || offset == 0) {
      return null;
    }

    final targetIndex = sceneIndex + (offset < 0 ? -1 : 1);

    if (targetIndex < 0 || targetIndex >= sceneGroups.length) {
      return null;
    }

    final movedGroup = sceneGroups.removeAt(sceneIndex);
    sceneGroups.insert(targetIndex, movedGroup);

    return _applySceneOrder(
      sceneGroups: sceneGroups,
      movedSceneId: sceneId,
    );
  }

  SceneMoveResult? moveSceneRelativeToTarget({
    required String sceneId,
    required String targetSceneId,
    required bool placeAfter,
  }) {
    if (sceneId == targetSceneId) {
      return null;
    }

    final sceneGroups = _sceneGroups();
    final sourceIndex = sceneGroups.indexWhere(
      (group) => group.first.id == sceneId,
    );

    if (sourceIndex == -1) {
      return null;
    }

    final movedGroup = sceneGroups.removeAt(sourceIndex);
    final targetIndex = sceneGroups.indexWhere(
      (group) => group.first.id == targetSceneId,
    );

    if (targetIndex == -1) {
      return null;
    }

    final insertionIndex = targetIndex + (placeAfter ? 1 : 0);
    sceneGroups.insert(insertionIndex, movedGroup);

    return _applySceneOrder(
      sceneGroups: sceneGroups,
      movedSceneId: sceneId,
    );
  }

  SceneDuplicateResult? duplicateScene(String sceneId) {
    final scenes = _document.sceneSections;
    final sourceIndex = scenes.indexWhere((scene) => scene.id == sceneId);

    if (sourceIndex == -1) {
      return null;
    }

    final sourceScene = scenes[sourceIndex];
    final duplicatedBlocks = sourceScene.blocks
        .map(
          (block) => FilmBlock(
            id: _generateBlockId(),
            type: block.type,
            text: block.text,
          ),
        )
        .toList(growable: false);

    _finishTypingGroup();
    _pushUndoSnapshot();
    _document.blocks.insertAll(
      sourceScene.endIndexExclusive,
      duplicatedBlocks,
    );

    final sourceNote = _document.sceneNote(sceneId);

    if (sourceNote.trim().isNotEmpty) {
      _document.sceneNotes[duplicatedBlocks.first.id] = sourceNote;
    }

    final sourceDevelopment = _document.sceneDevelopment[sceneId];

    if (sourceDevelopment != null) {
      _document.sceneDevelopment[duplicatedBlocks.first.id] = sourceDevelopment;
    }

    final sourceProduction = _document.sceneProduction[sceneId];

    if (sourceProduction != null) {
      _document.sceneProduction[duplicatedBlocks.first.id] = sourceProduction;
    }

    _markDocumentChanged();

    final duplicatedScene = _document.sceneById(duplicatedBlocks.first.id);

    return SceneDuplicateResult(
      sceneId: duplicatedBlocks.first.id,
      sceneNumber: duplicatedScene?.number ?? sourceScene.number + 1,
      blockIds:
          duplicatedBlocks.map((block) => block.id).toList(growable: false),
    );
  }

  SceneDeletionResult? deleteScene(String sceneId) {
    final scenes = _document.sceneSections;
    final sceneIndex = scenes.indexWhere((scene) => scene.id == sceneId);

    if (sceneIndex == -1) {
      return null;
    }

    final scene = scenes[sceneIndex];

    _finishTypingGroup();
    _pushUndoSnapshot();
    _document.blocks.removeRange(
      scene.startIndex,
      scene.endIndexExclusive,
    );
    _document.sceneNotes.remove(sceneId);
    _document.sceneDevelopment.remove(sceneId);
    _document.sceneProduction.remove(sceneId);
    final normalizedBudgetItems = _document.budgetItems.map((item) {
      return item.sceneId == sceneId ? item.copyWith(clearSceneId: true) : item;
    }).toList(growable: false);
    _document.budgetItems
      ..clear()
      ..addAll(normalizedBudgetItems);
    final normalizedShootingDays = _document.shootingDays.map((day) {
      return day.copyWith(
        sceneIds: day.sceneIds
            .where((assignedSceneId) => assignedSceneId != sceneId)
            .toList(growable: false),
      );
    }).toList(growable: false);
    _document.shootingDays
      ..clear()
      ..addAll(normalizedShootingDays);

    if (_document.sceneSections.isEmpty) {
      _document.blocks.add(
        FilmBlock(
          id: _generateBlockId(),
          type: BlockType.sceneHeading,
          text: 'ИНТ. НОВАЯ СЦЕНА - ДЕНЬ',
        ),
      );
    }

    final remainingScenes = _document.sceneSections;
    final targetScene = remainingScenes.isEmpty
        ? null
        : remainingScenes[
            sceneIndex.clamp(0, remainingScenes.length - 1).toInt()];
    final focusBlock = targetScene?.heading ?? _document.blocks.first;

    _markDocumentChanged();

    return SceneDeletionResult(
      focusBlockId: focusBlock.id,
      activeSceneId: targetScene?.id,
    );
  }

  bool setSceneNote(String sceneId, String note) {
    if (_document.sceneById(sceneId) == null) {
      return false;
    }

    final normalizedNote = note.trim();
    final currentNote = _document.sceneNote(sceneId);

    if (currentNote == normalizedNote) {
      return false;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();

    if (normalizedNote.isEmpty) {
      _document.sceneNotes.remove(sceneId);
    } else {
      _document.sceneNotes[sceneId] = normalizedNote;
    }

    _markDocumentChanged();
    return true;
  }

  bool setSceneDevelopment(
    String sceneId, {
    required String summary,
    required SceneWorkStatus status,
    required SceneColorTag colorTag,
  }) {
    if (_document.sceneById(sceneId) == null) {
      return false;
    }

    final nextData = SceneDevelopmentData(
      summary: summary.trim(),
      status: status,
      colorTag: colorTag,
    );
    final currentData = _document.sceneDevelopmentFor(sceneId);

    if (currentData.summary == nextData.summary &&
        currentData.status == nextData.status &&
        currentData.colorTag == nextData.colorTag) {
      return false;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();

    if (nextData.isDefault) {
      _document.sceneDevelopment.remove(sceneId);
    } else {
      _document.sceneDevelopment[sceneId] = nextData;
    }

    _markDocumentChanged();
    return true;
  }

  bool setSceneProduction(
    String sceneId,
    SceneProductionData data,
  ) {
    if (_document.sceneById(sceneId) == null) {
      return false;
    }

    final normalized = SceneProductionData(
      cast: _normalizeProductionList(data.cast),
      extras: data.extras < 0 ? 0 : data.extras,
      locations: _normalizeProductionList(data.locations),
      props: _normalizeProductionList(data.props),
      costumes: _normalizeProductionList(data.costumes),
      makeup: _normalizeProductionList(data.makeup),
      vehicles: _normalizeProductionList(data.vehicles),
      specialEquipment: _normalizeProductionList(data.specialEquipment),
      notes: data.notes.trim(),
      estimatedSetupMinutes:
          data.estimatedSetupMinutes < 0 ? 0 : data.estimatedSetupMinutes,
      estimatedShootMinutes:
          data.estimatedShootMinutes < 0 ? 0 : data.estimatedShootMinutes,
      priority: data.priority,
    );
    final current = _document.sceneProductionFor(sceneId);

    if (_sameSceneProductionData(current, normalized)) {
      return false;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();

    if (normalized.isDefault) {
      _document.sceneProduction.remove(sceneId);
    } else {
      _document.sceneProduction[sceneId] = normalized;
    }

    _markDocumentChanged();
    return true;
  }

  String createShootingDay({String? title}) {
    final dayNumber = _document.shootingDays.length + 1;
    final dayId = 'shooting_${_generateBlockId()}';
    final normalizedTitle = title?.trim();
    final day = ShootingDayPlan(
      id: dayId,
      title: normalizedTitle == null || normalizedTitle.isEmpty
          ? 'Съёмочный день $dayNumber'
          : normalizedTitle,
    );

    _finishTypingGroup();
    _pushUndoSnapshot();
    _document.shootingDays.add(day);
    _markDocumentChanged();
    return dayId;
  }

  bool updateShootingDay(ShootingDayPlan day) {
    final index = _document.shootingDays.indexWhere(
      (item) => item.id == day.id,
    );

    if (index == -1) {
      return false;
    }

    final validSceneIds =
        _document.sceneSections.map((scene) => scene.id).toSet();
    final normalized = day.copyWith(
      title: day.title.trim().isEmpty ? 'Съёмочный день' : day.title.trim(),
      date: day.date.trim(),
      location: day.location.trim(),
      crewCall: day.crewCall.trim(),
      firstShot: day.firstShot.trim(),
      estimatedWrap: day.estimatedWrap.trim(),
      sceneIds: day.sceneIds
          .where(validSceneIds.contains)
          .toSet()
          .toList(growable: false),
      notes: day.notes.trim(),
    );
    final current = _document.shootingDays[index];

    if (_sameShootingDay(current, normalized)) {
      return false;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();
    _document.shootingDays[index] = normalized;
    _markDocumentChanged();
    return true;
  }

  bool deleteShootingDay(String dayId) {
    final index = _document.shootingDays.indexWhere(
      (day) => day.id == dayId,
    );

    if (index == -1) {
      return false;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();
    _document.shootingDays.removeAt(index);
    final normalizedBudgetItems = _document.budgetItems.map((item) {
      return item.shootingDayId == dayId
          ? item.copyWith(clearShootingDayId: true)
          : item;
    }).toList(growable: false);
    _document.budgetItems
      ..clear()
      ..addAll(normalizedBudgetItems);
    _markDocumentChanged();
    return true;
  }

  bool moveShootingDay(String dayId, int offset) {
    final index = _document.shootingDays.indexWhere(
      (day) => day.id == dayId,
    );
    final targetIndex = index + (offset < 0 ? -1 : 1);

    if (index == -1 ||
        offset == 0 ||
        targetIndex < 0 ||
        targetIndex >= _document.shootingDays.length) {
      return false;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();
    final day = _document.shootingDays.removeAt(index);
    _document.shootingDays.insert(targetIndex, day);
    _markDocumentChanged();
    return true;
  }

  String createProductionPerson({
    String name = 'Новый участник',
    ProductionPersonType type = ProductionPersonType.crew,
  }) {
    final id = 'person_${_generateBlockId()}';
    final person = ProductionPerson(
      id: id,
      name: name.trim().isEmpty ? 'Новый участник' : name.trim(),
      type: type,
      department: type == ProductionPersonType.cast
          ? CrewDepartment.cast
          : CrewDepartment.other,
    );

    _finishTypingGroup();
    _pushUndoSnapshot();
    _document.productionPeople.add(person);
    _markDocumentChanged();
    return id;
  }

  bool updateProductionPerson(ProductionPerson person) {
    final index = _document.productionPeople.indexWhere(
      (item) => item.id == person.id,
    );

    if (index == -1) {
      return false;
    }

    final normalized = ProductionPerson(
      id: person.id,
      name: person.name.trim().isEmpty ? 'Без имени' : person.name.trim(),
      type: person.type,
      department: person.type == ProductionPersonType.cast
          ? CrewDepartment.cast
          : person.department,
      jobTitle: person.jobTitle.trim(),
      phone: person.phone.trim(),
      email: person.email.trim(),
      notes: person.notes.trim(),
      linkedCharacters: _normalizeProductionList(person.linkedCharacters)
          .map((value) => value.toUpperCase())
          .toList(growable: false),
      unavailableDates: _normalizeProductionList(person.unavailableDates),
      dailyRate: person.dailyRate < 0 ? 0 : person.dailyRate,
    );
    final current = _document.productionPeople[index];

    if (_sameProductionPerson(current, normalized)) {
      return false;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();
    _document.productionPeople[index] = normalized;
    _markDocumentChanged();
    return true;
  }

  bool deleteProductionPerson(String personId) {
    final index = _document.productionPeople.indexWhere(
      (person) => person.id == personId,
    );

    if (index == -1) {
      return false;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();
    _document.productionPeople.removeAt(index);
    _markDocumentChanged();
    return true;
  }

  String createBudgetItem({
    String title = 'Новая статья',
    BudgetCategory category = BudgetCategory.other,
  }) {
    final id = 'budget_${_generateBlockId()}';
    final item = BudgetItem(
      id: id,
      title: title.trim().isEmpty ? 'Новая статья' : title.trim(),
      category: category,
    );

    _finishTypingGroup();
    _pushUndoSnapshot();
    _document.budgetItems.add(item);
    _markDocumentChanged();
    return id;
  }

  bool updateBudgetItem(BudgetItem item) {
    final index = _document.budgetItems.indexWhere(
      (entry) => entry.id == item.id,
    );

    if (index == -1) {
      return false;
    }

    final validSceneIds =
        _document.sceneSections.map((scene) => scene.id).toSet();
    final validDayIds = _document.shootingDays.map((day) => day.id).toSet();
    final normalizedSceneId =
        item.sceneId != null && validSceneIds.contains(item.sceneId)
            ? item.sceneId
            : null;
    final normalizedDayId =
        item.shootingDayId != null && validDayIds.contains(item.shootingDayId)
            ? item.shootingDayId
            : null;
    final normalized = BudgetItem(
      id: item.id,
      title: item.title.trim().isEmpty ? 'Статья бюджета' : item.title.trim(),
      category: item.category,
      plannedAmount: item.plannedAmount < 0 ? 0 : item.plannedAmount,
      actualAmount: item.actualAmount < 0 ? 0 : item.actualAmount,
      paidAmount: item.paidAmount < 0 ? 0 : item.paidAmount,
      payee: item.payee.trim(),
      sceneId: normalizedSceneId,
      shootingDayId: normalizedDayId,
      notes: item.notes.trim(),
    );
    final current = _document.budgetItems[index];

    if (_sameBudgetItem(current, normalized)) {
      return false;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();
    _document.budgetItems[index] = normalized;
    _markDocumentChanged();
    return true;
  }

  bool deleteBudgetItem(String itemId) {
    final index = _document.budgetItems.indexWhere(
      (item) => item.id == itemId,
    );

    if (index == -1) {
      return false;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();
    _document.budgetItems.removeAt(index);
    _markDocumentChanged();
    return true;
  }

  bool setBudgetCurrency(String currency) {
    final normalized = currency.trim().toUpperCase();

    if (normalized.isEmpty || normalized == _document.budgetCurrency) {
      return false;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();
    _document.budgetCurrency = normalized;
    _markDocumentChanged();
    return true;
  }

  bool _sameProductionPerson(
    ProductionPerson first,
    ProductionPerson second,
  ) {
    return first.name == second.name &&
        first.type == second.type &&
        first.department == second.department &&
        first.jobTitle == second.jobTitle &&
        first.phone == second.phone &&
        first.email == second.email &&
        first.notes == second.notes &&
        _sameStringLists(first.linkedCharacters, second.linkedCharacters) &&
        _sameStringLists(first.unavailableDates, second.unavailableDates) &&
        first.dailyRate == second.dailyRate;
  }

  bool _sameBudgetItem(BudgetItem first, BudgetItem second) {
    return first.title == second.title &&
        first.category == second.category &&
        first.plannedAmount == second.plannedAmount &&
        first.actualAmount == second.actualAmount &&
        first.paidAmount == second.paidAmount &&
        first.payee == second.payee &&
        first.sceneId == second.sceneId &&
        first.shootingDayId == second.shootingDayId &&
        first.notes == second.notes;
  }

  List<String> _normalizeProductionList(Iterable<String> values) {
    final result = <String>[];
    final seen = <String>{};

    for (final value in values) {
      final normalized = value.trim();

      if (normalized.isEmpty || !seen.add(normalized.toUpperCase())) {
        continue;
      }

      result.add(normalized);
    }

    return result;
  }

  bool _sameSceneProductionData(
    SceneProductionData first,
    SceneProductionData second,
  ) {
    return _sameStringLists(first.cast, second.cast) &&
        first.extras == second.extras &&
        _sameStringLists(first.locations, second.locations) &&
        _sameStringLists(first.props, second.props) &&
        _sameStringLists(first.costumes, second.costumes) &&
        _sameStringLists(first.makeup, second.makeup) &&
        _sameStringLists(first.vehicles, second.vehicles) &&
        _sameStringLists(first.specialEquipment, second.specialEquipment) &&
        first.notes == second.notes &&
        first.estimatedSetupMinutes == second.estimatedSetupMinutes &&
        first.estimatedShootMinutes == second.estimatedShootMinutes &&
        first.priority == second.priority;
  }

  bool _sameShootingDay(ShootingDayPlan first, ShootingDayPlan second) {
    return first.id == second.id &&
        first.title == second.title &&
        first.date == second.date &&
        first.location == second.location &&
        first.crewCall == second.crewCall &&
        first.firstShot == second.firstShot &&
        first.estimatedWrap == second.estimatedWrap &&
        _sameStringLists(first.sceneIds, second.sceneIds) &&
        first.notes == second.notes &&
        first.status == second.status;
  }

  bool _sameStringLists(List<String> first, List<String> second) {
    if (first.length != second.length) {
      return false;
    }

    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) {
        return false;
      }
    }

    return true;
  }

  bool setScreenplayGoals(ScreenplayGoals goals) {
    final normalized = ScreenplayGoals(
      targetSceneCount: goals.targetSceneCount < 0 ? 0 : goals.targetSceneCount,
      targetPageCount: goals.targetPageCount < 0 ? 0 : goals.targetPageCount,
      targetMinutes: goals.targetMinutes < 0 ? 0 : goals.targetMinutes,
    );
    final current = _document.goals;

    if (current.targetSceneCount == normalized.targetSceneCount &&
        current.targetPageCount == normalized.targetPageCount &&
        current.targetMinutes == normalized.targetMinutes) {
      return false;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();
    _document.goals = normalized;
    _markDocumentChanged();
    return true;
  }

  int replaceAllText(
    String query,
    String replacement, {
    bool matchCase = false,
  }) {
    final normalizedQuery = query.trim();

    if (normalizedQuery.isEmpty) {
      return 0;
    }

    final expression = RegExp(
      RegExp.escape(normalizedQuery),
      caseSensitive: matchCase,
    );
    var matchCount = 0;

    for (final block in _document.blocks) {
      matchCount += expression.allMatches(block.text).length;
    }

    if (matchCount == 0) {
      return 0;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();

    for (final block in _document.blocks) {
      block.text = block.text.replaceAllMapped(
        expression,
        (_) => replacement,
      );
    }

    _markDocumentChanged();
    return matchCount;
  }

  List<List<FilmBlock>> _sceneGroups() {
    return _document.sceneSections
        .map((scene) => List<FilmBlock>.of(scene.blocks))
        .toList(growable: true);
  }

  List<FilmBlock> _blocksBeforeFirstScene() {
    final scenes = _document.sceneSections;

    if (scenes.isEmpty || scenes.first.startIndex == 0) {
      return <FilmBlock>[];
    }

    return List<FilmBlock>.of(
      _document.blocks.sublist(0, scenes.first.startIndex),
    );
  }

  SceneMoveResult? _applySceneOrder({
    required List<List<FilmBlock>> sceneGroups,
    required String movedSceneId,
  }) {
    final prefixBlocks = _blocksBeforeFirstScene();
    final nextBlocks = <FilmBlock>[
      ...prefixBlocks,
      for (final group in sceneGroups) ...group,
    ];
    final currentOrder = _document.blocks.map((block) => block.id).toList();
    final nextOrder = nextBlocks.map((block) => block.id).toList();

    if (_sameBlockOrder(currentOrder, nextOrder)) {
      return null;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();
    _document.blocks
      ..clear()
      ..addAll(nextBlocks);
    _markDocumentChanged();

    final movedScene = _document.sceneById(movedSceneId)!;

    return SceneMoveResult(
      sceneId: movedSceneId,
      sceneNumber: movedScene.number,
      blockIds: movedScene.blockIds,
    );
  }

  BlockMoveResult _applyMovedBlockOrder({
    required List<FilmBlock> nextBlocks,
    required Set<String> movedIds,
    String? focusBlockId,
  }) {
    _finishTypingGroup();
    _pushUndoSnapshot();

    _document.blocks
      ..clear()
      ..addAll(nextBlocks);

    final movedBlockIds = nextBlocks
        .where((block) => movedIds.contains(block.id))
        .map((block) => block.id)
        .toList(growable: false);
    final safeFocusBlockId =
        focusBlockId != null && movedIds.contains(focusBlockId)
            ? focusBlockId
            : movedBlockIds.first;

    _markDocumentChanged();

    return BlockMoveResult(
      movedBlockIds: movedBlockIds,
      focusBlockId: safeFocusBlockId,
      firstIndex: nextBlocks.indexWhere(
        (block) => movedIds.contains(block.id),
      ),
    );
  }

  bool _containsSceneHeading(Set<String> blockIds) {
    return _document.blocks.any(
      (block) =>
          blockIds.contains(block.id) && block.type == BlockType.sceneHeading,
    );
  }

  bool _sameBlockOrder(List<String> first, List<String> second) {
    if (first.length != second.length) {
      return false;
    }

    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) {
        return false;
      }
    }

    return true;
  }

  BlockMergeResult? mergeBlockWithPrevious(String id) {
    final index = _document.blocks.indexWhere((block) => block.id == id);

    if (index <= 0 || _document.blocks.length <= 1) {
      return null;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();

    final previousBlock = _document.blocks[index - 1];
    final currentBlock = _document.blocks[index];
    final cursorOffset = previousBlock.text.length;

    previousBlock.text = '${previousBlock.text}${currentBlock.text}';
    _document.blocks.removeAt(index);
    _markDocumentChanged();

    return BlockMergeResult(
      blockId: previousBlock.id,
      cursorOffset: cursorOffset,
    );
  }

  BlockMergeResult? mergeBlockWithNext(String id) {
    final index = _document.blocks.indexWhere((block) => block.id == id);

    if (index == -1 || index >= _document.blocks.length - 1) {
      return null;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();

    final currentBlock = _document.blocks[index];
    final nextBlock = _document.blocks[index + 1];
    final cursorOffset = currentBlock.text.length;

    currentBlock.text = '${currentBlock.text}${nextBlock.text}';
    _document.blocks.removeAt(index + 1);
    _markDocumentChanged();

    return BlockMergeResult(
      blockId: currentBlock.id,
      cursorOffset: cursorOffset,
    );
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
      sceneNotes: source.sceneNotes,
      sceneDevelopment: source.sceneDevelopment,
      sceneProduction: source.sceneProduction,
      shootingDays: source.shootingDays,
      productionPeople: source.productionPeople,
      budgetItems: source.budgetItems,
      budgetCurrency: source.budgetCurrency,
      goals: source.goals,
    );
  }

  void _markDocumentChanged() {
    _removeOrphanedSceneNotes();
    _revision++;
    _isDirty = true;
    _hasPendingAutosave = true;
    _lastError = null;
    _scheduleDebouncedSave();
    _notifySafely();
  }

  void _removeOrphanedSceneNotes() {
    final validSceneIds = _document.blocks
        .where((block) => block.type == BlockType.sceneHeading)
        .map((block) => block.id)
        .toSet();

    _document.sceneNotes.removeWhere(
      (sceneId, _) => !validSceneIds.contains(sceneId),
    );
    _document.sceneDevelopment.removeWhere(
      (sceneId, _) => !validSceneIds.contains(sceneId),
    );
    _document.sceneProduction.removeWhere(
      (sceneId, _) => !validSceneIds.contains(sceneId),
    );

    final normalizedDays = _document.shootingDays.map((day) {
      return day.copyWith(
        sceneIds: day.sceneIds
            .where(validSceneIds.contains)
            .toSet()
            .toList(growable: false),
      );
    }).toList(growable: false);

    _document.shootingDays
      ..clear()
      ..addAll(normalizedDays);

    final validDayIds = normalizedDays.map((day) => day.id).toSet();
    final normalizedBudgetItems = _document.budgetItems.map((item) {
      return item.copyWith(
        clearSceneId:
            item.sceneId != null && !validSceneIds.contains(item.sceneId),
        clearShootingDayId: item.shootingDayId != null &&
            !validDayIds.contains(item.shootingDayId),
      );
    }).toList(growable: false);

    _document.budgetItems
      ..clear()
      ..addAll(normalizedBudgetItems);
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
