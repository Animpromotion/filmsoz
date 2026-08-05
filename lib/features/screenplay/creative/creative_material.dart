import 'dart:convert';

enum CreativeMaterialType {
  idea,
  quote,
  link,
  image,
  research,
  character,
  location,
  unusedScene,
}

extension CreativeMaterialTypeX on CreativeMaterialType {
  String get label => switch (this) {
        CreativeMaterialType.idea => 'Идея',
        CreativeMaterialType.quote => 'Цитата',
        CreativeMaterialType.link => 'Ссылка',
        CreativeMaterialType.image => 'Изображение',
        CreativeMaterialType.research => 'Исследование',
        CreativeMaterialType.character => 'Персонаж',
        CreativeMaterialType.location => 'Локация',
        CreativeMaterialType.unusedScene => 'Неиспользованная сцена',
      };

  String get storageName => name;

  static CreativeMaterialType fromStorage(String? value) {
    return CreativeMaterialType.values.firstWhere(
      (item) => item.name == value,
      orElse: () => CreativeMaterialType.idea,
    );
  }
}

class CreativeMaterial {
  const CreativeMaterial({
    required this.id,
    required this.type,
    required this.title,
    this.body = '',
    this.source = '',
    this.url = '',
    this.folder = 'Без папки',
    this.tags = const <String>[],
    this.colorValue = 0xFFE5A93C,
    this.linkedSceneIds = const <String>[],
    this.linkedCharacterNames = const <String>[],
    this.usedBlockIds = const <String>[],
    this.imageName,
    this.imageBase64,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final CreativeMaterialType type;
  final String title;
  final String body;
  final String source;
  final String url;
  final String folder;
  final List<String> tags;
  final int colorValue;
  final List<String> linkedSceneIds;
  final List<String> linkedCharacterNames;
  final List<String> usedBlockIds;
  final String? imageName;
  final String? imageBase64;
  final String createdAt;
  final String updatedAt;

  bool get hasImage => imageBase64?.isNotEmpty == true;

  int get imageByteLength {
    final encoded = imageBase64;

    if (encoded == null || encoded.isEmpty) {
      return 0;
    }

    try {
      return base64Decode(encoded).length;
    } catch (_) {
      return 0;
    }
  }

  String get searchableText {
    return <String>[
      title,
      body,
      source,
      url,
      folder,
      ...tags,
      ...linkedCharacterNames,
      type.label,
    ].join(' ').toLowerCase();
  }

  CreativeMaterial copyWith({
    String? id,
    CreativeMaterialType? type,
    String? title,
    String? body,
    String? source,
    String? url,
    String? folder,
    List<String>? tags,
    int? colorValue,
    List<String>? linkedSceneIds,
    List<String>? linkedCharacterNames,
    List<String>? usedBlockIds,
    String? imageName,
    String? imageBase64,
    bool clearImage = false,
    String? createdAt,
    String? updatedAt,
  }) {
    return CreativeMaterial(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      source: source ?? this.source,
      url: url ?? this.url,
      folder: folder ?? this.folder,
      tags: List<String>.unmodifiable(tags ?? this.tags),
      colorValue: colorValue ?? this.colorValue,
      linkedSceneIds:
          List<String>.unmodifiable(linkedSceneIds ?? this.linkedSceneIds),
      linkedCharacterNames: List<String>.unmodifiable(
        linkedCharacterNames ?? this.linkedCharacterNames,
      ),
      usedBlockIds:
          List<String>.unmodifiable(usedBlockIds ?? this.usedBlockIds),
      imageName: clearImage ? null : imageName ?? this.imageName,
      imageBase64: clearImage ? null : imageBase64 ?? this.imageBase64,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'type': type.storageName,
      'title': title,
      'body': body,
      'source': source,
      'url': url,
      'folder': folder,
      'tags': tags,
      'colorValue': colorValue,
      'linkedSceneIds': linkedSceneIds,
      'linkedCharacterNames': linkedCharacterNames,
      'usedBlockIds': usedBlockIds,
      if (imageName != null) 'imageName': imageName,
      if (imageBase64 != null) 'imageBase64': imageBase64,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory CreativeMaterial.fromJson(Map<String, dynamic> json) {
    List<String> readStringList(Object? raw) {
      if (raw is! List) {
        return const <String>[];
      }

      return raw
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList(growable: false);
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final id = json['id']?.toString().trim();
    final title = json['title']?.toString().trim();
    final colorValue = json['colorValue'];

    return CreativeMaterial(
      id: id == null || id.isEmpty
          ? 'material_${DateTime.now().microsecondsSinceEpoch}'
          : id,
      type: CreativeMaterialTypeX.fromStorage(json['type']?.toString()),
      title: title == null || title.isEmpty ? 'Без названия' : title,
      body: json['body']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      folder: json['folder']?.toString().trim().isNotEmpty == true
          ? json['folder'].toString().trim()
          : 'Без папки',
      tags: readStringList(json['tags']),
      colorValue: colorValue is int ? colorValue : 0xFFE5A93C,
      linkedSceneIds: readStringList(json['linkedSceneIds']),
      linkedCharacterNames: readStringList(json['linkedCharacterNames']),
      usedBlockIds: readStringList(json['usedBlockIds']),
      imageName: json['imageName']?.toString(),
      imageBase64: json['imageBase64']?.toString(),
      createdAt: json['createdAt']?.toString().trim().isNotEmpty == true
          ? json['createdAt'].toString().trim()
          : now,
      updatedAt: json['updatedAt']?.toString().trim().isNotEmpty == true
          ? json['updatedAt'].toString().trim()
          : now,
    );
  }
}
