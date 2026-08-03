enum SceneWorkStatus {
  draft,
  inProgress,
  revise,
  ready,
}

extension SceneWorkStatusLabel on SceneWorkStatus {
  String get label {
    return switch (this) {
      SceneWorkStatus.draft => 'Черновик',
      SceneWorkStatus.inProgress => 'В работе',
      SceneWorkStatus.revise => 'Переработать',
      SceneWorkStatus.ready => 'Готово',
    };
  }
}

enum SceneColorTag {
  none,
  red,
  orange,
  yellow,
  green,
  blue,
  purple,
}

extension SceneColorTagLabel on SceneColorTag {
  String get label {
    return switch (this) {
      SceneColorTag.none => 'Без метки',
      SceneColorTag.red => 'Красная линия',
      SceneColorTag.orange => 'Оранжевая линия',
      SceneColorTag.yellow => 'Жёлтая линия',
      SceneColorTag.green => 'Зелёная линия',
      SceneColorTag.blue => 'Синяя линия',
      SceneColorTag.purple => 'Фиолетовая линия',
    };
  }
}

class SceneDevelopmentData {
  const SceneDevelopmentData({
    this.summary = '',
    this.status = SceneWorkStatus.draft,
    this.colorTag = SceneColorTag.none,
  });

  final String summary;
  final SceneWorkStatus status;
  final SceneColorTag colorTag;

  SceneDevelopmentData copyWith({
    String? summary,
    SceneWorkStatus? status,
    SceneColorTag? colorTag,
  }) {
    return SceneDevelopmentData(
      summary: summary ?? this.summary,
      status: status ?? this.status,
      colorTag: colorTag ?? this.colorTag,
    );
  }

  bool get isDefault =>
      summary.trim().isEmpty &&
      status == SceneWorkStatus.draft &&
      colorTag == SceneColorTag.none;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'summary': summary,
      'status': status.name,
      'colorTag': colorTag.name,
    };
  }

  factory SceneDevelopmentData.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status']?.toString();
    final rawColorTag = json['colorTag']?.toString();

    return SceneDevelopmentData(
      summary: json['summary']?.toString() ?? '',
      status: SceneWorkStatus.values.firstWhere(
        (value) => value.name == rawStatus,
        orElse: () => SceneWorkStatus.draft,
      ),
      colorTag: SceneColorTag.values.firstWhere(
        (value) => value.name == rawColorTag,
        orElse: () => SceneColorTag.none,
      ),
    );
  }
}

class ScreenplayGoals {
  const ScreenplayGoals({
    this.targetSceneCount = 0,
    this.targetPageCount = 0,
    this.targetMinutes = 0,
  });

  final int targetSceneCount;
  final int targetPageCount;
  final int targetMinutes;

  ScreenplayGoals copyWith({
    int? targetSceneCount,
    int? targetPageCount,
    int? targetMinutes,
  }) {
    return ScreenplayGoals(
      targetSceneCount: targetSceneCount ?? this.targetSceneCount,
      targetPageCount: targetPageCount ?? this.targetPageCount,
      targetMinutes: targetMinutes ?? this.targetMinutes,
    );
  }

  bool get isEmpty =>
      targetSceneCount <= 0 && targetPageCount <= 0 && targetMinutes <= 0;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'targetSceneCount': targetSceneCount,
      'targetPageCount': targetPageCount,
      'targetMinutes': targetMinutes,
    };
  }

  factory ScreenplayGoals.fromJson(Map<String, dynamic> json) {
    return ScreenplayGoals(
      targetSceneCount: _readNonNegativeInt(json['targetSceneCount']),
      targetPageCount: _readNonNegativeInt(json['targetPageCount']),
      targetMinutes: _readNonNegativeInt(json['targetMinutes']),
    );
  }

  static int _readNonNegativeInt(Object? value) {
    final parsed = switch (value) {
      int number => number,
      num number => number.toInt(),
      _ => int.tryParse(value?.toString() ?? '') ?? 0,
    };

    return parsed < 0 ? 0 : parsed;
  }
}
