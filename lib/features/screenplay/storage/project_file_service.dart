import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as path;

class ProjectFileService {
  const ProjectFileService();

  static const XTypeGroup _filmsozTypeGroup = XTypeGroup(
    label: 'Filmsoz project',
    extensions: <String>['filmsoz'],
  );

  static const int _recentProjectLimit = 8;
  static const String _settingsFolderName = 'Filmsoz Studio';
  static const String _recentProjectsFileName = 'recent_projects.json';

  Future<String?> chooseOpenProject() async {
    final file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[_filmsozTypeGroup],
      confirmButtonText: 'Открыть',
    );

    return file?.path;
  }

  Future<String?> chooseSaveProject({
    required String suggestedName,
  }) async {
    final cleanName = suggestedName.trim().isEmpty
        ? 'Без названия'
        : path.basenameWithoutExtension(suggestedName.trim());

    final location = await getSaveLocation(
      acceptedTypeGroups: const <XTypeGroup>[_filmsozTypeGroup],
      suggestedName: '$cleanName.filmsoz',
      confirmButtonText: 'Сохранить',
      canCreateDirectories: true,
    );

    if (location == null) {
      return null;
    }

    return _ensureFilmsozExtension(location.path);
  }

  Future<List<String>> loadRecentProjects() async {
    final file = await _getRecentProjectsFile();

    if (!await file.exists()) {
      return const <String>[];
    }

    try {
      final decoded = jsonDecode(
        await file.readAsString(encoding: utf8),
      );

      if (decoded is! List) {
        return const <String>[];
      }

      final existingPaths = <String>[];

      for (final item in decoded) {
        final projectPath = item?.toString().trim();

        if (projectPath == null || projectPath.isEmpty) {
          continue;
        }

        if (await File(projectPath).exists()) {
          existingPaths.add(projectPath);
        }
      }

      final uniquePaths = _uniquePaths(existingPaths);

      if (uniquePaths.length != decoded.length) {
        await _writeRecentProjects(uniquePaths);
      }

      return uniquePaths;
    } catch (_) {
      return const <String>[];
    }
  }

  Future<List<String>> rememberProject(String projectPath) async {
    final normalizedPath = _ensureFilmsozExtension(projectPath);
    final currentPaths = await loadRecentProjects();

    final updatedPaths = <String>[
      normalizedPath,
      ...currentPaths.where(
        (item) => !_pathsEqual(item, normalizedPath),
      ),
    ];

    final limitedPaths =
        updatedPaths.take(_recentProjectLimit).toList(growable: false);

    await _writeRecentProjects(limitedPaths);
    return limitedPaths;
  }

  String _ensureFilmsozExtension(String filePath) {
    if (filePath.toLowerCase().endsWith('.filmsoz')) {
      return filePath;
    }

    return '$filePath.filmsoz';
  }

  List<String> _uniquePaths(List<String> paths) {
    final result = <String>[];

    for (final projectPath in paths) {
      if (!result.any((item) => _pathsEqual(item, projectPath))) {
        result.add(projectPath);
      }
    }

    return result.take(_recentProjectLimit).toList(growable: false);
  }

  bool _pathsEqual(String first, String second) {
    if (Platform.isWindows) {
      return first.toLowerCase() == second.toLowerCase();
    }

    return first == second;
  }

  Future<void> _writeRecentProjects(List<String> projects) async {
    final file = await _getRecentProjectsFile();
    final jsonText = const JsonEncoder.withIndent('  ').convert(projects);

    await file.writeAsString(
      jsonText,
      encoding: utf8,
      flush: true,
    );
  }

  Future<File> _getRecentProjectsFile() async {
    final userProfile = Platform.environment['USERPROFILE'];

    Directory baseDirectory;

    if (Platform.isWindows && userProfile != null && userProfile.isNotEmpty) {
      final documentsDirectory = Directory(
        path.join(userProfile, 'Documents'),
      );

      baseDirectory = await documentsDirectory.exists()
          ? documentsDirectory
          : Directory(userProfile);
    } else {
      baseDirectory = Directory.current;
    }

    final settingsDirectory = Directory(
      path.join(baseDirectory.path, _settingsFolderName),
    );

    if (!await settingsDirectory.exists()) {
      await settingsDirectory.create(recursive: true);
    }

    return File(
      path.join(settingsDirectory.path, _recentProjectsFileName),
    );
  }
}
