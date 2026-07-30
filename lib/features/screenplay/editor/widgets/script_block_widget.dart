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
    this.nextBlockHint,
    this.suggestions = const <String>[],
    this.onSuggestionSelected,
  });

  final FilmBlock block;
  final TextEditingController textController;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final String? nextBlockHint;
  final List<String> suggestions;
  final ValueChanged<String>? onSuggestionSelected;

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
      child: AnimatedBuilder(
        animation: focusNode,
        builder: (context, _) {
          final showNextBlockHint =
              focusNode.hasFocus && nextBlockHint?.isNotEmpty == true;
          final showSuggestions = focusNode.hasFocus && suggestions.isNotEmpty;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
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
                  helperText: showNextBlockHint ? nextBlockHint : null,
                  helperMaxLines: 1,
                  helperStyle: const TextStyle(
                    fontFamily: 'Courier New',
                    fontSize: 10.5,
                    color: Color(0xFF777777),
                    height: 1.2,
                  ),
                ),
              ),
              if (showSuggestions)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: [
                      for (var index = 0; index < suggestions.length; index++)
                        ActionChip(
                          visualDensity: VisualDensity.compact,
                          avatar: index == 0
                              ? const Icon(Icons.keyboard_command_key, size: 13)
                              : null,
                          label: Text(
                            suggestions[index],
                            style: const TextStyle(
                              fontFamily: 'Courier New',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: onSuggestionSelected == null
                              ? null
                              : () => onSuggestionSelected!(suggestions[index]),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
