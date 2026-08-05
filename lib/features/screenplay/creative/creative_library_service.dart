import 'package:filmsoz_studio/features/screenplay/creative/creative_material.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/productivity/screenplay_productivity_service.dart';

class CreativeLibraryFilter {
  const CreativeLibraryFilter({
    this.query = '',
    this.type,
    this.folder,
    this.tag,
    this.sceneId,
    this.characterName,
    this.onlyUnused = false,
  });

  final String query;
  final CreativeMaterialType? type;
  final String? folder;
  final String? tag;
  final String? sceneId;
  final String? characterName;
  final bool onlyUnused;
}

class CreativeLibraryService {
  const CreativeLibraryService();

  List<CreativeMaterial> filter(
    Iterable<CreativeMaterial> materials,
    CreativeLibraryFilter filter,
  ) {
    final query = filter.query.trim().toLowerCase();

    final result = materials.where((material) {
      if (query.isNotEmpty && !material.searchableText.contains(query)) {
        return false;
      }

      if (filter.type != null && material.type != filter.type) {
        return false;
      }

      if (filter.folder != null && material.folder != filter.folder) {
        return false;
      }

      if (filter.tag != null && !material.tags.contains(filter.tag)) {
        return false;
      }

      if (filter.sceneId != null &&
          !material.linkedSceneIds.contains(filter.sceneId)) {
        return false;
      }

      if (filter.characterName != null &&
          !material.linkedCharacterNames.contains(filter.characterName)) {
        return false;
      }

      if (filter.onlyUnused && material.usedBlockIds.isNotEmpty) {
        return false;
      }

      return true;
    }).toList(growable: false);

    result.sort((first, second) {
      final firstTime = DateTime.tryParse(first.updatedAt);
      final secondTime = DateTime.tryParse(second.updatedAt);

      if (firstTime == null || secondTime == null) {
        return second.updatedAt.compareTo(first.updatedAt);
      }

      return secondTime.compareTo(firstTime);
    });

    return result;
  }

  List<String> folders(Iterable<CreativeMaterial> materials) {
    final folders = materials
        .map((material) => material.folder.trim())
        .where((folder) => folder.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();
    return folders;
  }

  List<String> tags(Iterable<CreativeMaterial> materials) {
    final tags = materials
        .expand((material) => material.tags)
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();
    return tags;
  }

  List<String> characterNames(FilmDocument document) {
    return const ScreenplayProductivityService()
        .characterStatistics(document)
        .map((item) => item.name)
        .toList(growable: false);
  }

  String insertionText(CreativeMaterial material) {
    final title = material.title.trim();
    final body = material.body.trim();
    final source = material.source.trim();
    final url = material.url.trim();

    return switch (material.type) {
      CreativeMaterialType.quote => <String>[
          if (body.isNotEmpty) '«$body»' else title,
          if (source.isNotEmpty) '— $source',
        ].join('\n'),
      CreativeMaterialType.link => <String>[
          title,
          if (body.isNotEmpty) body,
          if (url.isNotEmpty) url,
        ].where((item) => item.isNotEmpty).join('\n'),
      CreativeMaterialType.image => <String>[
          title,
          if (body.isNotEmpty) body,
          if (source.isNotEmpty) 'Источник: $source',
        ].where((item) => item.isNotEmpty).join('\n'),
      CreativeMaterialType.idea ||
      CreativeMaterialType.research ||
      CreativeMaterialType.character ||
      CreativeMaterialType.location ||
      CreativeMaterialType.unusedScene =>
        <String>[
          if (title.isNotEmpty) title,
          if (body.isNotEmpty) body,
          if (source.isNotEmpty) 'Источник: $source',
          if (url.isNotEmpty) url,
        ].where((item) => item.isNotEmpty).join('\n'),
    };
  }
}
