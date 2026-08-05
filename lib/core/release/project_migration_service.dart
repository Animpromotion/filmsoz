import 'package:filmsoz_studio/core/release/app_info.dart';

class FilmsozMigrationResult {
  const FilmsozMigrationResult({
    required this.root,
    required this.sourceVersion,
    required this.targetVersion,
    required this.messages,
  });

  final Map<String, dynamic> root;
  final int sourceVersion;
  final int targetVersion;
  final List<String> messages;

  bool get wasMigrated => sourceVersion != targetVersion || messages.isNotEmpty;
}

class FilmsozProjectMigrationService {
  const FilmsozProjectMigrationService();

  FilmsozMigrationResult migrate(Object? decoded) {
    if (decoded is! Map) {
      throw const FormatException('Filmsoz file has an invalid root format.');
    }

    final original = decoded.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final messages = <String>[];
    final sourceVersion = _readVersion(original['version']);

    if (sourceVersion > FilmsozAppInfo.projectFormatVersion) {
      throw FormatException(
        'Этот проект создан в более новой версии Filmsoz '
        '(формат V$sourceVersion). Обновите приложение перед открытием.',
      );
    }

    Map<String, dynamic> document;
    final rawDocument = original['document'];

    if (rawDocument is Map) {
      document = rawDocument.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    } else {
      document = Map<String, dynamic>.of(original);
      document.remove('format');
      document.remove('version');
      document.remove('savedAt');
      document.remove('project');
      messages.add('Старый документ без оболочки проекта был обновлён.');
    }

    _migrateBlocks(document, messages);

    final project = _readProjectMap(original['project']);
    final root = <String, dynamic>{
      'format': 'filmsoz',
      'version': FilmsozAppInfo.projectFormatVersion,
      'savedAt': original['savedAt']?.toString() ??
          DateTime.now().toUtc().toIso8601String(),
      'project': project,
      'document': document,
    };

    if (sourceVersion < FilmsozAppInfo.projectFormatVersion) {
      messages.add(
        'Формат проекта обновлён с версии $sourceVersion до '
        '${FilmsozAppInfo.projectFormatVersion}.',
      );
    }

    return FilmsozMigrationResult(
      root: root,
      sourceVersion: sourceVersion,
      targetVersion: FilmsozAppInfo.projectFormatVersion,
      messages: List<String>.unmodifiable(messages),
    );
  }

  int _readVersion(Object? value) {
    final parsed = value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '') ?? 1;
    return parsed < 1 ? 1 : parsed;
  }

  Map<String, dynamic> _readProjectMap(Object? value) {
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), item),
      );
    }

    return <String, dynamic>{
      'path': null,
      'name': null,
      'isDirty': false,
    };
  }

  void _migrateBlocks(
    Map<String, dynamic> document,
    List<String> messages,
  ) {
    Object? rawBlocks = document['blocks'];

    if (rawBlocks is! List) {
      rawBlocks = document['scriptBlocks'] ?? document['script'];

      if (rawBlocks is List) {
        messages.add('Старый список блоков сценария был преобразован.');
      }
    }

    if (rawBlocks is! List) {
      document['blocks'] = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'scene_1',
          'type': 'sceneHeading',
          'text': 'ИНТ. СТУДИЯ - ДЕНЬ',
        },
      ];
      messages.add('В проект добавлена стартовая сцена.');
      return;
    }

    final migrated = <Map<String, dynamic>>[];

    for (var index = 0; index < rawBlocks.length; index++) {
      final rawBlock = rawBlocks[index];

      if (rawBlock is! Map) {
        continue;
      }

      final block = rawBlock.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final id = block['id']?.toString().trim();
      final text = block['text'] ?? block['content'] ?? block['value'] ?? '';
      final rawType = block['type']?.toString() ??
          block['blockType']?.toString() ??
          'action';

      migrated.add(<String, dynamic>{
        'id': id == null || id.isEmpty ? 'migrated_block_${index + 1}' : id,
        'type': _normalizeBlockType(rawType),
        'text': text.toString(),
      });
    }

    if (migrated.isEmpty) {
      migrated.add(<String, dynamic>{
        'id': 'scene_1',
        'type': 'sceneHeading',
        'text': 'ИНТ. СТУДИЯ - ДЕНЬ',
      });
    }

    document['blocks'] = migrated;
    document.remove('scriptBlocks');
    document.remove('script');
  }

  String _normalizeBlockType(String rawType) {
    final value = rawType.trim().toLowerCase();

    return switch (value) {
      'scene' ||
      'sceneheading' ||
      'scene_heading' ||
      'heading' ||
      'slugline' =>
        'sceneHeading',
      'character' || 'charactername' || 'character_name' => 'character',
      'dialog' || 'dialogue' => 'dialogue',
      'parenthetical' || 'remark' || 'remarka' => 'parenthetical',
      'transition' => 'transition',
      _ => 'action',
    };
  }
}
