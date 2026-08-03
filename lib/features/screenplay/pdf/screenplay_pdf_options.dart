import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/document/scene_section.dart';

/// Determines which scenes are included in a PDF export.
enum ScreenplayPdfScope { entireDocument, selectedScenes }

class ScreenplayPdfOptions {
  const ScreenplayPdfOptions({
    required this.title,
    this.author = '',
    this.contact = '',
    this.draftLabel = '',
    this.includeTitlePage = true,
    this.showPageNumbers = true,
    this.showSceneNumbers = true,
    this.scope = ScreenplayPdfScope.entireDocument,
    this.selectedSceneIds = const <String>{},
    this.fontSize = 12,
    this.lineSpacing = 1,
  });

  final String title;
  final String author;
  final String contact;
  final String draftLabel;
  final bool includeTitlePage;
  final bool showPageNumbers;
  final bool showSceneNumbers;
  final ScreenplayPdfScope scope;
  final Set<String> selectedSceneIds;
  final double fontSize;

  /// Extra space between lines, measured in PDF points.
  final double lineSpacing;

  bool get exportsSelectedScenes => scope == ScreenplayPdfScope.selectedScenes;

  bool includesScene(String sceneId) {
    return !exportsSelectedScenes || selectedSceneIds.contains(sceneId);
  }

  List<SceneSection> resolveScenes(FilmDocument document) {
    return document.sceneSections
        .where((scene) => includesScene(scene.id))
        .toList(growable: false);
  }

  ScreenplayPdfOptions copyWith({
    String? title,
    String? author,
    String? contact,
    String? draftLabel,
    bool? includeTitlePage,
    bool? showPageNumbers,
    bool? showSceneNumbers,
    ScreenplayPdfScope? scope,
    Set<String>? selectedSceneIds,
    double? fontSize,
    double? lineSpacing,
  }) {
    return ScreenplayPdfOptions(
      title: title ?? this.title,
      author: author ?? this.author,
      contact: contact ?? this.contact,
      draftLabel: draftLabel ?? this.draftLabel,
      includeTitlePage: includeTitlePage ?? this.includeTitlePage,
      showPageNumbers: showPageNumbers ?? this.showPageNumbers,
      showSceneNumbers: showSceneNumbers ?? this.showSceneNumbers,
      scope: scope ?? this.scope,
      selectedSceneIds: selectedSceneIds ?? this.selectedSceneIds,
      fontSize: fontSize ?? this.fontSize,
      lineSpacing: lineSpacing ?? this.lineSpacing,
    );
  }
}
