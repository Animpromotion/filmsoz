enum PostSceneStatus {
  notStarted,
  editing,
  review,
  ready,
}

extension PostSceneStatusLabel on PostSceneStatus {
  String get label {
    return switch (this) {
      PostSceneStatus.notStarted => 'Не начато',
      PostSceneStatus.editing => 'В монтаже',
      PostSceneStatus.review => 'На проверке',
      PostSceneStatus.ready => 'Готово',
    };
  }
}

enum ApprovalStatus {
  pending,
  approved,
  changesRequested,
}

extension ApprovalStatusLabel on ApprovalStatus {
  String get label {
    return switch (this) {
      ApprovalStatus.pending => 'Ожидает',
      ApprovalStatus.approved => 'Утверждено',
      ApprovalStatus.changesRequested => 'Нужны правки',
    };
  }
}

class ScenePostProductionData {
  const ScenePostProductionData({
    this.status = PostSceneStatus.notStarted,
    this.progress = 0,
    this.editorNotes = '',
    this.directorNotes = '',
    this.selectedTakeIds = const <String>[],
    this.directorApproval = ApprovalStatus.pending,
    this.producerApproval = ApprovalStatus.pending,
  });

  final PostSceneStatus status;
  final int progress;
  final String editorNotes;
  final String directorNotes;
  final List<String> selectedTakeIds;
  final ApprovalStatus directorApproval;
  final ApprovalStatus producerApproval;

  bool get isDefault =>
      status == PostSceneStatus.notStarted &&
      progress == 0 &&
      editorNotes.trim().isEmpty &&
      directorNotes.trim().isEmpty &&
      selectedTakeIds.isEmpty &&
      directorApproval == ApprovalStatus.pending &&
      producerApproval == ApprovalStatus.pending;

  ScenePostProductionData copyWith({
    PostSceneStatus? status,
    int? progress,
    String? editorNotes,
    String? directorNotes,
    List<String>? selectedTakeIds,
    ApprovalStatus? directorApproval,
    ApprovalStatus? producerApproval,
  }) {
    return ScenePostProductionData(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      editorNotes: editorNotes ?? this.editorNotes,
      directorNotes: directorNotes ?? this.directorNotes,
      selectedTakeIds: selectedTakeIds ?? this.selectedTakeIds,
      directorApproval: directorApproval ?? this.directorApproval,
      producerApproval: producerApproval ?? this.producerApproval,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'status': status.name,
      'progress': progress,
      'editorNotes': editorNotes,
      'directorNotes': directorNotes,
      'selectedTakeIds': selectedTakeIds,
      'directorApproval': directorApproval.name,
      'producerApproval': producerApproval.name,
    };
  }

  factory ScenePostProductionData.fromJson(Map<String, dynamic> json) {
    return ScenePostProductionData(
      status: PostSceneStatus.values.firstWhere(
        (value) => value.name == json['status']?.toString(),
        orElse: () => PostSceneStatus.notStarted,
      ),
      progress: _readBoundedInt(json['progress'], min: 0, max: 100),
      editorNotes: json['editorNotes']?.toString() ?? '',
      directorNotes: json['directorNotes']?.toString() ?? '',
      selectedTakeIds: _readUniqueStrings(json['selectedTakeIds']),
      directorApproval: ApprovalStatus.values.firstWhere(
        (value) => value.name == json['directorApproval']?.toString(),
        orElse: () => ApprovalStatus.pending,
      ),
      producerApproval: ApprovalStatus.values.firstWhere(
        (value) => value.name == json['producerApproval']?.toString(),
        orElse: () => ApprovalStatus.pending,
      ),
    );
  }
}

class PostProductionSequence {
  const PostProductionSequence({
    required this.id,
    required this.title,
    this.sceneIds = const <String>[],
    this.notes = '',
  });

  final String id;
  final String title;
  final List<String> sceneIds;
  final String notes;

  PostProductionSequence copyWith({
    String? id,
    String? title,
    List<String>? sceneIds,
    String? notes,
  }) {
    return PostProductionSequence(
      id: id ?? this.id,
      title: title ?? this.title,
      sceneIds: sceneIds ?? this.sceneIds,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'sceneIds': sceneIds,
      'notes': notes,
    };
  }

