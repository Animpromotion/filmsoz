import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/scene_section.dart';
import 'package:filmsoz_studio/features/screenplay/editor/controller/screenplay_editor_controller.dart';
import 'package:filmsoz_studio/features/screenplay/editor/widgets/script_block_widget.dart';
import 'package:filmsoz_studio/features/screenplay/editor/widgets/script_page_sheet.dart';
import 'package:filmsoz_studio/features/screenplay/formatting/screenplay_editing_flow_service.dart';
import 'package:filmsoz_studio/features/screenplay/formatting/smart_formatting_service.dart';
import 'package:filmsoz_studio/features/screenplay/navigator/scene_navigator.dart';
import 'package:filmsoz_studio/features/screenplay/productivity/screenplay_productivity_service.dart';
import 'package:filmsoz_studio/features/screenplay/productivity/screenplay_productivity_toolbar.dart';
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
  final ScreenplayProductivityService _productivityService =
      const ScreenplayProductivityService();

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _scrollAreaKey = GlobalKey();

  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, GlobalKey> _blockKeys = {};
  final Set<String> _selectedBlockIds = <String>{};
  final Set<String> _collapsedSceneIds = <String>{};

  List<FilmBlock> _blockClipboard = const <FilmBlock>[];
  String? _draggingBlockId;
  String? _dragHoverTargetId;
  bool _dragInsertAfter = false;
  Timer? _dragAutoScrollTimer;
  Offset? _lastDragGlobalPosition;
  String? _selectionAnchorId;
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

    final activeBlockIds =
        _controller.document.blocks.map((block) => block.id).toSet();
    _selectedBlockIds.removeWhere(
      (blockId) => !activeBlockIds.contains(blockId),
    );

    if (_selectionAnchorId != null &&
        !activeBlockIds.contains(_selectionAnchorId)) {
      _selectionAnchorId = null;
    }

    final sceneIds =
        _controller.document.sceneSections.map((scene) => scene.id).toSet();
    _collapsedSceneIds.removeWhere(
      (sceneId) => !sceneIds.contains(sceneId),
    );

    if (_activeSceneId != null && !sceneIds.contains(_activeSceneId)) {
      _activeSceneId = _controller.document.sceneSections.firstOrNull?.id;
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

  List<String> _suggestionsForBlock(FilmBlock block) {
    final focusNode = _focusNodes[block.id];

    if (focusNode?.hasFocus != true) {
      return const <String>[];
    }

    final currentText = _textControllers[block.id]?.text ?? block.text;

    switch (block.type) {
      case BlockType.character:
        return _productivityService.characterSuggestions(
          _controller.document,
          query: currentText,
          excludeBlockId: block.id,
        );
      case BlockType.sceneHeading:
        return _productivityService.locationSuggestions(
          _controller.document,
          query: _productivityService.locationQuery(currentText),
          excludeBlockId: block.id,
        );
      case BlockType.action:
      case BlockType.dialogue:
      case BlockType.parenthetical:
      case BlockType.transition:
        return const <String>[];
    }
  }

  void _applySuggestion(FilmBlock block, String suggestion) {
    final textController = _textControllers[block.id];

    if (textController == null) {
      return;
    }

    final nextText = switch (block.type) {
      BlockType.character =>
        _productivityService.normalizeCharacterName(suggestion),
      BlockType.sceneHeading => _productivityService.applyLocationSuggestion(
          textController.text,
          suggestion,
        ),
      BlockType.action => textController.text,
      BlockType.dialogue => textController.text,
      BlockType.parenthetical => textController.text,
      BlockType.transition => textController.text,
    };

    if (nextText == textController.text) {
      return;
    }

    textController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
    _controller.updateBlockContent(
      block.id,
      text: nextText,
      inferredType: block.type,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusBlockAtOffset(block.id, nextText.length);
      }
    });
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
    final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
    final hasBlockSelection = _selectedBlockIds.isNotEmpty;

    if (isControlPressed && !isAltPressed && key == LogicalKeyboardKey.space) {
      final suggestions = _suggestionsForBlock(block);

      if (suggestions.isNotEmpty) {
        _applySuggestion(block, suggestions.first);
        return KeyEventResult.handled;
      }
    }

    if (isControlPressed &&
        !isAltPressed &&
        !isShiftPressed &&
        key == LogicalKeyboardKey.keyD) {
      _duplicateFocusedOrSelectedBlocks(activeBlockId: block.id);
      return KeyEventResult.handled;
    }

    if (isControlPressed &&
        !isAltPressed &&
        !isShiftPressed &&
        key == LogicalKeyboardKey.keyF) {
      unawaited(_showFindReplaceDialog());
      return KeyEventResult.handled;
    }

    if (isControlPressed &&
        !isAltPressed &&
        !isShiftPressed &&
        key == LogicalKeyboardKey.keyG) {
      unawaited(_showGoToSceneDialog());
      return KeyEventResult.handled;
    }

    if (isControlPressed &&
        !isAltPressed &&
        isShiftPressed &&
        key == LogicalKeyboardKey.keyM) {
      unawaited(_editSceneNote());
      return KeyEventResult.handled;
    }

    if (isControlPressed &&
        isAltPressed &&
        !isShiftPressed &&
        key == LogicalKeyboardKey.keyP) {
      unawaited(_showCharacterStatistics());
      return KeyEventResult.handled;
    }

    if (!isControlPressed &&
        isAltPressed &&
        !isShiftPressed &&
        (key == LogicalKeyboardKey.arrowUp ||
            key == LogicalKeyboardKey.arrowDown)) {
      _moveBlocksByOffset(
        activeBlockId: block.id,
        offset: key == LogicalKeyboardKey.arrowUp ? -1 : 1,
      );
      return KeyEventResult.handled;
    }

    if (!isControlPressed &&
        !isAltPressed &&
        !isShiftPressed &&
        key == LogicalKeyboardKey.escape &&
        hasBlockSelection) {
      _clearBlockSelection();
      return KeyEventResult.handled;
    }

    if (isControlPressed &&
        !isAltPressed &&
        !isShiftPressed &&
        key == LogicalKeyboardKey.keyC &&
        hasBlockSelection) {
      unawaited(_copySelectedBlocks());
      return KeyEventResult.handled;
    }

    if (isControlPressed &&
        !isAltPressed &&
        !isShiftPressed &&
        key == LogicalKeyboardKey.keyX &&
        hasBlockSelection) {
      unawaited(_cutSelectedBlocks());
      return KeyEventResult.handled;
    }

    if (isControlPressed &&
        !isAltPressed &&
        !isShiftPressed &&
        key == LogicalKeyboardKey.keyV &&
        hasBlockSelection) {
      _pasteCopiedBlocks();
      return KeyEventResult.handled;
    }

    if (isControlPressed &&
        !isAltPressed &&
        isShiftPressed &&
        key == LogicalKeyboardKey.keyV &&
        _blockClipboard.isNotEmpty) {
      _pasteCopiedBlocks(afterBlockId: block.id);
      return KeyEventResult.handled;
    }

    if (!isControlPressed &&
        !isAltPressed &&
        !isShiftPressed &&
        hasBlockSelection &&
        (key == LogicalKeyboardKey.delete ||
            key == LogicalKeyboardKey.backspace)) {
      _deleteSelectedBlocks();
      return KeyEventResult.handled;
    }

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

  void _handleBlockPointerDown(String blockId) {
    final isControlPressed = HardwareKeyboard.instance.isControlPressed;
    final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

    if (!isControlPressed && !isShiftPressed) {
      _selectionAnchorId = blockId;

      if (_selectedBlockIds.isNotEmpty && mounted) {
        setState(_selectedBlockIds.clear);
      }

      return;
    }

    if (isShiftPressed) {
      _selectBlockRange(
        blockId,
        additive: isControlPressed,
      );
      return;
    }

    setState(() {
      if (_selectedBlockIds.contains(blockId)) {
        _selectedBlockIds.remove(blockId);
      } else {
        _selectedBlockIds.add(blockId);
      }

      _selectionAnchorId = blockId;
    });
  }

  void _selectBlockRange(
    String targetBlockId, {
    required bool additive,
  }) {
    final blocks = _controller.document.blocks;
    final firstSelectedBlockId =
        _selectedBlockIds.isEmpty ? null : _selectedBlockIds.first;
    final anchorBlockId = _selectionAnchorId ??
        _focusedBlockId() ??
        firstSelectedBlockId ??
        targetBlockId;
    final anchorIndex = blocks.indexWhere(
      (block) => block.id == anchorBlockId,
    );
    final targetIndex = blocks.indexWhere(
      (block) => block.id == targetBlockId,
    );

    if (targetIndex == -1) {
      return;
    }

    final safeAnchorIndex = anchorIndex == -1 ? targetIndex : anchorIndex;
    final startIndex = math.min(safeAnchorIndex, targetIndex);
    final endIndex = math.max(safeAnchorIndex, targetIndex);

    setState(() {
      if (!additive) {
        _selectedBlockIds.clear();
      }

      for (var index = startIndex; index <= endIndex; index++) {
        _selectedBlockIds.add(blocks[index].id);
      }

      _selectionAnchorId = anchorBlockId;
    });
  }

  List<String> _selectedIdsInDocumentOrder() {
    return _controller.document.blocks
        .where((block) => _selectedBlockIds.contains(block.id))
        .map((block) => block.id)
        .toList(growable: false);
  }

  Future<void> _copySelectedBlocks() async {
    final selectedBlocks = _controller.copyBlocksByIds(_selectedBlockIds);

    if (selectedBlocks.isEmpty) {
      return;
    }

    _blockClipboard = selectedBlocks;

    try {
      await Clipboard.setData(
        ClipboardData(
          text: selectedBlocks.map((block) => block.text).join('\n\n'),
        ),
      );
    } catch (_) {
      // The internal Filmsoz clipboard still preserves block types.
    }

    if (!mounted) {
      return;
    }

    setState(() {});

    _showOperationMessage(
      'Скопировано блоков: ${selectedBlocks.length}',
    );
  }

  Future<void> _cutSelectedBlocks() async {
    final selectedIds = _selectedIdsInDocumentOrder();
    final selectedBlocks = _controller.copyBlocksByIds(selectedIds);

    if (selectedBlocks.isEmpty) {
      return;
    }

    _blockClipboard = selectedBlocks;

    try {
      await Clipboard.setData(
        ClipboardData(
          text: selectedBlocks.map((block) => block.text).join('\n\n'),
        ),
      );
    } catch (_) {
      // Cutting still works through the internal Filmsoz clipboard.
    }

    if (!mounted) {
      return;
    }

    _deleteBlockIds(
      selectedIds,
      successMessage: 'Вырезано блоков: ${selectedBlocks.length}',
    );
  }

  void _deleteSelectedBlocks() {
    final selectedIds = _selectedIdsInDocumentOrder();

    if (selectedIds.isEmpty) {
      return;
    }

    _deleteBlockIds(
      selectedIds,
      successMessage: 'Удалено блоков: ${selectedIds.length}',
    );
  }

  void _deleteBlockIds(
    List<String> blockIds, {
    required String successMessage,
  }) {
    final result = _controller.deleteBlocks(blockIds);

    if (result == null) {
      return;
    }

    _selectedBlockIds.clear();
    _selectionAnchorId = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _focusBlockAtOffset(
        result.focusBlockId,
        result.cursorOffset,
      );
      _showOperationMessage(successMessage);
    });
  }

  void _pasteCopiedBlocks({String? afterBlockId}) {
    if (_blockClipboard.isEmpty) {
      _showOperationMessage('Буфер блоков Filmsoz пуст.');
      return;
    }

    final selectedIds = _selectedIdsInDocumentOrder();
    final documentBlocks = _controller.document.blocks;
    final lastBlockId = documentBlocks.isEmpty ? null : documentBlocks.last.id;
    final insertionAnchor = selectedIds.isNotEmpty
        ? selectedIds.last
        : afterBlockId ?? _focusedBlockId() ?? lastBlockId;
    final result = _controller.insertBlocksAfter(
      afterBlockId: insertionAnchor,
      blocks: _blockClipboard,
    );

    if (result == null) {
      return;
    }

    setState(() {
      _selectedBlockIds
        ..clear()
        ..addAll(result.insertedBlockIds);
      _selectionAnchorId = result.focusBlockId;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _focusBlock(
        result.focusBlockId,
        cursorAtEnd: false,
      );
      _showOperationMessage(
        'Вставлено блоков: ${result.insertedBlockIds.length}',
      );
    });
  }

  void _clearBlockSelection() {
    if (_selectedBlockIds.isEmpty) {
      return;
    }

    setState(() {
      _selectedBlockIds.clear();
      _selectionAnchorId = null;
    });
  }

  void _moveFocusedOrSelectedBlocks(int offset) {
    final selectedIds = _selectedIdsInDocumentOrder();
    final activeBlockId =
        _focusedBlockId() ?? (selectedIds.isEmpty ? null : selectedIds.first);

    if (activeBlockId == null) {
      return;
    }

    _moveBlocksByOffset(
      activeBlockId: activeBlockId,
      offset: offset,
    );
  }

  void _moveBlocksByOffset({
    required String activeBlockId,
    required int offset,
  }) {
    final selectedIds = _selectedIdsInDocumentOrder();
    final activeBlock = _findBlockById(activeBlockId);

    if (selectedIds.isEmpty && activeBlock?.type == BlockType.sceneHeading) {
      _moveScene(activeBlockId, offset);
      return;
    }

    final movedIds =
        selectedIds.isEmpty ? <String>[activeBlockId] : selectedIds;
    final result = _controller.moveBlocksByOffset(
      blockIds: movedIds,
      offset: offset,
      focusBlockId: activeBlockId,
    );

    if (result == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _revealBlock(result.focusBlockId);
    });
  }

  List<String> _draggedBlockIds(String draggedBlockId) {
    if (_selectedBlockIds.contains(draggedBlockId)) {
      return _selectedIdsInDocumentOrder();
    }

    return <String>[draggedBlockId];
  }

  void _beginBlockDrag(String blockId) {
    _stopDragAutoScroll();

    setState(() {
      if (!_selectedBlockIds.contains(blockId)) {
        _selectedBlockIds
          ..clear()
          ..add(blockId);
        _selectionAnchorId = blockId;
      }

      _draggingBlockId = blockId;
      _dragHoverTargetId = null;
      _dragInsertAfter = false;
    });
  }

  void _finishBlockDrag() {
    _stopDragAutoScroll();

    if (!mounted || (_draggingBlockId == null && _dragHoverTargetId == null)) {
      return;
    }

    setState(() {
      _draggingBlockId = null;
      _dragHoverTargetId = null;
      _dragInsertAfter = false;
    });
  }

  void _stopDragAutoScroll() {
    _dragAutoScrollTimer?.cancel();
    _dragAutoScrollTimer = null;
    _lastDragGlobalPosition = null;
  }

  void _updateBlockDragHover(
    String targetBlockId,
    Offset globalPosition,
  ) {
    final blockContext = _blockKeys[targetBlockId]?.currentContext;
    final renderObject = blockContext?.findRenderObject();

    if (renderObject is! RenderBox) {
      return;
    }

    final localPosition = renderObject.globalToLocal(globalPosition);
    final insertAfter = localPosition.dy > renderObject.size.height / 2;

    if (_dragHoverTargetId != targetBlockId ||
        _dragInsertAfter != insertAfter) {
      setState(() {
        _dragHoverTargetId = targetBlockId;
        _dragInsertAfter = insertAfter;
      });
    }

    _lastDragGlobalPosition = globalPosition;
    _dragAutoScrollTimer ??= Timer.periodic(
      const Duration(milliseconds: 16),
      (_) {
        final dragPosition = _lastDragGlobalPosition;

        if (dragPosition != null) {
          _autoScrollDuringDrag(dragPosition);
        }
      },
    );
    _autoScrollDuringDrag(globalPosition);
  }

  void _acceptBlockDrop(
    String draggedBlockId,
    String targetBlockId,
  ) {
    final movedIds = _draggedBlockIds(draggedBlockId);
    final result = _controller.moveBlocksRelativeToTarget(
      blockIds: movedIds,
      targetBlockId: targetBlockId,
      placeAfter: _dragInsertAfter,
      focusBlockId: draggedBlockId,
    );

    if (result == null) {
      _finishBlockDrag();
      return;
    }

    _stopDragAutoScroll();

    setState(() {
      _selectedBlockIds
        ..clear()
        ..addAll(result.movedBlockIds);
      _selectionAnchorId = result.focusBlockId;
      _draggingBlockId = null;
      _dragHoverTargetId = null;
      _dragInsertAfter = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _revealBlock(result.focusBlockId);
    });
  }

  void _autoScrollDuringDrag(Offset globalPosition) {
    if (!_scrollController.hasClients) {
      return;
    }

    final scrollContext = _scrollAreaKey.currentContext;
    final renderObject = scrollContext?.findRenderObject();

    if (renderObject is! RenderBox) {
      return;
    }

    final localPosition = renderObject.globalToLocal(globalPosition);
    const edgeSize = 84.0;
    const maximumStep = 24.0;
    var scrollStep = 0.0;

    if (localPosition.dy < edgeSize) {
      final factor = ((edgeSize - localPosition.dy) / edgeSize).clamp(0.0, 1.0);
      scrollStep = -maximumStep * factor;
    } else if (localPosition.dy > renderObject.size.height - edgeSize) {
      final factor =
          ((localPosition.dy - (renderObject.size.height - edgeSize)) /
                  edgeSize)
              .clamp(0.0, 1.0);
      scrollStep = maximumStep * factor;
    }

    if (scrollStep == 0) {
      return;
    }

    final position = _scrollController.position;
    final nextOffset = (_scrollController.offset + scrollStep)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();

    if (nextOffset != _scrollController.offset) {
      _scrollController.jumpTo(nextOffset);
    }
  }

  void _revealBlock(String blockId) {
    final blockContext = _blockKeys[blockId]?.currentContext;

    if (blockContext == null) {
      return;
    }

    unawaited(
      Scrollable.ensureVisible(
        blockContext,
        alignment: 0.22,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  Widget _buildDragHandle(FilmBlock block) {
    if (block.type == BlockType.sceneHeading) {
      return const Tooltip(
        message: 'Сцену можно перетащить в навигаторе слева',
        child: Padding(
          padding: EdgeInsets.only(top: 8, right: 4),
          child: Icon(
            Icons.view_agenda_outlined,
            size: 17,
            color: Color(0xFFE5A93C),
          ),
        ),
      );
    }

    final selectedCount =
        _selectedBlockIds.contains(block.id) ? _selectedBlockIds.length : 1;

    return Draggable<String>(
      data: block.id,
      axis: Axis.vertical,
      maxSimultaneousDrags: 1,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      onDragStarted: () => _beginBlockDrag(block.id),
      onDragEnd: (_) => _finishBlockDrag(),
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF2B2B2E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5A93C)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55000000),
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Text(
            selectedCount == 1 ? 'Перемещение блока' : '$selectedCount блоков',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      childWhenDragging: const Opacity(
        opacity: 0.28,
        child: Icon(
          Icons.drag_indicator,
          size: 18,
          color: Color(0xFF8D8D99),
        ),
      ),
      child: const MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: Tooltip(
          message: 'Перетащить блок или выбранную группу',
          child: Padding(
            padding: EdgeInsets.only(top: 8, right: 4),
            child: Icon(
              Icons.drag_indicator,
              size: 18,
              color: Color(0xFF8D8D99),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSceneInlineToolbar(SceneSection scene) {
    final isCollapsed = _collapsedSceneIds.contains(scene.id);
    final sceneCount = _controller.document.sceneSections.length;

    return Container(
      height: 34,
      margin: const EdgeInsets.only(top: 8, bottom: 2),
      padding: const EdgeInsets.only(left: 8, right: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F1E5),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFFE7D6B5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE5A93C),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'СЦЕНА ${scene.number}',
              style: const TextStyle(
                color: Color(0xFF211A0D),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${scene.blockCount} блоков • ${scene.wordCount} слов • '
              '${scene.characterCount} символов'
              '${isCollapsed ? ' • СВЕРНУТА' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF6E6047),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            tooltip: isCollapsed ? 'Развернуть сцену' : 'Свернуть сцену',
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
            padding: EdgeInsets.zero,
            onPressed: () => _toggleSceneCollapsed(scene.id),
            icon: Icon(
              isCollapsed
                  ? Icons.unfold_more_rounded
                  : Icons.unfold_less_rounded,
              size: 17,
              color: const Color(0xFF6E6047),
            ),
          ),
          IconButton(
            tooltip: 'Переместить сцену выше',
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
            padding: EdgeInsets.zero,
            onPressed: scene.number > 1 ? () => _moveScene(scene.id, -1) : null,
            icon: const Icon(Icons.arrow_upward, size: 16),
          ),
          IconButton(
            tooltip: 'Переместить сцену ниже',
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
            padding: EdgeInsets.zero,
            onPressed: scene.number < sceneCount
                ? () => _moveScene(scene.id, 1)
                : null,
            icon: const Icon(Icons.arrow_downward, size: 16),
          ),
          IconButton(
            tooltip: 'Дублировать сцену',
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
            padding: EdgeInsets.zero,
            onPressed: () => _duplicateScene(scene.id),
            icon: const Icon(Icons.copy_all_outlined, size: 16),
          ),
          IconButton(
            tooltip: 'Удалить сцену',
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
            padding: EdgeInsets.zero,
            onPressed: () => unawaited(_deleteScene(scene.id)),
            icon: const Icon(
              Icons.delete_outline,
              size: 16,
              color: Color(0xFFB85050),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectableBlock(
    FilmBlock block, {
    SceneSection? scene,
  }) {
    final isSelected = _selectedBlockIds.contains(block.id);
    final isDropTarget = _dragHoverTargetId == block.id;
    final draggedIds = _draggingBlockId == null
        ? const <String>[]
        : _draggedBlockIds(_draggingBlockId!);
    final canAcceptDrop = !draggedIds.contains(block.id);

    return KeyedSubtree(
      key: _blockKeys[block.id],
      child: DragTarget<String>(
        onWillAcceptWithDetails: (details) {
          return !_draggedBlockIds(details.data).contains(block.id);
        },
        onMove: (details) {
          _updateBlockDragHover(block.id, details.offset);
        },
        onLeave: (_) {
          if (_dragHoverTargetId == block.id && mounted) {
            setState(() {
              _dragHoverTargetId = null;
              _dragInsertAfter = false;
            });
          }
        },
        onAcceptWithDetails: (details) {
          _acceptBlockDrop(details.data, block.id);
        },
        builder: (context, candidateData, rejectedData) {
          final showDropLine =
              isDropTarget && canAcceptDrop && candidateData.isNotEmpty;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: showDropLine && !_dragInsertAfter
                      ? const Color(0xFFE5A93C)
                      : Colors.transparent,
                  width: 3,
                ),
                bottom: BorderSide(
                  color: showDropLine && _dragInsertAfter
                      ? const Color(0xFFE5A93C)
                      : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 26,
                  child: _buildDragHandle(block),
                ),
                Expanded(
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: (_) => _handleBlockPointerDown(block.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0x16E5A93C)
                            : Colors.transparent,
                        border: Border(
                          left: BorderSide(
                            color: isSelected
                                ? const Color(0xFFE5A93C)
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (scene != null) _buildSceneInlineToolbar(scene),
                          ScriptBlockWidget(
                            block: block,
                            textController: _textControllers[block.id]!,
                            focusNode: _focusNodes[block.id]!,
                            onChanged: (text) => _handleTextChanged(
                              block.id,
                              text,
                            ),
                            nextBlockHint:
                                _editingFlowService.nextBlockHint(block.type),
                            suggestions: _suggestionsForBlock(block),
                            onSuggestionSelected: (suggestion) {
                              _applySuggestion(block, suggestion);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBlockSelectionToolbar() {
    return Container(
      height: 44,
      color: const Color(0xFF2B2B2E),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(
            Icons.select_all,
            size: 18,
            color: Color(0xFFE5A93C),
          ),
          const SizedBox(width: 8),
          Text(
            'Выбрано блоков: ${_selectedBlockIds.length}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 18),
          const Expanded(
            child: Text(
              'Alt+↑/↓ — переместить  •  Перетаскивание — изменить место',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFFB8B8BD),
                fontSize: 11,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Переместить выше (Alt+↑)',
            onPressed: () => _moveFocusedOrSelectedBlocks(-1),
            icon: const Icon(Icons.arrow_upward, size: 17),
          ),
          IconButton(
            tooltip: 'Переместить ниже (Alt+↓)',
            onPressed: () => _moveFocusedOrSelectedBlocks(1),
            icon: const Icon(Icons.arrow_downward, size: 17),
          ),
          TextButton.icon(
            onPressed: () => unawaited(_copySelectedBlocks()),
            icon: const Icon(Icons.copy_outlined, size: 16),
            label: const Text('Копировать'),
          ),
          TextButton.icon(
            onPressed: () => unawaited(_cutSelectedBlocks()),
            icon: const Icon(Icons.content_cut_outlined, size: 16),
            label: const Text('Вырезать'),
          ),
          TextButton.icon(
            onPressed:
                _blockClipboard.isEmpty ? null : () => _pasteCopiedBlocks(),
            icon: const Icon(Icons.content_paste_outlined, size: 16),
            label: const Text('Вставить'),
          ),
          TextButton.icon(
            onPressed: _deleteSelectedBlocks,
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Удалить'),
          ),
          IconButton(
            tooltip: 'Снять выделение (Esc)',
            onPressed: _clearBlockSelection,
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
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

  String? _currentInsertionAnchorId() {
    final selectedIds = _selectedIdsInDocumentOrder();

    if (selectedIds.isNotEmpty) {
      return selectedIds.last;
    }

    return _focusedBlockId() ?? _controller.document.blocks.lastOrNull?.id;
  }

  void _insertQuickBlock(BlockType type) {
    final initialText = switch (type) {
      BlockType.sceneHeading => 'ИНТ. ЛОКАЦИЯ - ДЕНЬ',
      BlockType.parenthetical => '()',
      BlockType.action => '',
      BlockType.character => '',
      BlockType.dialogue => '',
      BlockType.transition => '',
    };
    final result = _controller.insertBlocksAfter(
      afterBlockId: _currentInsertionAnchorId(),
      blocks: <FilmBlock>[
        FilmBlock(
          id: 'quick-insert-template',
          type: type,
          text: initialText,
        ),
      ],
    );

    if (result == null) {
      return;
    }

    setState(() {
      _selectedBlockIds.clear();
      _selectionAnchorId = result.focusBlockId;
    });

    final cursorOffset =
        type == BlockType.parenthetical ? 1 : initialText.length;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusBlockAtOffset(result.focusBlockId, cursorOffset);
      }
    });
  }

  void _duplicateFocusedOrSelectedBlocks({String? activeBlockId}) {
    final selectedIds = _selectedIdsInDocumentOrder();
    final fallbackId = activeBlockId ?? _focusedBlockId();
    final sourceIds = selectedIds.isNotEmpty
        ? selectedIds
        : fallbackId == null
            ? <String>[]
            : <String>[fallbackId];

    if (sourceIds.isEmpty) {
      return;
    }

    final sourceBlocks = _controller.copyBlocksByIds(sourceIds);
    final result = _controller.insertBlocksAfter(
      afterBlockId: sourceIds.last,
      blocks: sourceBlocks,
    );

    if (result == null) {
      return;
    }

    setState(() {
      _selectedBlockIds
        ..clear()
        ..addAll(result.insertedBlockIds);
      _selectionAnchorId = result.insertedBlockIds.first;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _focusBlock(result.focusBlockId, cursorAtEnd: true);
      _showOperationMessage(
        result.insertedBlockIds.length == 1
            ? 'Блок продублирован'
            : 'Продублировано блоков: ${result.insertedBlockIds.length}',
      );
    });
  }

  Future<void> _showFindReplaceDialog() async {
    final findController = TextEditingController();
    final replaceController = TextEditingController();
    var matchCase = false;

    final request = await showDialog<_FindReplaceRequest>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final matchCount = _productivityService.countMatches(
              _controller.document,
              findController.text,
              matchCase: matchCase,
            );

            return AlertDialog(
              title: const Text('Поиск и замена'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: findController,
                      autofocus: true,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Найти',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: replaceController,
                      decoration: const InputDecoration(
                        labelText: 'Заменить на',
                        prefixIcon: Icon(Icons.find_replace),
                      ),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: matchCase,
                      title: const Text('Учитывать регистр'),
                      onChanged: (value) {
                        setDialogState(() {
                          matchCase = value ?? false;
                        });
                      },
                    ),
                    Text(
                      findController.text.trim().isEmpty
                          ? 'Введите текст для поиска.'
                          : 'Найдено совпадений: $matchCount',
                      style: TextStyle(
                        color: matchCount > 0
                            ? const Color(0xFF80B980)
                            : const Color(0xFF8D8D99),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Отмена'),
                ),
                FilledButton.icon(
                  onPressed: matchCount == 0
                      ? null
                      : () {
                          Navigator.of(context).pop(
                            _FindReplaceRequest(
                              query: findController.text,
                              replacement: replaceController.text,
                              matchCase: matchCase,
                            ),
                          );
                        },
                  icon: const Icon(Icons.find_replace),
                  label: Text('Заменить всё ($matchCount)'),
                ),
              ],
            );
          },
        );
      },
    );

    findController.dispose();
    replaceController.dispose();

    if (request == null || !mounted) {
      return;
    }

    _forceTextSync = true;
    final replaced = _controller.replaceAllText(
      request.query,
      request.replacement,
      matchCase: request.matchCase,
    );
    _syncEditors();
    _forceTextSync = false;

    _showOperationMessage('Заменено совпадений: $replaced');
  }

  Future<void> _showCharacterStatistics() async {
    final statistics = _productivityService.characterStatistics(
      _controller.document,
    );

    final blockId = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Персонажи (${statistics.length})'),
          content: SizedBox(
            width: 560,
            height: 420,
            child: statistics.isEmpty
                ? const Center(
                    child: Text(
                      'В сценарии пока нет блоков персонажей.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    itemCount: statistics.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final statistic = statistics[index];

                      return ListTile(
                        leading: CircleAvatar(
                          child: Text('${index + 1}'),
                        ),
                        title: Text(
                          statistic.name,
                          style: const TextStyle(
                            fontFamily: 'Courier New',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          'Появлений: ${statistic.characterBlocks}  •  '
                          'Реплик: ${statistic.dialogueBlocks}  •  '
                          'Слов: ${statistic.dialogueWords}',
                        ),
                        trailing: const Icon(Icons.arrow_forward),
                        onTap: () {
                          Navigator.of(context).pop(statistic.firstBlockId);
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Закрыть'),
            ),
          ],
        );
      },
    );

    if (blockId == null || !mounted) {
      return;
    }

    final scene = _findSceneForBlock(blockId);

    if (scene != null && _collapsedSceneIds.contains(scene.id)) {
      setState(() {
        _collapsedSceneIds.remove(scene.id);
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _revealBlock(blockId);
      _focusBlock(blockId, cursorAtEnd: true);
    });
  }

  Future<void> _showGoToSceneDialog() async {
    final scenes = _controller.document.sceneSections;
    final searchController = TextEditingController();
    var query = '';

    final sceneId = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = scenes
                .where((scene) => scene.matchesQuery(query))
                .toList(growable: false);

            return AlertDialog(
              title: const Text('Перейти к сцене'),
              content: SizedBox(
                width: 600,
                height: 460,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      autofocus: true,
                      onChanged: (value) {
                        setDialogState(() {
                          query = value;
                        });
                      },
                      decoration: const InputDecoration(
                        hintText: 'Номер, локация или текст сцены...',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('Сцены не найдены.'))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final scene = filtered[index];

                                return ListTile(
                                  leading: CircleAvatar(
                                    child: Text('${scene.number}'),
                                  ),
                                  title: Text(
                                    scene.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'Courier New',
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${scene.blockCount} блоков • '
                                    '${scene.wordCount} слов',
                                  ),
                                  onTap: () {
                                    Navigator.of(context).pop(scene.id);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Отмена'),
                ),
              ],
            );
          },
        );
      },
    );

    searchController.dispose();

    if (sceneId == null || !mounted) {
      return;
    }

    final scene = _controller.document.sceneById(sceneId);

    if (scene != null) {
      await _selectScene(scene);
    }
  }

  Future<void> _editSceneNote([String? sceneId]) async {
    final resolvedSceneId = sceneId ?? _activeSceneId;

    if (resolvedSceneId == null) {
      return;
    }

    final scene = _controller.document.sceneById(resolvedSceneId);

    if (scene == null || !mounted) {
      return;
    }

    final noteController = TextEditingController(
      text: _controller.document.sceneNote(resolvedSceneId),
    );

    final result = await showDialog<_SceneNoteResult>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Заметка к сцене ${scene.number}'),
          content: SizedBox(
            width: 560,
            child: TextField(
              controller: noteController,
              autofocus: true,
              minLines: 6,
              maxLines: 14,
              decoration: InputDecoration(
                hintText: 'Идеи, реквизит, задачи, режиссёрские замечания...',
                helperText: scene.title,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            if (noteController.text.trim().isNotEmpty)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(
                    const _SceneNoteResult(text: ''),
                  );
                },
                child: const Text('Удалить заметку'),
              ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop(
                  _SceneNoteResult(text: noteController.text),
                );
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Сохранить'),
            ),
          ],
        );
      },
    );

    noteController.dispose();

    if (result == null || !mounted) {
      return;
    }

    final changed = _controller.setSceneNote(
      resolvedSceneId,
      result.text,
    );

    if (changed) {
      _showOperationMessage(
        result.text.trim().isEmpty ? 'Заметка удалена' : 'Заметка сохранена',
      );
    }
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
    _stopDragAutoScroll();
    _selectedBlockIds.clear();
    _collapsedSceneIds.clear();
    _selectionAnchorId = null;
    _draggingBlockId = null;
    _dragHoverTargetId = null;
    _dragInsertAfter = false;
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
    final hadBlockSelection = _selectedBlockIds.isNotEmpty;
    _stopDragAutoScroll();
    _selectedBlockIds.clear();
    _selectionAnchorId = null;
    _draggingBlockId = null;
    _dragHoverTargetId = null;
    _dragInsertAfter = false;

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
      if (hadBlockSelection && mounted) {
        setState(() {});
      }

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

  SceneSection? _findSceneForBlock(String blockId) {
    final blocks = _controller.document.blocks;
    final blockIndex = blocks.indexWhere((block) => block.id == blockId);

    if (blockIndex == -1) {
      return null;
    }

    for (final scene in _controller.document.sceneSections) {
      if (blockIndex >= scene.startIndex &&
          blockIndex < scene.endIndexExclusive) {
        return scene;
      }
    }

    return _controller.document.sceneSections.firstOrNull;
  }

  void _toggleSceneCollapsed(String sceneId) {
    final scene = _controller.document.sceneById(sceneId);

    if (scene == null) {
      return;
    }

    final shouldCollapse = !_collapsedSceneIds.contains(sceneId);
    final focusedBlockId = _focusedBlockId();
    final focusedInsideScene = focusedBlockId != null &&
        scene.blockIds.contains(focusedBlockId) &&
        focusedBlockId != scene.id;

    setState(() {
      if (shouldCollapse) {
        _collapsedSceneIds.add(sceneId);
        final hiddenIds = scene.blocks.skip(1).map((block) => block.id).toSet();
        _selectedBlockIds.removeWhere(hiddenIds.contains);

        if (_selectionAnchorId != null &&
            hiddenIds.contains(_selectionAnchorId)) {
          _selectionAnchorId = scene.id;
        }
      } else {
        _collapsedSceneIds.remove(sceneId);
      }
    });

    if (shouldCollapse && focusedInsideScene) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusBlock(scene.id, cursorAtEnd: true);
        }
      });
    }
  }

  void _moveScene(String sceneId, int offset) {
    final result = _controller.moveSceneByOffset(
      sceneId: sceneId,
      offset: offset,
    );

    if (result == null) {
      return;
    }

    setState(() {
      _activeSceneId = result.sceneId;
      _selectedBlockIds.clear();
      _selectionAnchorId = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _revealBlock(result.sceneId);
      _showOperationMessage(
        'Сцена перемещена на позицию ${result.sceneNumber}',
      );
    });
  }

  void _dropScene(
    String sceneId,
    String targetSceneId,
    bool placeAfter,
  ) {
    final result = _controller.moveSceneRelativeToTarget(
      sceneId: sceneId,
      targetSceneId: targetSceneId,
      placeAfter: placeAfter,
    );

    if (result == null) {
      return;
    }

    setState(() {
      _activeSceneId = result.sceneId;
      _selectedBlockIds.clear();
      _selectionAnchorId = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _revealBlock(result.sceneId);
      _showOperationMessage(
        'Сцена перемещена на позицию ${result.sceneNumber}',
      );
    });
  }

  void _duplicateScene(String sceneId) {
    final result = _controller.duplicateScene(sceneId);

    if (result == null) {
      return;
    }

    setState(() {
      _activeSceneId = result.sceneId;
      _selectedBlockIds.clear();
      _selectionAnchorId = null;
      _collapsedSceneIds.remove(result.sceneId);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _focusBlock(result.sceneId, cursorAtEnd: true);
      _showOperationMessage(
        'Создана копия сцены ${result.sceneNumber}',
      );
    });
  }

  Future<void> _deleteScene(String sceneId) async {
    final scene = _controller.document.sceneById(sceneId);

    if (scene == null || !mounted) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Удалить сцену ${scene.number}?'),
          content: Text(
            '${scene.title}\n\n'
            'Будут удалены ${scene.blockCount} блоков. '
            'Действие можно отменить через Ctrl+Z.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Удалить'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final result = _controller.deleteScene(sceneId);

    if (result == null) {
      return;
    }

    setState(() {
      _collapsedSceneIds.remove(sceneId);
      _selectedBlockIds.clear();
      _selectionAnchorId = null;
      _activeSceneId = result.activeSceneId;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _focusBlock(result.focusBlockId, cursorAtEnd: true);
      _showOperationMessage('Сцена удалена');
    });
  }

  Set<String> _hiddenBlockIdsForCollapsedScenes(
    List<SceneSection> scenes,
  ) {
    final hiddenIds = <String>{};

    for (final scene in scenes) {
      if (_collapsedSceneIds.contains(scene.id)) {
        hiddenIds.addAll(
          scene.blocks.skip(1).map((block) => block.id),
        );
      }
    }

    return hiddenIds;
  }

  Future<void> _selectScene(SceneSection scene) async {
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
    final scenes = _controller.document.sceneSections;

    if (scenes.isEmpty) {
      return;
    }

    SceneSection candidate = scenes.first;

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
    final scenes = _controller.document.sceneSections;
    final hiddenBlockIds = _hiddenBlockIdsForCollapsedScenes(scenes);
    final sceneByHeadingId = <String, SceneSection>{
      for (final scene in scenes) scene.id: scene,
    };
    final activeScene = _activeSceneId == null
        ? null
        : _controller.document.sceneById(_activeSceneId!);

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
          LogicalKeyboardKey.keyF,
          control: true,
        ): () => unawaited(_showFindReplaceDialog()),
        const SingleActivator(
          LogicalKeyboardKey.keyG,
          control: true,
        ): () => unawaited(_showGoToSceneDialog()),
        const SingleActivator(
          LogicalKeyboardKey.keyD,
          control: true,
        ): () => _duplicateFocusedOrSelectedBlocks(),
        const SingleActivator(
          LogicalKeyboardKey.keyM,
          control: true,
          shift: true,
        ): () => unawaited(_editSceneNote()),
        const SingleActivator(
          LogicalKeyboardKey.keyP,
          control: true,
          alt: true,
        ): () => unawaited(_showCharacterStatistics()),
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
        const SingleActivator(
          LogicalKeyboardKey.arrowUp,
          alt: true,
        ): () => _moveFocusedOrSelectedBlocks(-1),
        const SingleActivator(
          LogicalKeyboardKey.arrowDown,
          alt: true,
        ): () => _moveFocusedOrSelectedBlocks(1),
        if (_selectedBlockIds.isNotEmpty)
          const SingleActivator(
            LogicalKeyboardKey.keyC,
            control: true,
          ): () => unawaited(_copySelectedBlocks()),
        if (_selectedBlockIds.isNotEmpty)
          const SingleActivator(
            LogicalKeyboardKey.keyX,
            control: true,
          ): () => unawaited(_cutSelectedBlocks()),
        if (_selectedBlockIds.isNotEmpty)
          const SingleActivator(
            LogicalKeyboardKey.keyV,
            control: true,
          ): () => _pasteCopiedBlocks(),
        if (_blockClipboard.isNotEmpty)
          const SingleActivator(
            LogicalKeyboardKey.keyV,
            control: true,
            shift: true,
          ): () => _pasteCopiedBlocks(),
        if (_selectedBlockIds.isNotEmpty)
          const SingleActivator(LogicalKeyboardKey.delete):
              _deleteSelectedBlocks,
        if (_selectedBlockIds.isNotEmpty)
          const SingleActivator(LogicalKeyboardKey.backspace):
              _deleteSelectedBlocks,
        if (_selectedBlockIds.isNotEmpty)
          const SingleActivator(LogicalKeyboardKey.escape):
              _clearBlockSelection,
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
                ScreenplayProductivityToolbar(
                  onInsertBlock: _insertQuickBlock,
                  onDuplicateBlocks: () {
                    _duplicateFocusedOrSelectedBlocks();
                  },
                  onFindReplace: () => unawaited(_showFindReplaceDialog()),
                  onGoToScene: () => unawaited(_showGoToSceneDialog()),
                  onShowCharacters: () {
                    unawaited(_showCharacterStatistics());
                  },
                  onEditSceneNote: () => unawaited(_editSceneNote()),
                  hasActiveScene: activeScene != null,
                  hasFocusedBlock:
                      _focusedBlockId() != null || _selectedBlockIds.isNotEmpty,
                ),
                Expanded(
                  child: Row(
                    children: [
                      SceneNavigator(
                        scenes: scenes,
                        selectedSceneId: _activeSceneId,
                        collapsedSceneIds: _collapsedSceneIds,
                        sceneNotes: _controller.document.sceneNotes,
                        onSceneSelected: _selectScene,
                        onToggleSceneCollapsed: _toggleSceneCollapsed,
                        onMoveScene: _moveScene,
                        onDuplicateScene: _duplicateScene,
                        onDeleteScene: (sceneId) {
                          unawaited(_deleteScene(sceneId));
                        },
                        onEditSceneNote: (sceneId) {
                          unawaited(_editSceneNote(sceneId));
                        },
                        onSceneDropped: _dropScene,
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: Column(
                          children: [
                            if (_selectedBlockIds.isNotEmpty &&
                                _draggingBlockId == null)
                              _buildBlockSelectionToolbar(),
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
                                              if (!hiddenBlockIds
                                                  .contains(block.id))
                                                _buildSelectableBlock(
                                                  block,
                                                  scene: sceneByHeadingId[
                                                      block.id],
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
                          'Блоков: ${_controller.document.blocks.length}'
                          '${_selectedBlockIds.isEmpty ? '' : '  •  Выбрано: ${_selectedBlockIds.length}'}  •  '
                          'Активная: ${activeScene == null ? '—' : '${activeScene.number}. ${activeScene.title}'}'
                          '${activeScene == null ? '' : '  •  ${activeScene.wordCount} слов'}',
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
                          '${_saveStatusText()}  •  Ctrl+S  •  Ctrl+клик: блоки  •  Ctrl+Z / Ctrl+Y',
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
    _stopDragAutoScroll();

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

class _FindReplaceRequest {
  const _FindReplaceRequest({
    required this.query,
    required this.replacement,
    required this.matchCase,
  });

  final String query;
  final String replacement;
  final bool matchCase;
}

class _SceneNoteResult {
  const _SceneNoteResult({required this.text});

  final String text;
}

extension _FirstOrNullExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
  T? get lastOrNull => isEmpty ? null : last;
}
