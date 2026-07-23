import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';

class FilmDocument {
  final List<FilmBlock> blocks;

  FilmDocument({required this.blocks});

  factory FilmDocument.empty() {
    return FilmDocument(blocks: [
      FilmBlock(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: BlockType.sceneHeading,
        text: 'ИНТ. СТУДИЯ - ДЕНЬ',
      )
    ]);
  }

  List<FilmBlock> get scenes =>
      blocks.where((b) => b.type == BlockType.sceneHeading).toList();
}
