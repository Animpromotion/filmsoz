import 'dart:convert';
import 'dart:io';

import 'package:filmsoz_studio/core/release/app_settings.dart';
import 'package:path/path.dart' as path;

class FilmsozAppSettingsService {
  const FilmsozAppSettingsService({this.rootDirectoryPath});

  final String? rootDirectoryPath;

  static const String _settingsFileName = 'app_settings.json';

  Future<FilmsozAppSettings> load() async {
    final file = await settingsFile();

    if (!await file.exists()) {
      return const FilmsozAppSettings();
    }

    try {
      final decoded = jsonDecode(await file.readAsString(encoding: utf8));

      if (decoded is! Map) {
        return const FilmsozAppSettings();
      }

      return FilmsozAppSettings.fromJson(
        decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        ),
      );
    } catch (_) {
      return const FilmsozAppSettings();
    }
  }

  Future<void> save(FilmsozAppSettings settings) async {
    final file = await settingsFile();
    final temporaryFile = File('${file.path}.tmp');
    final text = const JsonEncoder.withIndent('  ').convert(
      settings.normalized().toJson(),
    );

    await temporaryFile.writeAsString(
      text,
      encoding: utf8,
      flush: true,
    );

    if (await file.exists()) {
      await file.delete();
    }

    await temporaryFile.rename(file.path);
  }

  Future<File> settingsFile() async {
    final directory = await applicationDirectory();
    return File(path.join(directory.path, _settingsFileName));
  }

  Future<Directory> applicationDirectory() async {
    final configuredRoot = rootDirectoryPath?.trim();

    if (configuredRoot != null && configuredRoot.isNotEmpty) {
      final directory = Directory(configuredRoot);

      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      return directory;
    }

    final userProfile = Platform.environment['USERPROFILE'];
    Directory baseDirectory;

    if (Platform.isWindows && userProfile != null && userProfile.isNotEmpty) {
      final documents = Directory(path.join(userProfile, 'Documents'));
      baseDirectory =
          await documents.exists() ? documents : Directory(userProfile);
    } else {
      baseDirectory = Directory.current;
    }

    final directory = Directory(
      path.join(baseDirectory.path, 'Filmsoz Studio'),
    );

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return directory;
  }
}
