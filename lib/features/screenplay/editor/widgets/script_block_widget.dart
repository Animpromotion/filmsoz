import 'package:flutter/material.dart';
import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';

class ScriptBlockWidget extends StatelessWidget {
  const ScriptBlockWidget({
    super.key,
    required this.block,
    required this.textController,
    required this.focusNode,
    required this.onChanged,
  });

  final FilmBlock block;
  final TextEditingController textController;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  EdgeInsets _margins() {
    switch (block.type) {
      case BlockType.sceneHeading:
        return const EdgeInsets.only(top: 16, bottom: 8);
      case BlockType.action:
        return const EdgeInsets.only(top: 6, bottom: 6);
      case BlockType.character:
        return const EdgeInsets.only(top: 12, left: 230, right: 90);
      case BlockType.dialogue:
        return const EdgeInsets.only(left: 120, right: 115, bottom: 8);
      case BlockType.parenthetical:
        return const EdgeInsets.only(left: 175, right: 150);
      case BlockType.transition:
        return const EdgeInsets.only(top: 12, left: 350);
    }
  }

  TextStyle _textStyle() {
    const baseStyle = TextStyle(
      fontFamily: 'Courier New',
      fontSize: 15,
      color: Colors.black,
      height: 1.4,
    );

    switch (block.type) {
      case BlockType.sceneHeading:
      case BlockType.character:
      case BlockType.transition:
        return baseStyle.copyWith(fontWeight: FontWeight.bold);
      case BlockType.parenthetical:
        return baseStyle.copyWith(fontStyle: FontStyle.italic);
      case BlockType.action:
      case BlockType.dialogue:
        return baseStyle;
    }
  }

  String _hintText() {
    switch (block.type) {
      case BlockType.sceneHeading:
        return 'ИНТ. ЛОКАЦИЯ — ДЕНЬ';
      case BlockType.action:
        return 'Описание действия...';
      case BlockType.character:
        return 'ПЕРСОНАЖ';
      case BlockType.dialogue:
        return 'Реплика персонажа...';
      case BlockType.parenthetical:
        return '(ремарка)';
      case BlockType.transition:
        return 'ПЕРЕХОД:';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: ValueKey(block.id),
      padding: _margins(),
      child: TextField(
        controller: textController,
        focusNode: focusNode,
        minLines: 1,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        onChanged: onChanged,
        style: _textStyle(),
        cursorColor: Colors.black,
        textCapitalization: block.type == BlockType.sceneHeading ||
                block.type == BlockType.character ||
                block.type == BlockType.transition
            ? TextCapitalization.characters
            : TextCapitalization.sentences,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          hintText: _hintText(),
          hintStyle: const TextStyle(
            fontFamily: 'Courier New',
            fontSize: 15,
            color: Color(0xFFAAAAAA),
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