  factory PostProductionSequence.fromJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString().trim();
    final rawTitle = json['title']?.toString().trim();

    return PostProductionSequence(
      id: rawId == null || rawId.isEmpty
          ? 'sequence_${DateTime.now().microsecondsSinceEpoch}'
          : rawId,
      title:
          rawTitle == null || rawTitle.isEmpty ? 'Монтажный эпизод' : rawTitle,
      sceneIds: _readUniqueStrings(json['sceneIds']),
      notes: json['notes']?.toString() ?? '',
    );
  }
}

class EditVersion {
  const EditVersion({
    required this.id,
    required this.title,
    this.sequenceId,
    this.versionNumber = 1,
    this.application = '',
    this.filePath = '',
    this.createdAt = '',
    this.durationSeconds = 0,
    this.notes = '',
    this.isCurrent = false,
  });

  final String id;
  final String title;
  final String? sequenceId;
  final int versionNumber;
  final String application;
  final String filePath;
  final String createdAt;
  final double durationSeconds;
  final String notes;
  final bool isCurrent;

  EditVersion copyWith({
    String? id,
    String? title,
    String? sequenceId,
    bool clearSequenceId = false,
    int? versionNumber,
    String? application,
    String? filePath,
    String? createdAt,
    double? durationSeconds,
    String? notes,
    bool? isCurrent,
  }) {
    return EditVersion(
      id: id ?? this.id,
      title: title ?? this.title,
      sequenceId: clearSequenceId ? null : sequenceId ?? this.sequenceId,
      versionNumber: versionNumber ?? this.versionNumber,
      application: application ?? this.application,
      filePath: filePath ?? this.filePath,
      createdAt: createdAt ?? this.createdAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      notes: notes ?? this.notes,
      isCurrent: isCurrent ?? this.isCurrent,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      if (sequenceId != null) 'sequenceId': sequenceId,
      'versionNumber': versionNumber,
      'application': application,
      'filePath': filePath,
      'createdAt': createdAt,
      'durationSeconds': durationSeconds,
      'notes': notes,
      'isCurrent': isCurrent,
    };
  }

  factory EditVersion.fromJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString().trim();
    final rawTitle = json['title']?.toString().trim();
    final rawSequenceId = json['sequenceId']?.toString().trim();

    return EditVersion(
      id: rawId == null || rawId.isEmpty
          ? 'version_${DateTime.now().microsecondsSinceEpoch}'
          : rawId,
      title: rawTitle == null || rawTitle.isEmpty ? 'Версия монтажа' : rawTitle,
      sequenceId:
          rawSequenceId == null || rawSequenceId.isEmpty ? null : rawSequenceId,
      versionNumber: _readPositiveInt(json['versionNumber'], fallback: 1),
      application: json['application']?.toString() ?? '',
      filePath: json['filePath']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
      durationSeconds: _readNonNegativeDouble(json['durationSeconds']),
      notes: json['notes']?.toString() ?? '',
      isCurrent: json['isCurrent'] == true,
    );
  }
}

enum PostTaskDepartment {
  editing,
  color,
  sound,
  music,
  vfx,
  titles,
  delivery,
  other,
}

extension PostTaskDepartmentLabel on PostTaskDepartment {
  String get label {
    return switch (this) {
      PostTaskDepartment.editing => 'Монтаж',
      PostTaskDepartment.color => 'Цветокоррекция',
      PostTaskDepartment.sound => 'Звук',
      PostTaskDepartment.music => 'Музыка',
      PostTaskDepartment.vfx => 'VFX',
      PostTaskDepartment.titles => 'Титры',
      PostTaskDepartment.delivery => 'Мастеринг и выдача',
      PostTaskDepartment.other => 'Другое',
    };
  }
}

enum PostTaskStatus {
  planned,
  inProgress,
  review,
  blocked,
  done,
}

extension PostTaskStatusLabel on PostTaskStatus {
  String get label {
    return switch (this) {
      PostTaskStatus.planned => 'Запланировано',
      PostTaskStatus.inProgress => 'В работе',
      PostTaskStatus.review => 'На проверке',
      PostTaskStatus.blocked => 'Заблокировано',
      PostTaskStatus.done => 'Готово',
    };
  }
}

enum PostTaskPriority {
  low,
  normal,
  high,
  urgent,
}

