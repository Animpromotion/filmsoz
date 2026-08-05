import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:filmsoz_studio/features/screenplay/creative/creative_material.dart';
import 'package:filmsoz_studio/features/screenplay/development/scene_development.dart';
import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/storage/local_storage_service.dart';
import 'package:filmsoz_studio/features/screenplay/production/production_planning.dart';
import 'package:filmsoz_studio/features/screenplay/postproduction/postproduction.dart';
import 'package:filmsoz_studio/features/screenplay/management/production_management.dart';
import 'package:filmsoz_studio/features/screenplay/shooting_control/shooting_control.dart';
import 'package:filmsoz_studio/features/screenplay/storyboard/storyboard_shot.dart';
import 'package:filmsoz_studio/features/screenplay/versioning/project_versioning.dart';
import 'package:filmsoz_studio/features/screenplay/versioning/project_versioning_file_service.dart';
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
  ScreenplayEditorController({
    LocalStorageService? storageService,
    ProjectVersioningFileService? versioningFileService,
  })  : _storageService = storageService ?? LocalStorageService(),
        _versioningFileService =
            versioningFileService ?? const ProjectVersioningFileService();

  static const int _historyLimit = 100;
  static const Duration _typingGroupDelay = Duration(milliseconds: 850);

  final LocalStorageService _storageService;
  final ProjectVersioningFileService _versioningFileService;

  FilmDocument _document = FilmDocument.empty();
  final List<FilmDocument> _undoStack = <FilmDocument>[];
  final List<FilmDocument> _redoStack = <FilmDocument>[];

  Timer? _periodicSaveTimer;
  Timer? _debouncedSaveTimer;
  Timer? _typingGroupTimer;
  Timer? _automaticBackupTimer;

  bool _isInitialized = false;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDirty = false;
  bool _hasPendingAutosave = false;
  bool _saveRequestedWhileSaving = false;
  bool _isDisposed = false;
  bool _isCreatingAutomaticBackup = false;

  int _idCounter = 0;
  int _revision = 0;
  int _lastAutomaticBackupRevision = -1;
  String? _typingBlockId;

  DateTime? _lastSavedAt;
  DateTime? _lastProjectSavedAt;
  DateTime? _lastAutomaticBackupAt;
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
  DateTime? get lastAutomaticBackupAt => _lastAutomaticBackupAt;
  bool get isCreatingAutomaticBackup => _isCreatingAutomaticBackup;

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
      _startAutomaticBackupTimer();
      _lastAutomaticBackupAt ??= DateTime.now();
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

    final duplicatedTakeIds = <String, String>{};
    final sourceShots = _document.storyboardShots[sceneId];

    if (sourceShots != null && sourceShots.isNotEmpty) {
      final duplicatedShots = <StoryboardShot>[];

      for (final sourceShot in sourceShots) {
        final duplicatedShotId = 'shot_${_generateBlockId()}';
        duplicatedShots.add(sourceShot.copyWith(id: duplicatedShotId));

        final sourceTakes = _document.shotTakes[sourceShot.id];

        if (sourceTakes != null && sourceTakes.isNotEmpty) {
          final duplicatedTakes = <ShotTake>[];

          for (final take in sourceTakes) {
            final duplicatedTakeId = 'take_${_generateBlockId()}';
            duplicatedTakeIds[take.id] = duplicatedTakeId;
            duplicatedTakes.add(take.copyWith(id: duplicatedTakeId));
          }

          _document.shotTakes[duplicatedShotId] = duplicatedTakes;
        }
      }

      _document.storyboardShots[duplicatedBlocks.first.id] = duplicatedShots;
    }

    final sourcePostProduction = _document.scenePostProduction[sceneId];

    if (sourcePostProduction != null) {
      final duplicatedPostProduction = sourcePostProduction.copyWith(
        selectedTakeIds: sourcePostProduction.selectedTakeIds
            .map((takeId) => duplicatedTakeIds[takeId])
            .whereType<String>()
            .toList(growable: false),
      );

      if (!duplicatedPostProduction.isDefault) {
        _document.scenePostProduction[duplicatedBlocks.first.id] =
            duplicatedPostProduction;
      }
    }

    final normalizedSequences =
        _document.postProductionSequences.map((sequence) {
      final sourceIndex = sequence.sceneIds.indexOf(sceneId);

      if (sourceIndex == -1) {
        return sequence;
      }

      final sceneIds = List<String>.of(sequence.sceneIds)
        ..insert(sourceIndex + 1, duplicatedBlocks.first.id);
      return sequence.copyWith(sceneIds: sceneIds);
    }).toList(growable: false);
    _document.postProductionSequences
      ..clear()
      ..addAll(normalizedSequences);

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
    _document.scenePostProduction.remove(sceneId);
    final removedShots = _document.storyboardShots.remove(sceneId);

    final removedShotIds = <String>{};

    if (removedShots != null) {
      for (final shot in removedShots) {
        removedShotIds.add(shot.id);
        _document.shotTakes.remove(shot.id);
      }
    }

    final normalizedSequences =
        _document.postProductionSequences.map((sequence) {
      return sequence.copyWith(
        sceneIds: sequence.sceneIds
            .where((assignedSceneId) => assignedSceneId != sceneId)
            .toList(growable: false),
      );
    }).toList(growable: false);
    _document.postProductionSequences
      ..clear()
      ..addAll(normalizedSequences);

    final normalizedPostTasks = _document.postProductionTasks.map((task) {
      return task.sceneId == sceneId ? task.copyWith(clearSceneId: true) : task;
    }).toList(growable: false);
    _document.postProductionTasks
      ..clear()
      ..addAll(normalizedPostTasks);

    final normalizedMissingMaterials = _document.missingMaterials.map((item) {
      return item.copyWith(
        clearSceneId: item.sceneId == sceneId,
        clearShotId:
            item.shotId != null && removedShotIds.contains(item.shotId),
      );
    }).toList(growable: false);
    _document.missingMaterials
      ..clear()
      ..addAll(normalizedMissingMaterials);

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

  String? createStoryboardShot(
    String sceneId, {
    StoryboardShot? template,
  }) {
    if (_document.sceneById(sceneId) == null) {
      return null;
    }

    final id = 'shot_${_generateBlockId()}';
    final source = template;
    final shot =
        source == null ? StoryboardShot(id: id) : source.copyWith(id: id);

    _finishTypingGroup();
    _pushUndoSnapshot();
    _document.storyboardShots
        .putIfAbsent(sceneId, () => <StoryboardShot>[])
        .add(_normalizeStoryboardShot(shot));
    _markDocumentChanged();
    return id;
  }

  bool updateStoryboardShot(String sceneId, StoryboardShot shot) {
    final shots = _document.storyboardShots[sceneId];

    if (shots == null) {
      return false;
    }

    final index = shots.indexWhere((item) => item.id == shot.id);

    if (index == -1) {
      return false;
    }

    final normalized = _normalizeStoryboardShot(shot);
    final current = shots[index];

    if (_sameStoryboardShot(current, normalized)) {
      return false;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();
    shots[index] = normalized;
    _markDocumentChanged();
    return true;
  }

  String? duplicateStoryboardShot(String sceneId, String shotId) {
    final source = _document.storyboardShotById(sceneId, shotId);

    if (source == null) {
      return null;
    }

    final shots = _document.storyboardShots[sceneId]!;
    final sourceIndex = shots.indexWhere((shot) => shot.id == shotId);
    final id = 'shot_${_generateBlockId()}';
    final duplicate = source.copyWith(id: id);

    _finishTypingGroup();
    _pushUndoSnapshot();
    shots.insert(sourceIndex + 1, duplicate);
    final sourceTakes = _document.shotTakes[source.id];

    if (sourceTakes != null && sourceTakes.isNotEmpty) {
      _document.shotTakes[id] = sourceTakes
          .map(
            (take) => take.copyWith(
              id: 'take_${_generateBlockId()}',
            ),
          )
          .toList(growable: true);
    }

    _markDocumentChanged();
    return id;
  }

  bool deleteStoryboardShot(String sceneId, String shotId) {
    final shots = _document.storyboardShots[sceneId];

    if (shots == null) {
      return false;
    }

    final index = shots.indexWhere((shot) => shot.id == shotId);

    if (index == -1) {
      return false;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();
    final removedTakeIds = (_document.shotTakes[shotId] ?? const <ShotTake>[])
        .map((take) => take.id)
        .toSet();
    shots.removeAt(index);
    _document.shotTakes.remove(shotId);

    final currentPostProduction = _document.scenePostProduction[sceneId];

    if (currentPostProduction != null) {
      final normalized = currentPostProduction.copyWith(
        selectedTakeIds: currentPostProduction.selectedTakeIds
            .where((takeId) => !removedTakeIds.contains(takeId))
            .toList(growable: false),
      );

      if (normalized.isDefault) {
        _document.scenePostProduction.remove(sceneId);
      } else {
        _document.scenePostProduction[sceneId] = normalized;
      }
    }

    final normalizedMissingMaterials = _document.missingMaterials.map((item) {
      return item.shotId == shotId ? item.copyWith(clearShotId: true) : item;
    }).toList(growable: false);
    _document.missingMaterials
      ..clear()
      ..addAll(normalizedMissingMaterials);

    if (shots.isEmpty) {
      _document.storyboardShots.remove(sceneId);
    }

    _markDocumentChanged();
    return true;
  }

  bool moveStoryboardShot(
    String sceneId, {
    required int oldIndex,
    required int newIndex,
  }) {
    final shots = _document.storyboardShots[sceneId];

    if (shots == null ||
        oldIndex < 0 ||
        oldIndex >= shots.length ||
        newIndex < 0 ||
        newIndex >= shots.length ||
        oldIndex == newIndex) {
      return false;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();
    final shot = shots.removeAt(oldIndex);
    shots.insert(newIndex, shot);
    _markDocumentChanged();
    return true;
  }

  String? createShotTake(
    String shotId, {
    ShotTake? template,
    String? shootingDayId,
  }) {
    if (!_allStoryboardShotIds().contains(shotId)) {
      return null;
    }

    final takes = _document.shotTakes[shotId] ?? const <ShotTake>[];
    final id = 'take_${_generateBlockId()}';
    var nextTakeNumber = 1;

    for (final take in takes) {
      if (take.takeNumber >= nextTakeNumber) {
        nextTakeNumber = take.takeNumber + 1;
      }
    }
    final source = template;
    final take = source == null
        ? ShotTake(
            id: id,
            takeNumber: nextTakeNumber,
            shootingDayId: _validShootingDayId(shootingDayId),
          )
        : source.copyWith(
            id: id,
            takeNumber: nextTakeNumber,
            shootingDayId: _validShootingDayId(
              shootingDayId ?? source.shootingDayId,
            ),
            clearShootingDayId:
                _validShootingDayId(shootingDayId ?? source.shootingDayId) ==
                    null,
          );

    _finishTypingGroup();
    _pushUndoSnapshot();
    _document.shotTakes
        .putIfAbsent(shotId, () => <ShotTake>[])
        .add(_normalizeShotTake(take));
    _markDocumentChanged();
    return id;
  }

  bool updateShotTake(String shotId, ShotTake take) {
    final takes = _document.shotTakes[shotId];

    if (takes == null) {
      return false;
    }

    final index = takes.indexWhere((item) => item.id == take.id);

    if (index == -1) {
      return false;
    }

    final normalized = _normalizeShotTake(take);
    final current = takes[index];

    if (_sameShotTake(current, normalized)) {
      return false;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();

    if (normalized.status == ShotTakeStatus.selected) {
      for (var takeIndex = 0; takeIndex < takes.length; takeIndex++) {
        final other = takes[takeIndex];

        if (other.id != normalized.id &&
            other.status == ShotTakeStatus.selected) {
          takes[takeIndex] = other.copyWith(status: ShotTakeStatus.recorded);
        }
      }
    }

    takes[index] = normalized;
    _markDocumentChanged();
    return true;
  }

  String? duplicateShotTake(String shotId, String takeId) {
    final source = _document.shotTakeById(shotId, takeId);

    if (source == null) {
      return null;
    }

    return createShotTake(
      shotId,
      template: source.copyWith(
        status: source.status == ShotTakeStatus.selected
            ? ShotTakeStatus.recorded
            : source.status,
      ),
      shootingDayId: source.shootingDayId,
    );
  }

  bool deleteShotTake(String shotId, String takeId) {
    final takes = _document.shotTakes[shotId];

    if (takes == null) {
      return false;
    }

    final index = takes.indexWhere((take) => take.id == takeId);

    if (index == -1) {
      return false;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();
    takes.removeAt(index);

    for (final entry in _document.scenePostProduction.entries.toList()) {
      if (!entry.value.selectedTakeIds.contains(takeId)) {
        continue;
      }

      final normalized = entry.value.copyWith(
        selectedTakeIds: entry.value.selectedTakeIds
            .where((selectedId) => selectedId != takeId)
            .toList(growable: false),
      );

      if (normalized.isDefault) {
        _document.scenePostProduction.remove(entry.key);
      } else {
        _document.scenePostProduction[entry.key] = normalized;
      }
    }

    if (takes.isEmpty) {
      _document.shotTakes.remove(shotId);
    }

    _markDocumentChanged();
    return true;
  }

  bool setShootingDayJournal(
    String dayId,
    ShootingDayJournal journal,
  ) {
    if (_document.shootingDayById(dayId) == null) {
      return false;
    }

    final normalized = _normalizeShootingDayJournal(journal);
    final current = _document.shootingDayJournalFor(dayId);

    if (_sameShootingDayJournal(current, normalized)) {
      return false;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();

    if (normalized.isDefault) {
      _document.shootingDayJournals.remove(dayId);
    } else {
      _document.shootingDayJournals[dayId] = normalized;
    }

    _markDocumentChanged();
    return true;
  }

  bool setScenePostProduction(
    String sceneId,
    ScenePostProductionData data,
  ) {
    if (_document.sceneById(sceneId) == null) {
      return false;
    }

    final validTakeIds = _takeIdsForScene(sceneId);
    final normalized = ScenePostProductionData(
      status: data.status,
      progress: data.progress.clamp(0, 100).toInt(),
      editorNotes: data.editorNotes.trim(),
      directorNotes: data.directorNotes.trim(),
      selectedTakeIds: data.selectedTakeIds
          .where(validTakeIds.contains)
          .toSet()
          .toList(growable: false),
      directorApproval: data.directorApproval,
      producerApproval: data.producerApproval,
    );
    final current = _document.scenePostProductionFor(sceneId);

    if (_sameScenePostProduction(current, normalized)) {
      return false;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();

    if (normalized.isDefault) {
      _document.scenePostProduction.remove(sceneId);
    } else {
      _document.scenePostProduction[sceneId] = normalized;
    }

    _markDocumentChanged();
    return true;
  }

  String createPostProductionSequence({String? title}) {
    final id = 'sequence_${_generateBlockId()}';
    final normalizedTitle = title?.trim();
    final sequence = PostProductionSequence(
      id: id,
      title: normalizedTitle == null || normalizedTitle.isEmpty
          ? 'Монтажный эпизод ${_document.postProductionSequences.length + 1}'
          : normalizedTitle,
    );

    _finishTypingGroup();
    _pushUndoSnapshot();
    _document.postProductionSequences.add(sequence);
    _markDocumentChanged();
    return id;
  }

  bool updatePostProductionSequence(PostProductionSequence sequence) {
    final index = _document.postProductionSequences.indexWhere(
      (item) => item.id == sequence.id,
    );

    if (index == -1) {
      return false;
    }

    final validSceneIds =
        _document.sceneSections.map((scene) => scene.id).toSet();
    final normalized = PostProductionSequence(
      id: sequence.id,
      title: sequence.title.trim().isEmpty
          ? 'Монтажный эпизод'
          : sequence.title.trim(),
      sceneIds: sequence.sceneIds
          .where(validSceneIds.contains)
          .toSet()
          .toList(growable: false),
      notes: sequence.notes.trim(),
    );
    final current = _document.postProductionSequences[index];

    if (_samePostProductionSequence(current, normalized)) {
      return false;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();
    _document.postProductionSequences[index] = normalized;
    _markDocumentChanged();
    return true;
  }

  bool deletePostProductionSequence(String sequenceId) {
    final index = _document.postProductionSequences.indexWhere(
      (item) => item.id == sequenceId,
    );

    if (index == -1) {
      return false;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();
    _document.postProductionSequences.removeAt(index);

    final normalizedVersions = _document.editVersions.map((version) {
      return version.sequenceId == sequenceId
          ? version.copyWith(clearSequenceId: true)
          : version;
    }).toList(growable: false);
    _document.editVersions
      ..clear()
      ..addAll(normalizedVersions);
    _markDocumentChanged();
    return true;
  }

  String createEditVersion({String? sequenceId}) {
    final validSequenceId = _document
        .postProductionSequenceById(
          sequenceId ?? '',
        )
        ?.id;
    final versions = _document.editVersions.where(
      (version) => version.sequenceId == validSequenceId,
    );
    var nextVersionNumber = 1;

    for (final version in versions) {
      if (version.versionNumber >= nextVersionNumber) {
        nextVersionNumber = version.versionNumber + 1;
      }
    }

    final id = 'version_${_generateBlockId()}';
    final version = EditVersion(
      id: id,
      title: 'Версия монтажа $nextVersionNumber',
      sequenceId: validSequenceId,
      versionNumber: nextVersionNumber,
      createdAt: DateTime.now().toIso8601String().split('T').first,
      isCurrent: true,
    );

    _finishTypingGroup();
    _pushUndoSnapshot();

    for (var index = 0; index < _document.editVersions.length; index++) {
      final other = _document.editVersions[index];

      if (other.sequenceId == validSequenceId && other.isCurrent) {
        _document.editVersions[index] = other.copyWith(isCurrent: false);
      }
    }

    _document.editVersions.add(version);
    _markDocumentChanged();
    return id;
  }

  bool updateEditVersion(EditVersion version) {
    final index = _document.editVersions.indexWhere(
      (item) => item.id == version.id,
    );

    if (index == -1) {
      return false;
    }

    final validSequenceId = _document
        .postProductionSequenceById(
          version.sequenceId ?? '',
        )
        ?.id;
    final normalized = EditVersion(
      id: version.id,
      title: version.title.trim().isEmpty
          ? 'Версия монтажа'
          : version.title.trim(),
      sequenceId: validSequenceId,
      versionNumber: version.versionNumber <= 0 ? 1 : version.versionNumber,
      application: version.application.trim(),
      filePath: version.filePath.trim(),
      createdAt: version.createdAt.trim(),
      durationSeconds:
          version.durationSeconds < 0 ? 0 : version.durationSeconds,
      notes: version.notes.trim(),
      isCurrent: version.isCurrent,
    );
    final current = _document.editVersions[index];

    if (_sameEditVersion(current, normalized)) {
      return false;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();

    if (normalized.isCurrent) {
      for (var itemIndex = 0;
          itemIndex < _document.editVersions.length;
          itemIndex++) {
        final other = _document.editVersions[itemIndex];

        if (other.id != normalized.id &&
            other.sequenceId == normalized.sequenceId &&
            other.isCurrent) {
          _document.editVersions[itemIndex] = other.copyWith(isCurrent: false);
        }
      }
    }

    _document.editVersions[index] = normalized;
    _markDocumentChanged();
    return true;
  }

  bool deleteEditVersion(String versionId) {
    final index = _document.editVersions.indexWhere(
      (item) => item.id == versionId,
    );

    if (index == -1) {
      return false;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();
    _document.editVersions.removeAt(index);

    final normalizedTasks = _document.postProductionTasks.map((task) {
      return task.versionId == versionId
          ? task.copyWith(clearVersionId: true)
          : task;
    }).toList(growable: false);
    _document.postProductionTasks
      ..clear()
      ..addAll(normalizedTasks);
    _markDocumentChanged();
    return true;
  }

  String createPostProductionTask({String? sceneId}) {
    final validSceneId = _document.sceneById(sceneId ?? '')?.id;
    final id = 'post_task_${_generateBlockId()}';
    final task = PostProductionTask(
      id: id,
      title: 'Новая задача',
      sceneId: validSceneId,
    );

    _finishTypingGroup();
    _pushUndoSnapshot();
    _document.postProductionTasks.add(task);
    _markDocumentChanged();
    return id;
  }

  bool updatePostProductionTask(PostProductionTask task) {
    final index = _document.postProductionTasks.indexWhere(
      (item) => item.id == task.id,
    );

    if (index == -1) {
      return false;
    }

    final validSceneId = _document.sceneById(task.sceneId ?? '')?.id;
    final validVersionId = _document.editVersionById(task.versionId ?? '')?.id;
    final progress = task.status == PostTaskStatus.done
        ? 100
        : task.progress.clamp(0, 100).toInt();
    final normalized = PostProductionTask(
      id: task.id,
      title: task.title.trim().isEmpty
          ? 'Задача постпродакшна'
          : task.title.trim(),
      department: task.department,
      status: task.status,
      priority: task.priority,
      assignee: task.assignee.trim(),
      dueDate: task.dueDate.trim(),
      progress: progress,
      sceneId: validSceneId,
      versionId: validVersionId,
      notes: task.notes.trim(),
    );
    final current = _document.postProductionTasks[index];

    if (_samePostProductionTask(current, normalized)) {
      return false;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();
    _document.postProductionTasks[index] = normalized;
    _markDocumentChanged();
    return true;
  }

  bool deletePostProductionTask(String taskId) {
    final index = _document.postProductionTasks.indexWhere(
      (item) => item.id == taskId,
    );

    if (index == -1) {
      return false;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();
    _document.postProductionTasks.removeAt(index);
    _markDocumentChanged();
    return true;
  }

  String createMissingMaterial({String? sceneId, String? shotId}) {
    final validSceneId = _document.sceneById(sceneId ?? '')?.id;
    final validShotId =
        _allStoryboardShotIds().contains(shotId) ? shotId : null;
    final id = 'missing_${_generateBlockId()}';
    final item = MissingMaterialItem(
      id: id,
      title: 'Отсутствующий материал',
      sceneId: validSceneId,
      shotId: validShotId,
    );

    _finishTypingGroup();
    _pushUndoSnapshot();
    _document.missingMaterials.add(item);
    _markDocumentChanged();
    return id;
  }

  bool updateMissingMaterial(MissingMaterialItem item) {
    final index = _document.missingMaterials.indexWhere(
      (value) => value.id == item.id,
    );

    if (index == -1) {
      return false;
    }

    final validSceneId = _document.sceneById(item.sceneId ?? '')?.id;
    final validShotId =
        _allStoryboardShotIds().contains(item.shotId) ? item.shotId : null;
    final normalized = MissingMaterialItem(
      id: item.id,
      title: item.title.trim().isEmpty
          ? 'Отсутствующий материал'
          : item.title.trim(),
      type: item.type,
      status: item.status,
      sceneId: validSceneId,
      shotId: validShotId,
      description: item.description.trim(),
      scheduledDate: item.scheduledDate.trim(),
      assignee: item.assignee.trim(),
    );
    final current = _document.missingMaterials[index];

    if (_sameMissingMaterial(current, normalized)) {
      return false;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();
    _document.missingMaterials[index] = normalized;
    _markDocumentChanged();
    return true;
  }

  bool deleteMissingMaterial(String itemId) {
    final index = _document.missingMaterials.indexWhere(
      (item) => item.id == itemId,
    );

    if (index == -1) {
      return false;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();
    _document.missingMaterials.removeAt(index);
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
    _document.shootingDayJournals.remove(dayId);
    final normalizedTakeMap = <String, List<ShotTake>>{
      for (final entry in _document.shotTakes.entries)
        entry.key: entry.value
            .map(
              (take) => take.shootingDayId == dayId
                  ? take.copyWith(clearShootingDayId: true)
                  : take,
            )
            .toList(growable: true),
    };
    _document.shotTakes
      ..clear()
      ..addAll(normalizedTakeMap);
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

  Set<String> _allStoryboardShotIds() {
    return _document.storyboardShots.values
        .expand((shots) => shots)
        .map((shot) => shot.id)
        .toSet();
  }

  String? _validShootingDayId(String? dayId) {
    if (dayId == null || _document.shootingDayById(dayId) == null) {
      return null;
    }

    return dayId;
  }

  ShotTake _normalizeShotTake(ShotTake take) {
    final normalizedPhotos = take.continuityPhotos
        .where(
          (photo) =>
              photo.id.trim().isNotEmpty && photo.base64Data.trim().isNotEmpty,
        )
        .map(
          (photo) => photo.copyWith(
            fileName: photo.fileName.trim(),
            mimeType: photo.mimeType.trim().isEmpty
                ? 'image/jpeg'
                : photo.mimeType.trim(),
            note: photo.note.trim(),
          ),
        )
        .toList(growable: false);

    return ShotTake(
      id: take.id,
      takeNumber: take.takeNumber <= 0 ? 1 : take.takeNumber,
      status: take.status,
      shootingDayId: _validShootingDayId(take.shootingDayId),
      timecode: take.timecode.trim(),
      durationSeconds: take.durationSeconds < 0 ? 0 : take.durationSeconds,
      mediaCard: take.mediaCard.trim(),
      camera: take.camera.trim(),
      fileName: take.fileName.trim(),
      rating: take.rating.clamp(0, 5).toInt(),
      directorNotes: take.directorNotes.trim(),
      cameraNotes: take.cameraNotes.trim(),
      soundNotes: take.soundNotes.trim(),
      rejectionReason: take.rejectionReason.trim(),
      costumeContinuity: take.costumeContinuity.trim(),
      makeupContinuity: take.makeupContinuity.trim(),
      propsContinuity: take.propsContinuity.trim(),
      actorPositions: take.actorPositions.trim(),
      continuityPhotos: normalizedPhotos,
    );
  }

  ShootingDayJournal _normalizeShootingDayJournal(
    ShootingDayJournal journal,
  ) {
    return ShootingDayJournal(
      actualCrewCall: journal.actualCrewCall.trim(),
      actualFirstShot: journal.actualFirstShot.trim(),
      actualWrap: journal.actualWrap.trim(),
      weather: journal.weather.trim(),
      summary: journal.summary.trim(),
      incidents: journal.incidents.trim(),
      mediaBackup: journal.mediaBackup.trim(),
      cameraReport: journal.cameraReport.trim(),
      soundReport: journal.soundReport.trim(),
      notes: journal.notes.trim(),
    );
  }

  bool _sameShotTake(ShotTake first, ShotTake second) {
    return first.id == second.id &&
        first.takeNumber == second.takeNumber &&
        first.status == second.status &&
        first.shootingDayId == second.shootingDayId &&
        first.timecode == second.timecode &&
        first.durationSeconds == second.durationSeconds &&
        first.mediaCard == second.mediaCard &&
        first.camera == second.camera &&
        first.fileName == second.fileName &&
        first.rating == second.rating &&
        first.directorNotes == second.directorNotes &&
        first.cameraNotes == second.cameraNotes &&
        first.soundNotes == second.soundNotes &&
        first.rejectionReason == second.rejectionReason &&
        first.costumeContinuity == second.costumeContinuity &&
        first.makeupContinuity == second.makeupContinuity &&
        first.propsContinuity == second.propsContinuity &&
        first.actorPositions == second.actorPositions &&
        _sameContinuityPhotos(
          first.continuityPhotos,
          second.continuityPhotos,
        );
  }

  bool _sameContinuityPhotos(
    List<ContinuityPhoto> first,
    List<ContinuityPhoto> second,
  ) {
    if (first.length != second.length) {
      return false;
    }

    for (var index = 0; index < first.length; index++) {
      final firstPhoto = first[index];
      final secondPhoto = second[index];

      if (firstPhoto.id != secondPhoto.id ||
          firstPhoto.fileName != secondPhoto.fileName ||
          firstPhoto.mimeType != secondPhoto.mimeType ||
          firstPhoto.base64Data != secondPhoto.base64Data ||
          firstPhoto.note != secondPhoto.note) {
        return false;
      }
    }

    return true;
  }

  bool _sameShootingDayJournal(
    ShootingDayJournal first,
    ShootingDayJournal second,
  ) {
    return first.actualCrewCall == second.actualCrewCall &&
        first.actualFirstShot == second.actualFirstShot &&
        first.actualWrap == second.actualWrap &&
        first.weather == second.weather &&
        first.summary == second.summary &&
        first.incidents == second.incidents &&
        first.mediaBackup == second.mediaBackup &&
        first.cameraReport == second.cameraReport &&
        first.soundReport == second.soundReport &&
        first.notes == second.notes;
  }

  Set<String> _takeIdsForScene(String sceneId) {
    final takeIds = <String>{};

    for (final shot in _document.storyboardShotsFor(sceneId)) {
      for (final take in _document.shotTakesFor(shot.id)) {
        takeIds.add(take.id);
      }
    }

    return takeIds;
  }

  bool _sameScenePostProduction(
    ScenePostProductionData first,
    ScenePostProductionData second,
  ) {
    return first.status == second.status &&
        first.progress == second.progress &&
        first.editorNotes == second.editorNotes &&
        first.directorNotes == second.directorNotes &&
        _sameStringLists(first.selectedTakeIds, second.selectedTakeIds) &&
        first.directorApproval == second.directorApproval &&
        first.producerApproval == second.producerApproval;
  }

  bool _samePostProductionSequence(
    PostProductionSequence first,
    PostProductionSequence second,
  ) {
    return first.id == second.id &&
        first.title == second.title &&
        _sameStringLists(first.sceneIds, second.sceneIds) &&
        first.notes == second.notes;
  }

  bool _sameEditVersion(EditVersion first, EditVersion second) {
    return first.id == second.id &&
        first.title == second.title &&
        first.sequenceId == second.sequenceId &&
        first.versionNumber == second.versionNumber &&
        first.application == second.application &&
        first.filePath == second.filePath &&
        first.createdAt == second.createdAt &&
        first.durationSeconds == second.durationSeconds &&
        first.notes == second.notes &&
        first.isCurrent == second.isCurrent;
  }

  bool _samePostProductionTask(
    PostProductionTask first,
    PostProductionTask second,
  ) {
    return first.id == second.id &&
        first.title == second.title &&
        first.department == second.department &&
        first.status == second.status &&
        first.priority == second.priority &&
        first.assignee == second.assignee &&
        first.dueDate == second.dueDate &&
        first.progress == second.progress &&
        first.sceneId == second.sceneId &&
        first.versionId == second.versionId &&
        first.notes == second.notes;
  }

  bool _sameMissingMaterial(
    MissingMaterialItem first,
    MissingMaterialItem second,
  ) {
    return first.id == second.id &&
        first.title == second.title &&
        first.type == second.type &&
        first.status == second.status &&
        first.sceneId == second.sceneId &&
        first.shotId == second.shotId &&
        first.description == second.description &&
        first.scheduledDate == second.scheduledDate &&
        first.assignee == second.assignee;
  }

  StoryboardShot _normalizeStoryboardShot(StoryboardShot shot) {
    return StoryboardShot(
      id: shot.id,
      title: shot.title.trim(),
      shotSize: shot.shotSize,
      cameraAngle: shot.cameraAngle,
      cameraMovement: shot.cameraMovement,
      lens: shot.lens.trim(),
      fps: shot.fps <= 0 ? 24 : shot.fps,
      durationSeconds: shot.durationSeconds < 0 ? 0 : shot.durationSeconds,
      equipment: normalizeStoryboardStrings(shot.equipment),
      visualDescription: shot.visualDescription.trim(),
      actionDescription: shot.actionDescription.trim(),
      dialogue: shot.dialogue.trim(),
      sound: shot.sound.trim(),
      notes: shot.notes.trim(),
      imageFileName: shot.imageFileName?.trim(),
      imageMimeType: shot.imageMimeType?.trim(),
      imageBase64: shot.imageBase64?.trim(),
    );
  }

  bool _sameStoryboardShot(StoryboardShot first, StoryboardShot second) {
    return first.id == second.id &&
        first.title == second.title &&
        first.shotSize == second.shotSize &&
        first.cameraAngle == second.cameraAngle &&
        first.cameraMovement == second.cameraMovement &&
        first.lens == second.lens &&
        first.fps == second.fps &&
        first.durationSeconds == second.durationSeconds &&
        _sameStringLists(first.equipment, second.equipment) &&
        first.visualDescription == second.visualDescription &&
        first.actionDescription == second.actionDescription &&
        first.dialogue == second.dialogue &&
        first.sound == second.sound &&
        first.notes == second.notes &&
        first.imageFileName == second.imageFileName &&
        first.imageMimeType == second.imageMimeType &&
        first.imageBase64 == second.imageBase64;
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

  CreativeMaterial upsertCreativeMaterial(CreativeMaterial material) {
    _finishTypingGroup();
    _pushUndoSnapshot();

    final now = DateTime.now().toUtc().toIso8601String();
    final index = _document.creativeMaterials.indexWhere(
      (item) => item.id == material.id,
    );
    final normalized = material.copyWith(
      title: material.title.trim().isEmpty
          ? material.type.label
          : material.title.trim(),
      body: material.body.trim(),
      source: material.source.trim(),
      url: material.url.trim(),
      folder:
          material.folder.trim().isEmpty ? 'Без папки' : material.folder.trim(),
      tags: material.tags
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList(growable: false),
      linkedSceneIds: material.linkedSceneIds
          .where((sceneId) => _document.sceneById(sceneId) != null)
          .toSet()
          .toList(growable: false),
      linkedCharacterNames: material.linkedCharacterNames
          .map((item) => item.trim().toUpperCase())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList(growable: false),
      createdAt: material.createdAt.trim().isEmpty ? now : material.createdAt,
      updatedAt: now,
    );

    if (index == -1) {
      _document.creativeMaterials.add(normalized);
      _appendChangeLog(
        'Добавлен материал в творческую базу',
        details: normalized.title,
      );
    } else {
      _document.creativeMaterials[index] = normalized;
      _appendChangeLog(
        'Обновлён материал творческой базы',
        details: normalized.title,
      );
    }

    _markDocumentChanged();
    return normalized;
  }

  CreativeMaterial? duplicateCreativeMaterial(String materialId) {
    final source = _document.creativeMaterialById(materialId);

    if (source == null) {
      return null;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();
    final now = DateTime.now().toUtc();
    final duplicate = source.copyWith(
      id: 'material_${now.microsecondsSinceEpoch}',
      title: '${source.title} — копия',
      usedBlockIds: const <String>[],
      createdAt: now.toIso8601String(),
      updatedAt: now.toIso8601String(),
    );
    _document.creativeMaterials.add(duplicate);
    _appendChangeLog(
      'Дублирован материал творческой базы',
      details: duplicate.title,
    );
    _markDocumentChanged();
    return duplicate;
  }

  bool deleteCreativeMaterial(String materialId) {
    final index = _document.creativeMaterials.indexWhere(
      (material) => material.id == materialId,
    );

    if (index == -1) {
      return false;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();
    final removed = _document.creativeMaterials.removeAt(index);
    _appendChangeLog(
      'Удалён материал из творческой базы',
      details: removed.title,
    );
    _markDocumentChanged();
    return true;
  }

  BlockInsertionResult? insertCreativeMaterialText({
    required String materialId,
    required String text,
    String? afterBlockId,
  }) {
    final materialIndex = _document.creativeMaterials.indexWhere(
      (material) => material.id == materialId,
    );
    final normalizedText = text.trim();

    if (materialIndex == -1 || normalizedText.isEmpty) {
      return null;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();

    final afterIndex = afterBlockId == null
        ? -1
        : _document.blocks.indexWhere((block) => block.id == afterBlockId);
    final insertionIndex =
        afterIndex == -1 ? _document.blocks.length : afterIndex + 1;
    final block = FilmBlock(
      id: _generateBlockId(),
      type: BlockType.action,
      text: normalizedText,
    );
    _document.blocks.insert(insertionIndex, block);

    final material = _document.creativeMaterials[materialIndex];
    _document.creativeMaterials[materialIndex] = material.copyWith(
      usedBlockIds: <String>{...material.usedBlockIds, block.id}.toList(
        growable: false,
      ),
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );
    _appendChangeLog(
      'Материал вставлен в сценарий',
      details: material.title,
    );
    _markDocumentChanged();

    return BlockInsertionResult(
      insertedBlockIds: <String>[block.id],
      focusBlockId: block.id,
    );
  }

  ProjectMember upsertProjectMember(ProjectMember member) {
    _finishTypingGroup();
    _pushUndoSnapshot();

    final index = _document.projectMembers.indexWhere(
      (item) => item.id == member.id,
    );
    final normalized = member.copyWith(
      name: member.name.trim().isEmpty ? 'Участник' : member.name.trim(),
      role: member.role.trim(),
      email: member.email.trim(),
      notes: member.notes.trim(),
    );

    if (index == -1) {
      _document.projectMembers.add(normalized);
      _appendChangeLog(
        'Добавлен участник команды',
        details: normalized.name,
      );
    } else {
      _document.projectMembers[index] = normalized;
      _appendChangeLog(
        'Обновлена карточка участника',
        details: normalized.name,
      );
    }

    _markDocumentChanged();
    return normalized;
  }

  bool deleteProjectMember(String memberId) {
    final index = _document.projectMembers.indexWhere(
      (member) => member.id == memberId,
    );

    if (index == -1) {
      return false;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();
    final removed = _document.projectMembers.removeAt(index);

    final normalizedComments = _document.collaborationComments.map((comment) {
      return comment.copyWith(
        clearAuthorId: comment.authorId == memberId,
        clearAssigneeId: comment.assigneeId == memberId,
      );
    }).toList(growable: false);
    _document.collaborationComments
      ..clear()
      ..addAll(normalizedComments);

    _appendChangeLog(
      'Удалён участник команды',
      details: removed.name,
    );
    _markDocumentChanged();
    return true;
  }

  CollaborationComment upsertCollaborationComment(
    CollaborationComment comment,
  ) {
    _finishTypingGroup();
    _pushUndoSnapshot();

    final index = _document.collaborationComments.indexWhere(
      (item) => item.id == comment.id,
    );
    final now = DateTime.now().toUtc().toIso8601String();
    final normalized = comment.copyWith(
      text: comment.text.trim(),
      createdAt: comment.createdAt.trim().isEmpty ? now : comment.createdAt,
      updatedAt: now,
    );

    if (index == -1) {
      _document.collaborationComments.add(normalized);
      _appendChangeLog(
        'Добавлен комментарий',
        details: normalized.text,
        actorId: normalized.authorId,
      );
    } else {
      _document.collaborationComments[index] = normalized;
      _appendChangeLog(
        'Обновлён комментарий',
        details: normalized.text,
        actorId: normalized.authorId,
      );
    }

    _markDocumentChanged();
    return normalized;
  }

  bool deleteCollaborationComment(String commentId) {
    final index = _document.collaborationComments.indexWhere(
      (comment) => comment.id == commentId,
    );

    if (index == -1) {
      return false;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();
    final removed = _document.collaborationComments.removeAt(index);
    _appendChangeLog(
      'Удалён комментарий',
      details: removed.text,
    );
    _markDocumentChanged();
    return true;
  }

  ProjectCheckpoint createProjectCheckpoint({
    required String name,
    String note = '',
    String? authorId,
  }) {
    _finishTypingGroup();
    _pushUndoSnapshot();

    final now = DateTime.now().toUtc();
    final checkpoint = ProjectCheckpoint(
      id: 'checkpoint_${now.microsecondsSinceEpoch}',
      name: name.trim().isEmpty ? 'Контрольная версия' : name.trim(),
      note: note.trim(),
      authorId: authorId,
      createdAt: now.toIso8601String(),
      snapshot: _document.toJson(includeCheckpoints: false),
    );
    _document.projectCheckpoints.add(checkpoint);
    _appendChangeLog(
      'Создана контрольная версия',
      details: checkpoint.name,
      actorId: authorId,
    );
    _markDocumentChanged();
    return checkpoint;
  }

  bool restoreProjectCheckpoint(String checkpointId) {
    final checkpoint = _document.projectCheckpointById(checkpointId);

    if (checkpoint == null || checkpoint.snapshot.isEmpty) {
      return false;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();
    final existingCheckpoints = List<ProjectCheckpoint>.of(
      _document.projectCheckpoints,
    );
    final restored = FilmDocument.fromJson(checkpoint.snapshot);
    restored.projectCheckpoints
      ..clear()
      ..addAll(existingCheckpoints);
    _document = restored;
    _appendChangeLog(
      'Восстановлена контрольная версия',
      details: checkpoint.name,
      actorId: checkpoint.authorId,
    );
    _markDocumentChanged();
    return true;
  }

  bool deleteProjectCheckpoint(String checkpointId) {
    final index = _document.projectCheckpoints.indexWhere(
      (checkpoint) => checkpoint.id == checkpointId,
    );

    if (index == -1) {
      return false;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();
    final removed = _document.projectCheckpoints.removeAt(index);
    _appendChangeLog(
      'Удалена контрольная версия',
      details: removed.name,
    );
    _markDocumentChanged();
    return true;
  }

  void updateVersioningSettings(ProjectVersioningSettings settings) {
    final normalized = settings.copyWith();

    if (_document.versioningSettings.autoBackupMinutes ==
            normalized.autoBackupMinutes &&
        _document.versioningSettings.maxAutomaticBackups ==
            normalized.maxAutomaticBackups &&
        _document.versioningSettings.teamPackageBaseFingerprint ==
            normalized.teamPackageBaseFingerprint) {
      return;
    }

    _finishTypingGroup();
    _pushUndoSnapshot();
    _document.versioningSettings = normalized;
    _appendChangeLog(
      'Изменены настройки резервных копий',
      details: 'Каждые ${normalized.autoBackupMinutes} мин., '
          'хранить ${normalized.maxAutomaticBackups}',
    );
    _markDocumentChanged();
  }

  void replaceWithVersionedDocument(
    FilmDocument document, {
    required String summary,
    bool preserveCurrentCheckpoints = true,
  }) {
    _finishTypingGroup();
    _pushUndoSnapshot();
    final checkpoints = preserveCurrentCheckpoints
        ? List<ProjectCheckpoint>.of(_document.projectCheckpoints)
        : const <ProjectCheckpoint>[];
    final replacement = _cloneDocument(document);

    if (preserveCurrentCheckpoints) {
      replacement.projectCheckpoints
        ..clear()
        ..addAll(checkpoints);
    }

    _document = replacement;
    _appendChangeLog(summary);
    _markDocumentChanged();
  }

  Future<String?> createAutomaticBackupNow() async {
    if (_isCreatingAutomaticBackup || _isDisposed) {
      return null;
    }

    _isCreatingAutomaticBackup = true;
    _notifySafely();

    try {
      final snapshot = _cloneDocument(_document);
      final result = await _versioningFileService.createAutomaticBackup(
        document: snapshot,
        projectName: _projectName,
        projectPath: _projectPath,
        maxBackups: snapshot.versioningSettings.maxAutomaticBackups,
      );
      _lastAutomaticBackupAt = DateTime.now();
      _lastAutomaticBackupRevision = _revision;
      return result;
    } catch (error) {
      _lastError = 'Ошибка резервного копирования: $error';
      return null;
    } finally {
      _isCreatingAutomaticBackup = false;
      _notifySafely();
    }
  }

  void recordVersioningChange({
    required String summary,
    String details = '',
    String? actorId,
  }) {
    _finishTypingGroup();
    _pushUndoSnapshot();
    _appendChangeLog(
      summary,
      details: details,
      actorId: actorId,
    );
    _markDocumentChanged();
  }

  void _appendChangeLog(
    String summary, {
    String details = '',
    String? actorId,
  }) {
    final timestamp = DateTime.now().toUtc();
    _document.projectChangeLog.add(
      ProjectChangeEntry(
        id: 'change_${timestamp.microsecondsSinceEpoch}_${_idCounter++}',
        summary: summary,
        details: details.trim(),
        actorId: actorId,
        createdAt: timestamp.toIso8601String(),
      ),
    );

    while (_document.projectChangeLog.length > 500) {
      _document.projectChangeLog.removeAt(0);
    }
  }

  void createNewProject() {
    _finishTypingGroup();
    _document = FilmDocument.empty();
    _projectPath = null;
    _projectName = 'Без названия';
    _storagePath = null;
    _lastProjectSavedAt = null;
    _lastAutomaticBackupAt = DateTime.now();
    _lastAutomaticBackupRevision = -1;
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
    _lastAutomaticBackupAt = DateTime.now();
    _lastAutomaticBackupRevision = -1;
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
      _lastAutomaticBackupAt = DateTime.now();
      _lastAutomaticBackupRevision = _revision;
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
      storyboardShots: source.storyboardShots,
      shotTakes: source.shotTakes,
      shootingDayJournals: source.shootingDayJournals,
      scenePostProduction: source.scenePostProduction,
      postProductionSequences: source.postProductionSequences,
      editVersions: source.editVersions,
      postProductionTasks: source.postProductionTasks,
      missingMaterials: source.missingMaterials,
      projectMembers: source.projectMembers,
      collaborationComments: source.collaborationComments,
      projectChangeLog: source.projectChangeLog,
      projectCheckpoints: source.projectCheckpoints,
      creativeMaterials: source.creativeMaterials,
      versioningSettings: source.versioningSettings,
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
    _document.scenePostProduction.removeWhere(
      (sceneId, _) => !validSceneIds.contains(sceneId),
    );
    _document.storyboardShots.removeWhere(
      (sceneId, _) => !validSceneIds.contains(sceneId),
    );

    final validShotIds = _allStoryboardShotIds();
    _document.shotTakes.removeWhere(
      (shotId, _) => !validShotIds.contains(shotId),
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
    _document.shootingDayJournals.removeWhere(
      (dayId, _) => !validDayIds.contains(dayId),
    );
    final normalizedTakeMap = <String, List<ShotTake>>{
      for (final entry in _document.shotTakes.entries)
        entry.key: entry.value
            .map(
              (take) => take.shootingDayId != null &&
                      !validDayIds.contains(take.shootingDayId)
                  ? take.copyWith(clearShootingDayId: true)
                  : take,
            )
            .toList(growable: true),
    };
    _document.shotTakes
      ..clear()
      ..addAll(normalizedTakeMap);

    for (final entry in _document.scenePostProduction.entries.toList()) {
      final validTakeIds = _takeIdsForScene(entry.key);
      final normalized = entry.value.copyWith(
        selectedTakeIds: entry.value.selectedTakeIds
            .where(validTakeIds.contains)
            .toList(growable: false),
      );

      if (normalized.isDefault) {
        _document.scenePostProduction.remove(entry.key);
      } else {
        _document.scenePostProduction[entry.key] = normalized;
      }
    }

    final normalizedSequences =
        _document.postProductionSequences.map((sequence) {
      return sequence.copyWith(
        sceneIds: sequence.sceneIds
            .where(validSceneIds.contains)
            .toSet()
            .toList(growable: false),
      );
    }).toList(growable: false);
    _document.postProductionSequences
      ..clear()
      ..addAll(normalizedSequences);

    final validSequenceIds = normalizedSequences.map((item) => item.id).toSet();
    final normalizedVersions = _document.editVersions.map((version) {
      return version.sequenceId != null &&
              !validSequenceIds.contains(version.sequenceId)
          ? version.copyWith(clearSequenceId: true)
          : version;
    }).toList(growable: false);
    _document.editVersions
      ..clear()
      ..addAll(normalizedVersions);

    final validVersionIds = normalizedVersions.map((item) => item.id).toSet();
    final normalizedPostTasks = _document.postProductionTasks.map((task) {
      return task.copyWith(
        clearSceneId:
            task.sceneId != null && !validSceneIds.contains(task.sceneId),
        clearVersionId:
            task.versionId != null && !validVersionIds.contains(task.versionId),
      );
    }).toList(growable: false);
    _document.postProductionTasks
      ..clear()
      ..addAll(normalizedPostTasks);

    final normalizedMissingMaterials = _document.missingMaterials.map((item) {
      return item.copyWith(
        clearSceneId:
            item.sceneId != null && !validSceneIds.contains(item.sceneId),
        clearShotId: item.shotId != null && !validShotIds.contains(item.shotId),
      );
    }).toList(growable: false);
    _document.missingMaterials
      ..clear()
      ..addAll(normalizedMissingMaterials);

    final validMemberIds =
        _document.projectMembers.map((member) => member.id).toSet();
    final validTakeIds = _document.shotTakes.values
        .expand((takes) => takes)
        .map((take) => take.id)
        .toSet();
    final validTaskIds =
        _document.postProductionTasks.map((task) => task.id).toSet();
    final normalizedComments = _document.collaborationComments.map((comment) {
      final hasValidTarget = switch (comment.targetType) {
        CollaborationTargetType.project => true,
        CollaborationTargetType.scene =>
          comment.targetId != null && validSceneIds.contains(comment.targetId),
        CollaborationTargetType.shot =>
          comment.targetId != null && validShotIds.contains(comment.targetId),
        CollaborationTargetType.take =>
          comment.targetId != null && validTakeIds.contains(comment.targetId),
        CollaborationTargetType.task =>
          comment.targetId != null && validTaskIds.contains(comment.targetId),
      };

      return comment.copyWith(
        clearTargetId: !hasValidTarget,
        targetType: hasValidTarget
            ? comment.targetType
            : CollaborationTargetType.project,
        clearAuthorId: comment.authorId != null &&
            !validMemberIds.contains(comment.authorId),
        clearAssigneeId: comment.assigneeId != null &&
            !validMemberIds.contains(comment.assigneeId),
      );
    }).toList(growable: false);
    _document.collaborationComments
      ..clear()
      ..addAll(normalizedComments);

    final validBlockIds = _document.blocks.map((block) => block.id).toSet();
    final normalizedCreativeMaterials = _document.creativeMaterials.map(
      (material) {
        return material.copyWith(
          linkedSceneIds: material.linkedSceneIds
              .where(validSceneIds.contains)
              .toSet()
              .toList(growable: false),
          usedBlockIds: material.usedBlockIds
              .where(validBlockIds.contains)
              .toSet()
              .toList(growable: false),
        );
      },
    ).toList(growable: false);
    _document.creativeMaterials
      ..clear()
      ..addAll(normalizedCreativeMaterials);

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

  void _startAutomaticBackupTimer() {
    _automaticBackupTimer?.cancel();
    _automaticBackupTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(_maybeCreateAutomaticBackup()),
    );
  }

  Future<void> _maybeCreateAutomaticBackup() async {
    if (_isDisposed ||
        !_isInitialized ||
        _isCreatingAutomaticBackup ||
        _revision == _lastAutomaticBackupRevision) {
      return;
    }

    final interval = Duration(
      minutes: _document.versioningSettings.autoBackupMinutes,
    );
    final lastBackup = _lastAutomaticBackupAt;

    if (lastBackup != null &&
        DateTime.now().difference(lastBackup) < interval) {
      return;
    }

    await createAutomaticBackupNow();
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
    _automaticBackupTimer?.cancel();
    super.dispose();
  }
}
