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

  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, FocusNode> _focusNodes = {};

  bool _isSplittingBlock = false;

  @override
  void initState() {
    super.initState();

    _controller.addListener(_onDocumentChanged);
    _syncEditors();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _controller.document.blocks.isEmpty) {
        return;
      }

      _focusBlock(
        _controller.document.blocks.first.id,
        cursorAtEnd: true,
      );
    });
  }

  void _onDocumentChanged() {
    _syncEditors();

    if (mounted) {
      setState(() {});
    }
  }

  void _syncEditors() {
    final activeIds = _controller.document.blocks
        .map((block) => block.id)
        .toSet();

    final removedIds = _textControllers.keys
        .where((id) => !activeIds.contains(id))
        .toList(growable: false);

    for (final id in removedIds) {
      final removedController = _textControllers.remove(id);
      final removedFocusNode = _focusNodes.remove(id);

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

      _focusNodes.putIfAbsent(
        block.id,
        () => FocusNode(
          debugLabel: 'filmsoz-block-${block.id}',
          onKeyEvent: (_, event) => _handleBlockKey(block.id, event),
        ),
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
      debugPrint('[Filmsoz v3] Enter: ${block.id}');
      _splitBlockAtSelection(block);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.tab) {
      debugPrint('[Filmsoz v3] Tab: ${block.id}');
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
      final cursorAtBeginning = selection.isValid &&
          selection.isCollapsed &&
          selection.start == 0;

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
    final textBeforeCursor = text.substring(0, newLineIndex);
    final textAfterCursor = text.substring(newLineIndex + 1);

    debugPrint('[Filmsoz v3] Enter fallback: ${block.id}');
    _splitBlockWithText(
      block: block,
      textBeforeCursor: textBeforeCursor,
      textAfterCursor: textAfterCursor,
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

      if (textController != null &&
          selection != null &&
          selection.isValid) {
        final baseOffset = selection.baseOffset
            .clamp(0, textController.text.length)
            .toInt();
        final extentOffset = selection.extentOffset
            .clamp(0, textController.text.length)
            .toInt();

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
    return Scaffold(
      body: Column(
        children: [
          const EditorToolbar(),
          Expanded(
            child: Row(
              children: [
                SceneNavigator(
                  scenes: _controller.document.scenes,
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: ColoredBox(
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
                                const Text(
                                  'FILMSOZ EDITOR V3 • ENTER / TAB ACTIVE',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF777777),
                                    fontFamily: 'Courier New',
                                    fontSize: 10,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                for (final block
                                    in _controller.document.blocks)
                                  ScriptBlockWidget(
                                    block: block,
                                    textController:
                                        _textControllers[block.id]!,
                                    focusNode: _focusNodes[block.id]!,
                                    onChanged: (text) =>
                                        _handleTextChanged(block.id, text),
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
            height: 26,
            color: const Color(0xFF252526),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            child: const Text(
              'Filmsoz v3 | Enter: новый блок | Tab: тип блока | Backspace: удалить пустой блок',
              style: TextStyle(
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

    for (final controller in _textControllers.values) {
      controller.dispose();
    }

    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }

    _scrollController.dispose();
    super.dispose();
  }
}
