import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:path/path.dart' as p;

class AutomaticBackupEntry {
  const AutomaticBackupEntry({
    required this.path,
    required this.createdAt,
    required this.sizeBytes,
  });

  final String path;
  final DateTime createdAt;
  final int sizeBytes;

  String get fileName => p.basename(path);
}

class TeamPackageImport {
  const TeamPackageImport({
    required this.packageId,
    required this.projectName,
    required this.exportedAt,
    required this.baseFingerprint,
    required this.documentFingerprint,
    required this.document,
    this.exportedForMemberId,
  });

  final String packageId;
  final String projectName;
  final DateTime exportedAt;
  final String baseFingerprint;
  final String documentFingerprint;
  final FilmDocument document;
  final String? exportedForMemberId;

  bool conflictsWith(FilmDocument currentDocument) {
    return baseFingerprint !=
        ProjectVersioningFileService.fingerprint(currentDocument);
  }
}

class ProjectVersioningFileService {
  const ProjectVersioningFileService({this.rootDirectoryPath});

  final String? rootDirectoryPath;

  static const XTypeGroup _teamPackageTypeGroup = XTypeGroup(
    label: 'Filmsoz team package',
    extensions: <String>['filmsozpack'],
  );

  static String fingerprint(FilmDocument document) {
    final canonical = document.toJson(includeCheckpoints: false);
    canonical.remove('projectChangeLog');
    final rawSettings = canonical['versioningSettings'];
    if (rawSettings is Map) {
      rawSettings.remove('teamPackageBaseFingerprint');
    }
    final jsonText = jsonEncode(canonical);
    var hash = 0x811C9DC5;

    for (final codeUnit in jsonText.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }

    return hash.toRadixString(16).padLeft(8, '0');
  }