extension PostTaskPriorityLabel on PostTaskPriority {
  String get label {
    return switch (this) {
      PostTaskPriority.low => 'Низкий',
      PostTaskPriority.normal => 'Обычный',
      PostTaskPriority.high => 'Высокий',
      PostTaskPriority.urgent => 'Срочно',
    };
  }
}

class PostProductionTask {
  const PostProductionTask({
    required this.id,
    required this.title,
    this.department = PostTaskDepartment.editing,
    this.status = PostTaskStatus.planned,
    this.priority = PostTaskPriority.normal,
    this.assignee = '',
    this.dueDate = '',
    this.progress = 0,
    this.sceneId,
    this.versionId,
    this.notes = '',
  });

  final String id;
  final String title;
  final PostTaskDepartment department;
  final PostTaskStatus status;
  final PostTaskPriority priority;
  final String assignee;
  final String dueDate;
  final int progress;
  final String? sceneId;
  final String? versionId;
  final String notes;

  PostProductionTask copyWith({
    String? id,
    String? title,
    PostTaskDepartment? department,
    PostTaskStatus? status,
    PostTaskPriority? priority,
    String? assignee,
    String? dueDate,
    int? progress,
    String? sceneId,
    bool clearSceneId = false,
    String? versionId,
    bool clearVersionId = false,
    String? notes,
  }) {
    return PostProductionTask(
      id: id ?? this.id,
      title: title ?? this.title,
      department: department ?? this.department,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      assignee: assignee ?? this.assignee,
      dueDate: dueDate ?? this.dueDate,
      progress: progress ?? this.progress,
      sceneId: clearSceneId ? null : sceneId ?? this.sceneId,
      versionId: clearVersionId ? null : versionId ?? this.versionId,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'department': department.name,
      'status': status.name,
      'priority': priority.name,
      'assignee': assignee,
      'dueDate': dueDate,
      'progress': progress,
      if (sceneId != null) 'sceneId': sceneId,
      if (versionId != null) 'versionId': versionId,
      'notes': notes,
    };
  }

  factory PostProductionTask.fromJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString().trim();
    final rawTitle = json['title']?.toString().trim();
    final rawSceneId = json['sceneId']?.toString().trim();
    final rawVersionId = json['versionId']?.toString().trim();

    return PostProductionTask(
      id: rawId == null || rawId.isEmpty
          ? 'post_task_${DateTime.now().microsecondsSinceEpoch}'
          : rawId,
      title: rawTitle == null || rawTitle.isEmpty
          ? 'Задача постпродакшна'
          : rawTitle,
      department: PostTaskDepartment.values.firstWhere(
        (value) => value.name == json['department']?.toString(),
        orElse: () => PostTaskDepartment.editing,
      ),
      status: PostTaskStatus.values.firstWhere(
        (value) => value.name == json['status']?.toString(),
        orElse: () => PostTaskStatus.planned,
      ),
      priority: PostTaskPriority.values.firstWhere(
        (value) => value.name == json['priority']?.toString(),
        orElse: () => PostTaskPriority.normal,
      ),
      assignee: json['assignee']?.toString() ?? '',
      dueDate: json['dueDate']?.toString() ?? '',
      progress: _readBoundedInt(json['progress'], min: 0, max: 100),
      sceneId: rawSceneId == null || rawSceneId.isEmpty ? null : rawSceneId,
      versionId:
          rawVersionId == null || rawVersionId.isEmpty ? null : rawVersionId,
      notes: json['notes']?.toString() ?? '',
    );
  }
}

enum MissingMaterialType {
  missingShot,
  reshoot,
  pickup,
  audio,
  vfxPlate,
}

extension MissingMaterialTypeLabel on MissingMaterialType {
  String get label {
    return switch (this) {
      MissingMaterialType.missingShot => 'Отсутствующий кадр',
      MissingMaterialType.reshoot => 'Пересъёмка',
      MissingMaterialType.pickup => 'Досъёмка',
      MissingMaterialType.audio => 'Дополнительный звук',
      MissingMaterialType.vfxPlate => 'VFX-плейт',
    };
  }
}

enum MissingMaterialStatus {
  open,
  scheduled,
  completed,
  cancelled,
}

