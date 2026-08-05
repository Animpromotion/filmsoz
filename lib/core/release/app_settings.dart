class FilmsozAppSettings {
  const FilmsozAppSettings({
    this.autosaveSeconds = 30,
    this.projectsDirectory = '',
    this.backupsDirectory = '',
    this.recoveryEnabled = true,
    this.showEditorHints = true,
    this.compactToolbar = false,
    this.maxErrorLogFiles = 14,
    this.maxProjectCheckpoints = 30,
  });

  final int autosaveSeconds;
  final String projectsDirectory;
  final String backupsDirectory;
  final bool recoveryEnabled;
  final bool showEditorHints;
  final bool compactToolbar;
  final int maxErrorLogFiles;
  final int maxProjectCheckpoints;

  FilmsozAppSettings normalized() {
    return FilmsozAppSettings(
      autosaveSeconds: autosaveSeconds.clamp(5, 600).toInt(),
      projectsDirectory: projectsDirectory.trim(),
      backupsDirectory: backupsDirectory.trim(),
      recoveryEnabled: recoveryEnabled,
      showEditorHints: showEditorHints,
      compactToolbar: compactToolbar,
      maxErrorLogFiles: maxErrorLogFiles.clamp(1, 90).toInt(),
      maxProjectCheckpoints: maxProjectCheckpoints.clamp(1, 100).toInt(),
    );
  }

  FilmsozAppSettings copyWith({
    int? autosaveSeconds,
    String? projectsDirectory,
    String? backupsDirectory,
    bool? recoveryEnabled,
    bool? showEditorHints,
    bool? compactToolbar,
    int? maxErrorLogFiles,
    int? maxProjectCheckpoints,
  }) {
    return FilmsozAppSettings(
      autosaveSeconds: autosaveSeconds ?? this.autosaveSeconds,
      projectsDirectory: projectsDirectory ?? this.projectsDirectory,
      backupsDirectory: backupsDirectory ?? this.backupsDirectory,
      recoveryEnabled: recoveryEnabled ?? this.recoveryEnabled,
      showEditorHints: showEditorHints ?? this.showEditorHints,
      compactToolbar: compactToolbar ?? this.compactToolbar,
      maxErrorLogFiles: maxErrorLogFiles ?? this.maxErrorLogFiles,
      maxProjectCheckpoints:
          maxProjectCheckpoints ?? this.maxProjectCheckpoints,
    ).normalized();
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'autosaveSeconds': autosaveSeconds,
      'projectsDirectory': projectsDirectory,
      'backupsDirectory': backupsDirectory,
      'recoveryEnabled': recoveryEnabled,
      'showEditorHints': showEditorHints,
      'compactToolbar': compactToolbar,
      'maxErrorLogFiles': maxErrorLogFiles,
      'maxProjectCheckpoints': maxProjectCheckpoints,
    };
  }

  factory FilmsozAppSettings.fromJson(Map<String, dynamic> json) {
    int readInt(String key, int fallback) {
      final value = json[key];

      if (value is num) {
        return value.toInt();
      }

      return int.tryParse(value?.toString() ?? '') ?? fallback;
    }

    return FilmsozAppSettings(
      autosaveSeconds: readInt('autosaveSeconds', 30),
      projectsDirectory: json['projectsDirectory']?.toString() ?? '',
      backupsDirectory: json['backupsDirectory']?.toString() ?? '',
      recoveryEnabled: json['recoveryEnabled'] != false,
      showEditorHints: json['showEditorHints'] != false,
      compactToolbar: json['compactToolbar'] == true,
      maxErrorLogFiles: readInt('maxErrorLogFiles', 14),
      maxProjectCheckpoints: readInt('maxProjectCheckpoints', 30),
    ).normalized();
  }
}
