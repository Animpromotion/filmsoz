import 'package:flutter/material.dart';
import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';

class ScriptBlockWidget extends StatelessWidget {
  final FilmBlock block;
  final ValueChanged<String> onChanged;

  const ScriptBlockWidget({
    super.key,
    required this.block,
    required this.onChanged,
  });

  EdgeInsets _getMargins() {
    switch (block.type) {
      case BlockType.sceneHeading:
        return const EdgeInsets.only(top: 16, bottom: 8);
      case BlockType.character:
        return const EdgeInsets.only(top: 12, left: 180, right: 100);
      case BlockType.parenthetical:
        return const EdgeInsets.only(left: 130, right: 150);
      case BlockType.dialogue:
        return const EdgeInsets.only(left: 100, right: 120, bottom: 8);
      case BlockType.transition:
        return const EdgeInsets.only(top: 12, left: 250);
      case BlockType.action:
      default:
        return const EdgeInsets.only(top: 6, bottom: 6);
    }
  }

  TextStyle _getTextStyle() {
    const baseStyle = TextStyle(
      fontFamily: 'Courier Prime',
      fontSize: 12,
      color: Colors.black,
      height: 1.2,
    );

    switch (block.type) {
      case BlockType.sceneHeading:
      case BlockType.character:
      case BlockType.transition:
        return baseStyle.copyWith(fontWeight: FontWeight.bold);
      case BlockType.parenthetical:
        return baseStyle.copyWith(fontStyle: FontStyle.italic);
      default:
        return baseStyle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _getMargins(),
      child: TextFormField(
        initialValue: block.text,
        onChanged: onChanged,
        style: _getTextStyle(),
        textCapitalization: block.type == BlockType.sceneHeading ||
                block.type == BlockType.character ||
                block.type == BlockType.transition
            ? TextCapitalization.characters
            : TextCapitalization.sentences,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}
