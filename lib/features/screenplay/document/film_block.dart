import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';

class FilmBlock {
  final String id;
  BlockType type;
  String text;

  FilmBlock({
    required this.id,
    required this.type,
    required this.text,
  });

  FilmBlock copyWith({
    String? id,
    BlockType? type,
    String? text,
  }) {
    return FilmBlock(
      id: id ?? this.id,
      type: type ?? this.type,
      text: text ?? this.text,
    );
  }
}
