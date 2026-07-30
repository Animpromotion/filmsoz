import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/editor/controller/screenplay_editor_controller.dart';
import 'package:filmsoz_studio/features/screenplay/editor/widgets/script_block_widget.dart';
import 'package:filmsoz_studio/features/screenplay/editor/widgets/script_page_sheet.dart';
import 'package:filmsoz_studio/features/screenplay/navigator/scene_navigator.dart';
import 'package:filmsoz_studio/features/screenplay/toolbar/editor_toolbar.dart';

class EditorMainScreen extends StatefulWidget {
  const EditorMainScreen({super.key});

  @override
  State<EditorMainScreen> createState() => _EditorMainScreenState();
}

class _EditorMainScreenState extends State<EditorMainScreen> {
  final ScreenplayEditorController _controller = ScreenplayEditorController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _scrollAreaKey = GlobalKey();

  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, GlobalKey> _blockKeys = {};

  bool _isSplittingBlock = false;
  bool _scrollUpdateScheduled = false;
  String? _activeSceneId;

  @override
  void initState() {
    super.initState();

    _controller.addListener(_onDocumentChanged);
    _scrollController.addListener(_scheduleActiveSceneUpdateFromScroll);
    _syncEditors();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _controller.document.blocks.isEmpty) {
        return;
      }

      final firstScene = _controller.document.scenes.firstOrNull;
      _activeSceneId = firstScene?.id;

      _focusBlock(
        _controller.document.blocks.first.id,
        cursorAtEnd: true,
      );

      setState(() {});
    });
  }

  void _onDocumentChanged() {
    _syncEditors();

    final sceneIds =
        _controller.document.scenes.map((scene) => scene.id).toSet();

    if (_activeSceneId != null && !sceneIds.contains(_activeSceneId)) {
      _activeSceneId = _controller.document.scenes.firstOrNull?.id;
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

      if (!hasFocus && textController.text != block.text) {
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

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
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

    if (key == LogicalKeyboardKey.backspace) {
      final textController = _textControllers[block.id];

      if (textController == null) {
        return KeyEventResult.ignored;
      }

      final selection = textController.selection;
      final cursorAtBeginning =
          selection.isValid && selection.isCollapsed && selection.start == 0;

      if (textController.text.isEmpty &&
          cursorAtBeginning &&
          blockIndex > 0 &&
          _controller.document.blocks.length > 1) {
        _deleteEmptyBlock(block);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void _handleTextChanged(String blockId, String text) {
    if (_isSplittingBlock) {
      return;
    }

    final newLineIndex = text.indexOf('\n');

    if (newLineIndex == -1) {
      _controller.updateBlockText(blockId, text);
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

    textController.value = TextEditingValue(
      text: textBeforeCursor,
      selection: TextSelection.collapsed(offset: textBeforeCursor.length),
    );

    final newBlock = _controller.splitBlock(
      id: block.id,
      textBeforeCursor: textBeforeCursor,
      textAfterCursor: textAfterCursor,
      nextType: _nextTypeAfterEnter(block.type),
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
    final types = BlockType.values;
    final currentIndex = types.indexOf(block.type);
    final nextIndex = reverse
        ? (currentIndex - 1 + types.length) % types.length
        : (currentIndex + 1) % types.length;

    final selection = _textControllers[block.id]?.selection;

    _controller.setBlockType(block.id, types[nextIndex]);

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

  void _deleteEmptyBlock(FilmBlock block) {
    final blocks = _controller.document.blocks;
    final index = blocks.indexWhere((item) => item.id == block.id);

    if (index <= 0 || blocks.length <= 1) {
      return;
    }

    final previousBlock = blocks[index - 1];
    _controller.deleteBlock(block.id);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _focusBlock(previousBlock.id, cursorAtEnd: true);
    });
  }

  void _focusBlock(
    String blockId, {
    required bool cursorAtEnd,
  }) {
    final focusNode = _focusNodes[blockId];
    final textController = _textControllers[blockId];

    if (focusNode == null || textController == null) {
      return;
    }

    focusNode.requestFocus();
    textController.selection = TextSelection.collapsed(
      offset: cursorAtEnd ? textController.text.length : 0,
    );
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

  BlockType _nextTypeAfterEnter(BlockType currentType) {
    switch (currentType) {
      case BlockType.sceneHeading:
        return BlockType.action;
      case BlockType.action:
        return BlockType.action;
      case BlockType.character:
        return BlockType.dialogue;
      case BlockType.dialogue:
        return BlockType.character;
      case BlockType.parenthetical:
        return BlockType.dialogue;
      case BlockType.transition:
        return BlockType.sceneHeading;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scenes = _controller.document.scenes;
    final activeScene = _findBlockById(_activeSceneId);

    return Scaffold(
      body: Column(
        children: [
          const EditorToolbar(),
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
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Center(
                          child: ScriptPageSheet(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final block in _controller.document.blocks)
                                  KeyedSubtree(
                                    key: _blockKeys[block.id],
                                    child: ScriptBlockWidget(
                                      block: block,
                                      textController:
                                          _textControllers[block.id]!,
                                      focusNode: _focusNodes[block.id]!,
                                      onChanged: (text) =>
                                          _handleTextChanged(block.id, text),
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
            alignment: Alignment.centerLeft,
            child: Text(
              'Сцен: ${scenes.length}  •  '
              'Блоков: ${_controller.document.blocks.length}  •  '
              'Активная: ${activeScene?.text.trim().isNotEmpty == true ? activeScene!.text : 'БЕЗ НАЗВАНИЯ'}  •  '
              'Enter: новый блок  •  Tab: тип блока',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFAAAAAA),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
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

extension _FirstOrNullExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
