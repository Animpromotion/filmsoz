import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/editor/controller/screenplay_editor_controller.dart';
import 'package:filmsoz_studio/features/screenplay/editor/widgets/script_block_widget.dart';
import 'package:filmsoz_studio/features/screenplay/editor/widgets/script_page_sheet.dart';
import 'package:filmsoz_studio/features/screenplay/formatting/screenplay_editing_flow_service.dart';
import 'package:filmsoz_studio/features/screenplay/formatting/smart_formatting_service.dart';
import 'package:filmsoz_studio/features/screenplay/navigator/scene_navigator.dart';
import 'package:filmsoz_studio/features/screenplay/storage/fountain_file_service.dart';
import 'package:filmsoz_studio/features/screenplay/storage/project_file_service.dart';
import 'package:filmsoz_studio/features/screenplay/toolbar/editor_toolbar.dart';

class EditorMainScreen extends StatefulWidget {
  const EditorMainScreen({super.key});

  @override
  State<EditorMainScreen> createState() => _EditorMainScreenState();
}

class _EditorMainScreenState extends State<EditorMainScreen>
    with WidgetsBindingObserver {
  late final ScreenplayEditorController _controller;
  final ProjectFileService _projectFileService = const ProjectFileService();
  final FountainFileService _fountainFileService = const FountainFileService();
  final SmartFormattingService _smartFormattingService =
      const SmartFormattingService();
  final ScreenplayEditingFlowService _editingFlowService =
      const ScreenplayEditingFlowService();

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _scrollAreaKey = GlobalKey();

  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, GlobalKey> _blockKeys = {};

  bool _isSplittingBlock = false;
  bool _scrollUpdateScheduled = false;
  bool _initialFocusPlaced = false;
  bool _forceTextSync = false;
  String? _activeSceneId;
  List<String> _recentProjects = const <String>[];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _controller = ScreenplayEditorController();
    _controller.addListener(_onDocumentChanged);
    _scrollController.addListener(_scheduleActiveSceneUpdateFromScroll);

    _syncEditors();
    unawaited(_initializeEditor());
  }

  Future<void> _initializeEditor() async {
    await _controller.initialize();
    final recentProjects = await _projectFileService.loadRecentProjects();

    if (!mounted) {
      return;
    }

    setState(() {
      _recentProjects = recentProjects;
    });

    _syncEditors();
    _placeInitialFocus();
  }

  void _placeInitialFocus() {
    if (_initialFocusPlaced || _controller.document.blocks.isEmpty) {
      return;
    }

    _initialFocusPlaced = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _controller.document.blocks.isEmpty) {
        return;
      }

      final firstScene = _controller.document.scenes.firstOrNull;

      setState(() {
        _activeSceneId = firstScene?.id;
      });

      _focusBlock(
        _controller.document.blocks.first.id,
        cursorAtEnd: true,
      );
    });
  }

  void _onDocumentChanged() {
    _syncEditors();

    final sceneIds =
        _controller.document.scenes.map((scene) => scene.id).toSet();

    if (_activeSceneId != null && !sceneIds.contains(_activeSceneId)) {
      _activeSceneId = _controller.document.scenes.firstOrNull?.id;
    }

    if (_controller.isInitialized) {
      _placeInitialFocus();
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _syncEditors() {
    final activeIds =
        _controller.document.blocks.map((block) => block.id).toSet();

    final removedIds = _textControllers.keys
        .where((id) => !activeIds.contains(id))
        .toList(growable: false);

    for (final id in removedIds) {
      final removedController = _textControllers.remove(id);
      final removedFocusNode = _focusNodes.remove(id);
      _blockKeys.remove(id);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        removedController?.dispose();
        removedFocusNode?.dispose();
      });
    }

    for (final block in _controller.document.blocks) {
      final textController = _textControllers.putIfAbsent(
        block.id,
        () => TextEditingController(text: block.text),
      );

      _blockKeys.putIfAbsent(block.id, GlobalKey.new);

      _focusNodes.putIfAbsent(
        block.id,
        () {
          final focusNode = FocusNode(
            debugLabel: 'filmsoz-block-${block.id}',
            onKeyEvent: (_, event) => _handleBlockKey(block.id, event),
          );

          focusNode.addListener(() {
            if (focusNode.hasFocus) {
              _activateSceneForBlock(block.id);
            }
          });

          return focusNode;
        },
      );

      final hasFocus = _focusNodes[block.id]?.hasFocus ?? false;

      if ((_forceTextSync || !hasFocus) && textController.text != block.text) {
        textController.value = TextEditingValue(
          text: block.text,
          selection: TextSelection.collapsed(offset: block.text.length),
        );
      }
    }
  }

  KeyEventResult _handleBlockKey(
    String blockId,
    KeyEvent event,
  ) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final blockIndex = _controller.document.blocks.indexWhere(
      (block) => block.id == blockId,
    );

    if (blockIndex == -1) {
      return KeyEventResult.ignored;
    }

    final block = _controller.document.blocks[blockIndex];
    final key = event.logicalKey;
    final isControlPressed = HardwareKeyboard.instance.isControlPressed;
    final isAltPressed = HardwareKeyboard.instance.isAltPressed;

    if (isControlPressed && isAltPressed && key == LogicalKeyboardKey.keyO) {
      unawaited(_importFountain());
      return KeyEventResult.handled;
    }

    if (isControlPressed && isAltPressed && key == LogicalKeyboardKey.keyE) {
      unawaited(_exportFountain());
      return KeyEventResult.handled;
    }

    if (isControlPressed && key == LogicalKeyboardKey.keyZ) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        _redo();
      } else {
        _undo();
      }

      return KeyEventResult.handled;
    }

    if (isControlPressed && key == LogicalKeyboardKey.keyY) {
      _redo();
      return KeyEventResult.handled;
    }

    if (isControlPressed && key == LogicalKeyboardKey.keyN) {
      unawaited(_newProject());
      return KeyEventResult.handled;
    }

    if (isControlPressed && key == LogicalKeyboardKey.keyO) {
      unawaited(_openProject());
      return KeyEventResult.handled;
    }

    if (isControlPressed && key == LogicalKeyboardKey.keyS) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        unawaited(_saveProjectAs());
      } else {
        unawaited(_saveProject());
      }

      return KeyEventResult.handled;
    }

    if ((key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _splitBlockAtSelection(block);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.tab) {
      _changeBlockType(
        block,
        reverse: HardwareKeyboard.instance.isShiftPressed,
      );
      return KeyEventResult.handled;
    }

    final textController = _textControllers[block.id];
    final selection = textController?.selection;
    final cursorAtBeginning = textController != null &&
        selection != null &&
        selection.isValid &&
        selection.isCollapsed &&
        selection.start == 0;
    final cursorAtEnd = textController != null &&
        selection != null &&
        selection.isValid &&
        selection.isCollapsed &&
        selection.end == textController.text.length;

    if (!isControlPressed &&
        !isAltPressed &&
        key == LogicalKeyboardKey.backspace &&
        cursorAtBeginning &&
        blockIndex > 0) {
      _mergeWithPrevious(block);
      return KeyEventResult.handled;
    }

    if (!isControlPressed &&
        !isAltPressed &&
        key == LogicalKeyboardKey.delete &&
        cursorAtEnd &&
        blockIndex < _controller.document.blocks.length - 1) {
      _mergeWithNext(block);
      return KeyEventResult.handled;
    }

    final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

    if (!isControlPressed &&
        !isAltPressed &&
        !isShiftPressed &&
        cursorAtBeginning &&
        blockIndex > 0 &&
        (key == LogicalKeyboardKey.arrowLeft ||
            key == LogicalKeyboardKey.arrowUp)) {
      _moveFocusToAdjacentBlock(
        targetIndex: blockIndex - 1,
        cursorAtEnd: true,
      );
      return KeyEventResult.handled;
    }

    if (!isControlPressed &&
        !isAltPressed &&
        !isShiftPressed &&
        cursorAtEnd &&
        blockIndex < _controller.document.blocks.length - 1 &&
        (key == LogicalKeyboardKey.arrowRight ||
            key == LogicalKeyboardKey.arrowDown)) {
      _moveFocusToAdjacentBlock(
        targetIndex: blockIndex + 1,
        cursorAtEnd: false,
      );
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _handleTextChanged(String blockId, String text) {
    if (_isSplittingBlock) {
      return;
    }

    final newLineIndex = text.indexOf('\n');

    if (newLineIndex == -1) {
      _updateBlockWithSmartFormatting(blockId, text);
      return;
    }

    // Shift + Enter leaves a line break inside the current block.
    if (HardwareKeyboard.instance.isShiftPressed) {
      _updateBlockWithSmartFormatting(blockId, text);
      return;
    }

    final blockIndex = _controller.document.blocks.indexWhere(
      (block) => block.id == blockId,
    );

    if (blockIndex == -1) {
      return;
    }

    final block = _controller.document.blocks[blockIndex];

    _splitBlockWithText(
      block: block,
      textBeforeCursor: text.substring(0, newLineIndex),
      textAfterCursor: text.substring(newLineIndex + 1),
    );
  }

  void _updateBlockWithSmartFormatting(
    String blockId,
    String text,
  ) {
    final blockIndex = _controller.document.blocks.indexWhere(
      (block) => block.id == blockId,
    );

    if (blockIndex == -1) {
      return;
    }

    final block = _controller.document.blocks[blockIndex];
    final previousType = blockIndex > 0
        ? _controller.document.blocks[blockIndex - 1].type
        : null;

    final inferredType = _smartFormattingService.detectLiveType(
      text: text,
      currentType: block.type,
      previousType: previousType,
    );

    _controller.updateBlockContent(
      blockId,
      text: text,
      inferredType: inferredType,
    );
  }

  void _splitBlockAtSelection(FilmBlock block) {
    final textController = _textControllers[block.id];

    if (textController == null) {
      return;
    }

    final value = textController.value;
    final text = value.text;
    final selection = value.selection;

    var start = text.length;
    var end = text.length;

    if (selection.isValid) {
      start = math
          .min(selection.start, selection.end)
          .clamp(0, text.length)
          .toInt();
      end = math
          .max(selection.start, selection.end)
          .clamp(0, text.length)
          .toInt();
    }

    _splitBlockWithText(
      block: block,
      textBeforeCursor: text.substring(0, start),
      textAfterCursor: text.substring(end),
    );
  }

  void _splitBlockWithText({
    required FilmBlock block,
    required String textBeforeCursor,
    required String textAfterCursor,
  }) {
    if (_isSplittingBlock) {
      return;
    }

    _isSplittingBlock = true;

    final textController = _textControllers[block.id];

    if (textController == null) {
      _isSplittingBlock = false;
      return;
    }

    final blockIndex = _controller.document.blocks.indexWhere(
      (item) => item.id == block.id,
    );
    final previousType = blockIndex > 0
        ? _controller.document.blocks[blockIndex - 1].type
        : null;

    final formatted = _smartFormattingService.finalizeBlock(
      text: textBeforeCursor,
      currentType: block.type,
      previousType: previousType,
    );

    final enterPlan = _editingFlowService.planEnter(
      currentType: formatted.type,
      textBeforeCursor: formatted.text,
      textAfterCursor: textAfterCursor,
    );

    textController.value = TextEditingValue(
      text: formatted.text,
      selection: TextSelection.collapsed(offset: formatted.text.length),
    );

    if (!enterPlan.shouldSplit) {
      _controller.updateBlockContent(
        block.id,
        text: formatted.text,
        inferredType: enterPlan.currentType,
      );
      _syncEditors();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _isSplittingBlock = false;

        if (!mounted) {
          return;
        }

        _focusBlock(block.id, cursorAtEnd: true);
      });
      return;
    }

    final newBlock = _controller.splitBlock(
      id: block.id,
      textBeforeCursor: formatted.text,
      textAfterCursor: textAfterCursor,
      currentType: enterPlan.currentType,
      nextType: enterPlan.nextType,
    );

    _syncEditors();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isSplittingBlock = false;

      if (!mounted) {
        return;
      }

      _focusBlock(newBlock.id, cursorAtEnd: false);
    });
  }

  void _changeBlockType(
    FilmBlock block, {
    required bool reverse,
  }) {
    final nextType = _editingFlowService.cycleType(
      block.type,
      reverse: reverse,
    );
    final selection = _textControllers[block.id]?.selection;

    _controller.setBlockType(block.id, nextType);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final textController = _textControllers[block.id];
      _focusNodes[block.id]?.requestFocus();

      if (textController != null && selection != null && selection.isValid) {
        final baseOffset =
            selection.baseOffset.clamp(0, textController.text.length).toInt();
        final extentOffset =
            selection.extentOffset.clamp(0, textController.text.length).toInt();

        textController.selection = TextSelection(
          baseOffset: baseOffset,
          extentOffset: extentOffset,
        );
      }
    });
  }

  void _mergeWithPrevious(FilmBlock block) {
    final result = _controller.mergeBlockWithPrevious(block.id);

    if (result == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _focusBlockAtOffset(
        result.blockId,
        result.cursorOffset,
      );
    });
  }

  void _mergeWithNext(FilmBlock block) {
    final result = _controller.mergeBlockWithNext(block.id);

    if (result == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _focusBlockAtOffset(
        result.blockId,
        result.cursorOffset,
      );
    });
  }

  void _moveFocusToAdjacentBlock({
    required int targetIndex,
    required bool cursorAtEnd,
  }) {
    final blocks = _controller.document.blocks;

    if (targetIndex < 0 || targetIndex >= blocks.length) {
      return;
    }

    final targetBlock = blocks[targetIndex];
    final targetController = _textControllers[targetBlock.id];

    if (targetController == null) {
      return;
    }

    final cursorOffset = cursorAtEnd ? targetController.text.length : 0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _focusBlockAtOffset(targetBlock.id, cursorOffset);
    });
  }

  Future<void> _newProject() async {
    final canContinue = await _confirmDiscardChanges(
      actionName: 'созданием нового сценария',
    );

    if (!canContinue || !mounted) {
      return;
    }

    _prepareDocumentReplacement();
    _controller.createNewProject();
    _finishDocumentReplacement();
  }

  Future<void> _openProject() async {
    final canContinue = await _confirmDiscardChanges(
      actionName: 'открытием другого проекта',
    );

    if (!canContinue || !mounted) {
      return;
    }

    final selectedPath = await _projectFileService.chooseOpenProject();

    if (selectedPath == null || !mounted) {
      return;
    }

    await _openProjectPath(selectedPath);
  }

  Future<void> _openRecentProject(String projectPath) async {
    final canContinue = await _confirmDiscardChanges(
      actionName: 'открытием другого проекта',
    );

    if (!canContinue || !mounted) {
      return;
    }

    await _openProjectPath(projectPath);
  }

  Future<void> _openProjectPath(String projectPath) async {
    _prepareDocumentReplacement();

    final opened = await _controller.openProjectFromPath(projectPath);

    if (!mounted) {
      return;
    }

    _finishDocumentReplacement();

    if (opened) {
      await _rememberProject(projectPath);
    } else {
      await _showProjectError(
        fallbackMessage: 'Не удалось открыть проект.',
      );
    }
  }

  Future<bool> _saveProject() async {
    if (!_controller.hasProjectPath) {
      return _saveProjectAs();
    }

    final saved = await _controller.saveCurrentProject();

    if (!mounted) {
      return saved;
    }

    if (saved) {
      final projectPath = _controller.projectPath;

      if (projectPath != null) {
        await _rememberProject(projectPath);
      }
    } else {
      await _showProjectError(
        fallbackMessage: 'Не удалось сохранить проект.',
      );
    }

    return saved;
  }

  Future<bool> _saveProjectAs() async {
    final selectedPath = await _projectFileService.chooseSaveProject(
      suggestedName: _controller.projectName,
    );

    if (selectedPath == null || !mounted) {
      return false;
    }

    final saved = await _controller.saveProjectToPath(selectedPath);

    if (!mounted) {
      return saved;
    }

    if (saved) {
      final projectPath = _controller.projectPath;

      if (projectPath != null) {
        await _rememberProject(projectPath);
      }
    } else {
      await _showProjectError(
        fallbackMessage: 'Не удалось сохранить проект.',
      );
    }

    return saved;
  }

  Future<void> _importFountain() async {
    final canContinue = await _confirmDiscardChanges(
      actionName: 'импортом сценария Fountain',
    );

    if (!canContinue || !mounted) {
      return;
    }

    final selectedPath = await _fountainFileService.chooseImportFile();

    if (selectedPath == null || !mounted) {
      return;
    }

    try {
      final result = await _fountainFileService.importFromPath(selectedPath);

      if (!mounted) {
        return;
      }

      _prepareDocumentReplacement();
      _controller.replaceWithImportedDocument(
        result.document,
        sourceName: result.suggestedProjectName,
      );
      _finishDocumentReplacement();

      _showOperationMessage(
        'Fountain импортирован: ${result.suggestedProjectName}',
      );
    } catch (error) {
      await _showOperationError(
        title: 'Ошибка импорта Fountain',
        message: 'Не удалось импортировать файл:\n$error',
      );
    }
  }

  Future<void> _exportFountain() async {
    final selectedPath = await _fountainFileService.chooseExportFile(
      suggestedName: _controller.projectName,
    );

    if (selectedPath == null || !mounted) {
      return;
    }

    try {
      final exportedPath = await _fountainFileService.exportToPath(
        _controller.document,
        selectedPath,
      );

      if (!mounted) {
        return;
      }

      _showOperationMessage('Fountain экспортирован: $exportedPath');
    } catch (error) {
      await _showOperationError(
        title: 'Ошибка экспорта Fountain',
        message: 'Не удалось экспортировать сценарий:\n$error',
      );
    }
  }

  Future<bool> _confirmDiscardChanges({
    required String actionName,
  }) async {
    if (!_controller.isDirty) {
      return true;
    }

    final choice = await showDialog<_UnsavedChangesChoice>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Есть несохранённые изменения'),
          content: Text(
            'Перед $actionName сохранить текущий сценарий в файл проекта?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(_UnsavedChangesChoice.cancel);
              },
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(_UnsavedChangesChoice.discard);
              },
              child: const Text('Не сохранять'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(_UnsavedChangesChoice.save);
              },
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );

    switch (choice) {
      case _UnsavedChangesChoice.save:
        return _saveProject();
      case _UnsavedChangesChoice.discard:
        return true;
      case _UnsavedChangesChoice.cancel:
      case null:
        return false;
    }
  }

  Future<void> _rememberProject(String projectPath) async {
    final recentProjects = await _projectFileService.rememberProject(
      projectPath,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _recentProjects = recentProjects;
    });
  }

  Future<void> _showProjectError({
    required String fallbackMessage,
  }) async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Filmsoz Studio'),
          content: Text(_controller.lastError ?? fallbackMessage),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Понятно'),
            ),
          ],
        );
      },
    );
  }

  void _showOperationMessage(String message) {
    if (!mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
        ),
      );
  }

  Future<void> _showOperationError({
    required String title,
    required String message,
  }) async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: SelectableText(message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Понятно'),
            ),
          ],
        );
      },
    );
  }

  void _prepareDocumentReplacement() {
    FocusManager.instance.primaryFocus?.unfocus();
    _initialFocusPlaced = false;
    _activeSceneId = null;
    _forceTextSync = true;
  }

  void _finishDocumentReplacement() {
    _forceTextSync = false;
    _syncEditors();
    _placeInitialFocus();

    if (mounted) {
      setState(() {});
    }
  }

  void _undo() {
    _performHistoryAction(_controller.undo);
  }

  void _redo() {
    _performHistoryAction(_controller.redo);
  }

  void _performHistoryAction(bool Function() action) {
    final focusedBlockId = _focusedBlockId();
    final previousBlocks = _controller.document.blocks;
    final previousIndex = focusedBlockId == null
        ? -1
        : previousBlocks.indexWhere((block) => block.id == focusedBlockId);
    final previousSelection = focusedBlockId == null
        ? null
        : _textControllers[focusedBlockId]?.selection;

    _forceTextSync = true;
    final changed = action();
    _forceTextSync = false;

    if (!changed) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _controller.document.blocks.isEmpty) {
        return;
      }

      final blocks = _controller.document.blocks;
      final existingIndex = focusedBlockId == null
          ? -1
          : blocks.indexWhere((block) => block.id == focusedBlockId);
      final String targetId;

      if (existingIndex >= 0) {
        targetId = blocks[existingIndex].id;
      } else {
        final safeIndex = previousIndex < 0
            ? 0
            : previousIndex.clamp(0, blocks.length - 1).toInt();
        targetId = blocks[safeIndex].id;
      }

      final textController = _textControllers[targetId];
      final focusNode = _focusNodes[targetId];

      if (textController == null || focusNode == null) {
        return;
      }

      focusNode.requestFocus();

      var cursorOffset = textController.text.length;

      if (previousSelection != null && previousSelection.isValid) {
        cursorOffset = previousSelection.extentOffset
            .clamp(0, textController.text.length)
            .toInt();
      }

      textController.selection = TextSelection.collapsed(
        offset: cursorOffset,
      );
      _activateSceneForBlock(targetId);
    });
  }

  String? _focusedBlockId() {
    for (final entry in _focusNodes.entries) {
      if (entry.value.hasFocus) {
        return entry.key;
      }
    }

    return null;
  }

  void _focusBlock(
    String blockId, {
    required bool cursorAtEnd,
  }) {
    final textController = _textControllers[blockId];

    if (textController == null) {
      return;
    }

    _focusBlockAtOffset(
      blockId,
      cursorAtEnd ? textController.text.length : 0,
      reveal: false,
    );
  }

  void _focusBlockAtOffset(
    String blockId,
    int cursorOffset, {
    bool reveal = true,
  }) {
    final focusNode = _focusNodes[blockId];
    final textController = _textControllers[blockId];

    if (focusNode == null || textController == null) {
      return;
    }

    final safeOffset =
        cursorOffset.clamp(0, textController.text.length).toInt();

    focusNode.requestFocus();
    textController.selection = TextSelection.collapsed(offset: safeOffset);
    _activateSceneForBlock(blockId);

    if (!reveal) {
      return;
    }

    final blockContext = _blockKeys[blockId]?.currentContext;

    if (blockContext != null) {
      unawaited(
        Scrollable.ensureVisible(
          blockContext,
          alignment: 0.18,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  void _activateSceneForBlock(String blockId) {
    final scene = _findSceneForBlock(blockId);

    if (scene == null || scene.id == _activeSceneId || !mounted) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || scene.id == _activeSceneId) {
        return;
      }

      setState(() {
        _activeSceneId = scene.id;
      });
    });
  }

  FilmBlock? _findSceneForBlock(String blockId) {
    final blocks = _controller.document.blocks;
    final blockIndex = blocks.indexWhere((block) => block.id == blockId);

    if (blockIndex == -1) {
      return null;
    }

    for (var index = blockIndex; index >= 0; index--) {
      final block = blocks[index];

      if (block.type == BlockType.sceneHeading) {
        return block;
      }
    }

    return _controller.document.scenes.firstOrNull;
  }

  Future<void> _selectScene(FilmBlock scene) async {
    if (mounted && _activeSceneId != scene.id) {
      setState(() {
        _activeSceneId = scene.id;
      });
    }

    final blockContext = _blockKeys[scene.id]?.currentContext;

    if (blockContext == null) {
      return;
    }

    await Scrollable.ensureVisible(
      blockContext,
      alignment: 0.08,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );

    if (!mounted) {
      return;
    }

    _focusBlock(scene.id, cursorAtEnd: true);
  }

  void _scheduleActiveSceneUpdateFromScroll() {
    if (_scrollUpdateScheduled) {
      return;
    }

    _scrollUpdateScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollUpdateScheduled = false;

      if (mounted) {
        _updateActiveSceneFromScroll();
      }
    });
  }

  void _updateActiveSceneFromScroll() {
    final scrollAreaContext = _scrollAreaKey.currentContext;

    if (scrollAreaContext == null) {
      return;
    }

    final scrollAreaBox = scrollAreaContext.findRenderObject();

    if (scrollAreaBox is! RenderBox || !scrollAreaBox.hasSize) {
      return;
    }

    final viewportTop = scrollAreaBox.localToGlobal(Offset.zero).dy + 72;
    final scenes = _controller.document.scenes;

    if (scenes.isEmpty) {
      return;
    }

    FilmBlock candidate = scenes.first;

    for (final scene in scenes) {
      final sceneContext = _blockKeys[scene.id]?.currentContext;
      final sceneBox = sceneContext?.findRenderObject();

      if (sceneBox is! RenderBox || !sceneBox.hasSize) {
        continue;
      }

      final sceneTop = sceneBox.localToGlobal(Offset.zero).dy;

      if (sceneTop <= viewportTop) {
        candidate = scene;
      } else {
        break;
      }
    }

    if (candidate.id != _activeSceneId && mounted) {
      setState(() {
        _activeSceneId = candidate.id;
      });
    }
  }

  FilmBlock? _findBlockById(String? blockId) {
    if (blockId == null) {
      return null;
    }

    for (final block in _controller.document.blocks) {
      if (block.id == blockId) {
        return block;
      }
    }

    return null;
  }

  String _saveStatusText() {
    if (_controller.isLoading) {
      return 'Загрузка сценария...';
    }

    if (_controller.isSaving) {
      return 'Сохранение...';
    }

    if (_controller.lastError != null) {
      return _controller.lastError!;
    }

    if (_controller.isDirty) {
      return _controller.hasProjectPath
          ? 'Изменения автосохранены • файл проекта не обновлён'
          : 'Автосохранено • проект ещё не сохранён';
    }

    final lastProjectSavedAt = _controller.lastProjectSavedAt;

    if (lastProjectSavedAt != null) {
      final hours = lastProjectSavedAt.hour.toString().padLeft(2, '0');
      final minutes = lastProjectSavedAt.minute.toString().padLeft(2, '0');
      final seconds = lastProjectSavedAt.second.toString().padLeft(2, '0');

      return 'Проект сохранён в $hours:$minutes:$seconds';
    }

    final lastSavedAt = _controller.lastSavedAt;

    if (lastSavedAt == null) {
      return 'Автосохранение готово';
    }

    final hours = lastSavedAt.hour.toString().padLeft(2, '0');
    final minutes = lastSavedAt.minute.toString().padLeft(2, '0');
    final seconds = lastSavedAt.second.toString().padLeft(2, '0');

    return 'Автосохранено в $hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final scenes = _controller.document.scenes;
    final activeScene = _findBlockById(_activeSceneId);

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(
          LogicalKeyboardKey.keyO,
          control: true,
          alt: true,
        ): () => unawaited(_importFountain()),
        const SingleActivator(
          LogicalKeyboardKey.keyE,
          control: true,
          alt: true,
        ): () => unawaited(_exportFountain()),
        const SingleActivator(
          LogicalKeyboardKey.keyN,
          control: true,
        ): () => unawaited(_newProject()),
        const SingleActivator(
          LogicalKeyboardKey.keyO,
          control: true,
        ): () => unawaited(_openProject()),
        const SingleActivator(
          LogicalKeyboardKey.keyS,
          control: true,
          shift: true,
        ): () => unawaited(_saveProjectAs()),
        const SingleActivator(
          LogicalKeyboardKey.keyS,
          control: true,
        ): () => unawaited(_saveProject()),
        const SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: true,
        ): _undo,
        const SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: true,
          shift: true,
        ): _redo,
        const SingleActivator(
          LogicalKeyboardKey.keyY,
          control: true,
        ): _redo,
      },
      child: Stack(
        children: [
          Scaffold(
            body: Column(
              children: [
                EditorToolbar(
                  projectName: _controller.projectName,
                  isDirty: _controller.isDirty,
                  recentProjects: _recentProjects,
                  onNewProject: () => unawaited(_newProject()),
                  onOpenProject: () => unawaited(_openProject()),
                  onOpenRecentProject: (projectPath) {
                    unawaited(_openRecentProject(projectPath));
                  },
                  onSave: () => unawaited(_saveProject()),
                  onSaveAs: () => unawaited(_saveProjectAs()),
                  onImportFountain: () => unawaited(_importFountain()),
                  onExportFountain: () => unawaited(_exportFountain()),
                  onUndo: _undo,
                  onRedo: _redo,
                  isSaving: _controller.isSaving,
                  canUndo: _controller.canUndo,
                  canRedo: _controller.canRedo,
                ),
                Expanded(
                  child: Row(
                    children: [
                      SceneNavigator(
                        scenes: scenes,
                        selectedSceneId: _activeSceneId,
                        onSceneSelected: _selectScene,
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: ColoredBox(
                          key: _scrollAreaKey,
                          color: const Color(0xFF1E1E1E),
                          child: Scrollbar(
                            controller: _scrollController,
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Center(
                                child: ScriptPageSheet(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      for (final block
                                          in _controller.document.blocks)
                                        KeyedSubtree(
                                          key: _blockKeys[block.id],
                                          child: ScriptBlockWidget(
                                            block: block,
                                            textController:
                                                _textControllers[block.id]!,
                                            focusNode: _focusNodes[block.id]!,
                                            onChanged: (text) =>
                                                _handleTextChanged(
                                              block.id,
                                              text,
                                            ),
                                            nextBlockHint: _editingFlowService
                                                .nextBlockHint(block.type),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 28,
                  color: const Color(0xFF252526),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Сцен: ${scenes.length}  •  '
                          'Блоков: ${_controller.document.blocks.length}  •  '
                          'Активная: ${activeScene?.text.trim().isNotEmpty == true ? activeScene!.text : 'БЕЗ НАЗВАНИЯ'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFAAAAAA),
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Tooltip(
                        message: _controller.storagePath ??
                            'Путь будет определён после запуска',
                        child: Text(
                          '${_saveStatusText()}  •  Ctrl+S  •  Ctrl+N / Ctrl+O  •  Ctrl+Z / Ctrl+Y',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _controller.lastError == null
                                ? const Color(0xFF9FD39F)
                                : const Color(0xFFFF9A9A),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_controller.isLoading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x99000000),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 14),
                      Text(
                        'Загрузка последнего сценария...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(_controller.saveDocument(force: true));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _controller
      ..removeListener(_onDocumentChanged)
      ..dispose();

    _scrollController
      ..removeListener(_scheduleActiveSceneUpdateFromScroll)
      ..dispose();

    for (final controller in _textControllers.values) {
      controller.dispose();
    }

    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }

    super.dispose();
  }
}

enum _UnsavedChangesChoice { save, discard, cancel }

extension _FirstOrNullExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
