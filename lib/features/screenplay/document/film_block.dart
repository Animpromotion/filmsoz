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

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'type': type.name,
      'text': text,
    };
  }

  factory FilmBlock.fromJson(Map<String, dynamic> json) {
    final rawType = json['type']?.toString();

    final type = BlockType.values.firstWhere(
      (value) => value.name == rawType,
      orElse: () => BlockType.action,
    );

    final rawId = json['id']?.toString().trim();

    return FilmBlock(
      id: rawId == null || rawId.isEmpty
          ? DateTime.now().microsecondsSinceEpoch.toString()
          : rawId,
      type: type,
      text: json['text']?.toString() ?? '',
    );
  }
}