extension MissingMaterialStatusLabel on MissingMaterialStatus {
  String get label {
    return switch (this) {
      MissingMaterialStatus.open => 'Открыто',
      MissingMaterialStatus.scheduled => 'Запланировано',
      MissingMaterialStatus.completed => 'Выполнено',
      MissingMaterialStatus.cancelled => 'Отменено',
    };
  }
}

class MissingMaterialItem {
  const MissingMaterialItem({
    required this.id,
    required this.title,
    this.type = MissingMaterialType.missingShot,
    this.status = MissingMaterialStatus.open,
    this.sceneId,
    this.shotId,
    this.description = '',
    this.scheduledDate = '',
    this.assignee = '',
  });

  final String id;
  final String title;
  final MissingMaterialType type;
  final MissingMaterialStatus status;
  final String? sceneId;
  final String? shotId;
  final String description;
  final String scheduledDate;
  final String assignee;

  MissingMaterialItem copyWith({
    String? id,
    String? title,
    MissingMaterialType? type,
    MissingMaterialStatus? status,
    String? sceneId,
    bool clearSceneId = false,
    String? shotId,
    bool clearShotId = false,
    String? description,
    String? scheduledDate,
    String? assignee,
  }) {
    return MissingMaterialItem(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      status: status ?? this.status,
      sceneId: clearSceneId ? null : sceneId ?? this.sceneId,
      shotId: clearShotId ? null : shotId ?? this.shotId,
      description: description ?? this.description,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      assignee: assignee ?? this.assignee,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'type': type.name,
      'status': status.name,
      if (sceneId != null) 'sceneId': sceneId,
      if (shotId != null) 'shotId': shotId,
      'description': description,
      'scheduledDate': scheduledDate,
      'assignee': assignee,
    };
  }

  factory MissingMaterialItem.fromJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString().trim();
    final rawTitle = json['title']?.toString().trim();
    final rawSceneId = json['sceneId']?.toString().trim();
    final rawShotId = json['shotId']?.toString().trim();

    return MissingMaterialItem(
      id: rawId == null || rawId.isEmpty
          ? 'missing_${DateTime.now().microsecondsSinceEpoch}'
          : rawId,
      title: rawTitle == null || rawTitle.isEmpty
          ? 'Отсутствующий материал'
          : rawTitle,
      type: MissingMaterialType.values.firstWhere(
        (value) => value.name == json['type']?.toString(),
        orElse: () => MissingMaterialType.missingShot,
      ),
      status: MissingMaterialStatus.values.firstWhere(
        (value) => value.name == json['status']?.toString(),
        orElse: () => MissingMaterialStatus.open,
      ),
      sceneId: rawSceneId == null || rawSceneId.isEmpty ? null : rawSceneId,
      shotId: rawShotId == null || rawShotId.isEmpty ? null : rawShotId,
      description: json['description']?.toString() ?? '',
      scheduledDate: json['scheduledDate']?.toString() ?? '',
      assignee: json['assignee']?.toString() ?? '',
    );
  }
}

List<String> normalizePostProductionStrings(Iterable<String> values) {
  final result = <String>[];
  final seen = <String>{};

  for (final value in values) {
    final text = value.trim();

    if (text.isEmpty || !seen.add(text)) {
      continue;
    }

    result.add(text);
  }

  return result;
}

List<String> _readUniqueStrings(Object? value) {
  if (value is! List) {
    return const <String>[];
  }

  return normalizePostProductionStrings(
    value.map((item) => item?.toString() ?? ''),
  );
}

int _readBoundedInt(
  Object? value, {
  required int min,
  required int max,
}) {
  final parsed = switch (value) {
    num number => number.toInt(),
    _ => int.tryParse(value?.toString() ?? '') ?? min,
  };

  return parsed.clamp(min, max).toInt();
}

int _readPositiveInt(Object? value, {required int fallback}) {
  final parsed = switch (value) {
    num number => number.toInt(),
    _ => int.tryParse(value?.toString() ?? '') ?? fallback,
  };

  return parsed <= 0 ? fallback : parsed;
}

double _readNonNegativeDouble(Object? value) {
  final parsed = switch (value) {
    num number => number.toDouble(),
    _ => double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0,
  };

  return parsed < 0 ? 0.0 : parsed;
}