  Future<String> createAutomaticBackup({
    required FilmDocument document,
    required String projectName,
    String? projectPath,
    required int maxBackups,
    DateTime? now,
  }) async {
    final timestamp = (now ?? DateTime.now()).toUtc();
    final backupDirectory = await _backupDirectory(projectName);
    final fileName = '${_timestampForFile(timestamp)}.filmsoz';
    final target = File(p.join(backupDirectory.path, fileName));
    final payload = <String, dynamic>{
      'format': 'filmsoz-backup',
      'version': 1,
      'createdAt': timestamp.toIso8601String(),
      'projectName': projectName,
      if (projectPath != null) 'projectPath': projectPath,
      'fingerprint': fingerprint(document),
      'document': document.toJson(),
    };

    await target.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      encoding: utf8,
      flush: true,
    );
    await pruneAutomaticBackups(
      projectName: projectName,
      maxBackups: maxBackups,
    );
    return target.path;
  }

  Future<List<AutomaticBackupEntry>> listAutomaticBackups({
    required String projectName,
  }) async {
    final directory = await _backupDirectory(projectName);
    final result = <AutomaticBackupEntry>[];

    await for (final entity in directory.list()) {
      if (entity is! File || !entity.path.toLowerCase().endsWith('.filmsoz')) {
        continue;
      }

      final stat = await entity.stat();
      result.add(
        AutomaticBackupEntry(
          path: entity.path,
          createdAt: stat.modified,
          sizeBytes: stat.size,
        ),
      );
    }

    result.sort((first, second) {
      final byFileName = second.fileName.compareTo(first.fileName);
      return byFileName != 0
          ? byFileName
          : second.createdAt.compareTo(first.createdAt);
    });
    return result;
  }

  Future<void> pruneAutomaticBackups({
    required String projectName,
    required int maxBackups,
  }) async {
    final backups = await listAutomaticBackups(projectName: projectName);
    final safeLimit = maxBackups.clamp(1, 100).toInt();

    for (final backup in backups.skip(safeLimit)) {
      final file = File(backup.path);

      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<FilmDocument> loadAutomaticBackup(String filePath) async {
    final file = File(filePath);

    if (!await file.exists()) {
      throw FileSystemException('Резервная копия не найдена.', filePath);
    }

    final decoded = jsonDecode(await file.readAsString(encoding: utf8));

    if (decoded is! Map) {
      throw const FormatException('Некорректная резервная копия Filmsoz.');
    }

    final root = decoded.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final rawDocument = root['document'];

    if (rawDocument is! Map) {
      throw const FormatException('В резервной копии нет документа.');
    }

    return FilmDocument.fromJson(
      rawDocument.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
    );
  }

  Future<void> deleteAutomaticBackup(String filePath) async {
    final file = File(filePath);

    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<String?> chooseExportTeamPackage({
    required String projectName,
  }) async {
    final location = await getSaveLocation(
      acceptedTypeGroups: const <XTypeGroup>[_teamPackageTypeGroup],
      suggestedName: '${_cleanName(projectName)}_team.filmsozpack',
      confirmButtonText: 'Экспортировать',
      canCreateDirectories: true,
    );

    if (location == null) {
      return null;
    }

    return _ensurePackageExtension(location.path);
  }

  Future<String?> chooseImportTeamPackage() async {
    final file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[_teamPackageTypeGroup],
      confirmButtonText: 'Импортировать',
    );

    return file?.path;
  }

  Future<String> writeTeamPackage({
    required String filePath,
    required FilmDocument document,
    required String projectName,
    String? exportedForMemberId,
    String? baseFingerprint,
    DateTime? exportedAt,
  }) async {
    final targetPath = _ensurePackageExtension(filePath);
    final file = File(targetPath);
    await file.parent.create(recursive: true);

    final timestamp = (exportedAt ?? DateTime.now()).toUtc();
    final documentFingerprint = fingerprint(document);
    final packageId = 'package_${timestamp.microsecondsSinceEpoch}';
    final payload = <String, dynamic>{
      'format': 'filmsoz-team-package',
      'version': 1,
      'packageId': packageId,
      'projectName': projectName,
      'exportedAt': timestamp.toIso8601String(),
      'baseFingerprint': baseFingerprint == null || baseFingerprint.isEmpty
          ? documentFingerprint
          : baseFingerprint,
      'documentFingerprint': documentFingerprint,
      if (exportedForMemberId != null)
        'exportedForMemberId': exportedForMemberId,
      'document': document.toJson(),
    };

    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      encoding: utf8,
      flush: true,
    );
    return file.path;
  }

  Future<TeamPackageImport> readTeamPackage(String filePath) async {
    final file = File(filePath);

    if (!await file.exists()) {
      throw FileSystemException('Командный пакет не найден.', filePath);
    }

    final decoded = jsonDecode(await file.readAsString(encoding: utf8));

    if (decoded is! Map) {
      throw const FormatException('Некорректный командный пакет Filmsoz.');
    }

    final root = decoded.map(
      (key, value) => MapEntry(key.toString(), value),
    );

    if (root['format']?.toString() != 'filmsoz-team-package') {
      throw const FormatException('Файл не является командным пакетом.');
    }

    final rawDocument = root['document'];

    if (rawDocument is! Map) {
      throw const FormatException('В командном пакете нет документа.');
    }

    final document = FilmDocument.fromJson(
      rawDocument.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
    );
    final exportedAt = DateTime.tryParse(
          root['exportedAt']?.toString() ?? '',
        ) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final rawMemberId = root['exportedForMemberId']?.toString().trim();

    return TeamPackageImport(
      packageId: root['packageId']?.toString() ?? '',
      projectName: root['projectName']?.toString() ?? 'Filmsoz project',
      exportedAt: exportedAt,
      baseFingerprint: root['baseFingerprint']?.toString() ?? '',
      documentFingerprint:
          root['documentFingerprint']?.toString() ?? fingerprint(document),
      exportedForMemberId:
          rawMemberId == null || rawMemberId.isEmpty ? null : rawMemberId,
      document: document,
    );
  }

  Future<Directory> _backupDirectory(String projectName) async {
    final root = await _filmsozDirectory();
    final directory = Directory(
      p.join(root.path, 'Backups', _cleanName(projectName)),
    );

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return directory;
  }

  Future<Directory> _filmsozDirectory() async {
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
      final documents = Directory(p.join(userProfile, 'Documents'));
      baseDirectory =
          await documents.exists() ? documents : Directory(userProfile);
    } else {
      baseDirectory = Directory.current;
    }

    final directory = Directory(p.join(baseDirectory.path, 'Filmsoz Studio'));

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return directory;
  }

  String _timestampForFile(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}${two(value.month)}${two(value.day)}_'
        '${two(value.hour)}${two(value.minute)}${two(value.second)}_'
        '${value.millisecond.toString().padLeft(3, '0')}';
  }

  String _ensurePackageExtension(String filePath) {
    return filePath.toLowerCase().endsWith('.filmsozpack')
        ? filePath
        : '$filePath.filmsozpack';
  }

  String _cleanName(String value) {
    final baseName = p.basenameWithoutExtension(value.trim());
    final resolved = baseName.isEmpty ? 'filmsoz_project' : baseName;
    return resolved.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  }
}
