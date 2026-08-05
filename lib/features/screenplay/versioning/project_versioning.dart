enum CollaborationTargetType {
  project,
  scene,
  shot,
  take,
  task,
}

extension CollaborationTargetTypeLabel on CollaborationTargetType {
  String get label {
    return switch (this) {
      CollaborationTargetType.project => 'Проект',
      CollaborationTargetType.scene => 'Сцена',
      CollaborationTargetType.shot => 'Кадр',
      CollaborationTargetType.take => 'Дубль',
      CollaborationTargetType.task => 'Задача',
    };
  }
}

enum CollaborationCommentStatus {
  open,
  inProgress,
  resolved,
}

extension CollaborationCommentStatusLabel on CollaborationCommentStatus {
  String get label {
    return switch (this) {
      CollaborationCommentStatus.open => 'Открыт',
      CollaborationCommentStatus.inProgress => 'В работе',
      CollaborationCommentStatus.resolved => 'Решён',
    };
  }
}

class ProjectMember {
  const ProjectMember({
    required this.id,
    required this.name,
    this.role = '',
    this.email = '',
    this.notes = '',
    this.isActive = true,
  });

  final String id;
  final String name;
  final String role;
  final String email;
  final String notes;
  final bool isActive;

  ProjectMember copyWith({
    String? id,
    String? name,
    String? role,
    String? email,
    String? notes,
    bool? isActive,
  }) {
    return ProjectMember(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      email: email ?? this.email,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'role': role,
      'email': email,
      'notes': notes,
      'isActive': isActive,
    };
  }

  factory ProjectMember.fromJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString().trim();
    final rawName = json['name']?.toString().trim();

    return ProjectMember(
      id: rawId == null || rawId.isEmpty
          ? 'member_${DateTime.now().microsecondsSinceEpoch}'
          : rawId,
      name: rawName == null || rawName.isEmpty ? 'Участник' : rawName,
      role: json['role']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      isActive: json['isActive'] != false,
    );
  }
}

class CollaborationComment {
  const CollaborationComment({
    required this.id,
    required this.text,
    this.targetType = CollaborationTargetType.project,
    this.targetId,
    this.authorId,
    this.assigneeId,
    this.status = CollaborationCommentStatus.open,
    this.dueDate = '',
    this.createdAt = '',
    this.updatedAt = '',
  });

  final String id;
  final String text;
  final CollaborationTargetType targetType;
  final String? targetId;
  final String? authorId;
  final String? assigneeId;
  final CollaborationCommentStatus status;
  final String dueDate;
  final String createdAt;
  final String updatedAt;

  bool get isResolved => status == CollaborationCommentStatus.resolved;

  bool isOverdue({DateTime? now}) {
    if (isResolved || dueDate.trim().isEmpty) {
      return false;
    }

    final parsed = DateTime.tryParse(dueDate.trim());

    if (parsed == null) {
      return false;
    }

    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final deadline = DateTime(parsed.year, parsed.month, parsed.day);
    return deadline.isBefore(today);
  }

  CollaborationComment copyWith({
    String? id,
    String? text,
    CollaborationTargetType? targetType,
    String? targetId,
    bool clearTargetId = false,
    String? authorId,
    bool clearAuthorId = false,
    String? assigneeId,
    bool clearAssigneeId = false,
    CollaborationCommentStatus? status,
    String? dueDate,
    String? createdAt,
    String? updatedAt,
  }) {
    return CollaborationComment(
      id: id ?? this.id,
      text: text ?? this.text,
      targetType: targetType ?? this.targetType,
      targetId: clearTargetId ? null : targetId ?? this.targetId,
      authorId: clearAuthorId ? null : authorId ?? this.authorId,
      assigneeId: clearAssigneeId ? null : assigneeId ?? this.assigneeId,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'text': text,
      'targetType': targetType.name,
      if (targetId != null) 'targetId': targetId,
      if (authorId != null) 'authorId': authorId,
      if (assigneeId != null) 'assigneeId': assigneeId,
      'status': status.name,
      'dueDate': dueDate,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory CollaborationComment.fromJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString().trim();
    final rawTargetId = json['targetId']?.toString().trim();
    final rawAuthorId = json['authorId']?.toString().trim();
    final rawAssigneeId = json['assigneeId']?.toString().trim();

    return CollaborationComment(
      id: rawId == null || rawId.isEmpty
          ? 'comment_${DateTime.now().microsecondsSinceEpoch}'
          : rawId,
      text: json['text']?.toString() ?? '',
      targetType: CollaborationTargetType.values.firstWhere(
        (value) => value.name == json['targetType']?.toString(),
        orElse: () => CollaborationTargetType.project,
      ),
      targetId: rawTargetId == null || rawTargetId.isEmpty ? null : rawTargetId,
      authorId: rawAuthorId == null || rawAuthorId.isEmpty ? null : rawAuthorId,
      assigneeId:
          rawAssigneeId == null || rawAssigneeId.isEmpty ? null : rawAssigneeId,
      status: CollaborationCommentStatus.values.firstWhere(
        (value) => value.name == json['status']?.toString(),
        orElse: () => CollaborationCommentStatus.open,
      ),
      dueDate: json['dueDate']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString() ?? '',
    );
  }
}

class ProjectChangeEntry {
  const ProjectChangeEntry({
    required this.id,
    required this.summary,
    this.details = '',
    this.actorId,
    this.createdAt = '',
  });

  final String id;
  final String summary;
  final String details;
  final String? actorId;
  final String createdAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'summary': summary,
      'details': details,
      if (actorId != null) 'actorId': actorId,
      'createdAt': createdAt,
    };
  }

  factory ProjectChangeEntry.fromJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString().trim();
    final rawActorId = json['actorId']?.toString().trim();

    return ProjectChangeEntry(
      id: rawId == null || rawId.isEmpty
          ? 'change_${DateTime.now().microsecondsSinceEpoch}'
          : rawId,
      summary: json['summary']?.toString() ?? '',
      details: json['details']?.toString() ?? '',
      actorId: rawActorId == null || rawActorId.isEmpty ? null : rawActorId,
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

class ProjectCheckpoint {
  const ProjectCheckpoint({
    required this.id,
    required this.name,
    required this.snapshot,
    this.note = '',
    this.authorId,
    this.createdAt = '',
  });

  final String id;
  final String name;
  final String note;
  final String? authorId;
  final String createdAt;
  final Map<String, dynamic> snapshot;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'note': note,
      if (authorId != null) 'authorId': authorId,
      'createdAt': createdAt,
      'snapshot': snapshot,
    };
  }

  factory ProjectCheckpoint.fromJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString().trim();
    final rawName = json['name']?.toString().trim();
    final rawAuthorId = json['authorId']?.toString().trim();
    final rawSnapshot = json['snapshot'];
    final snapshot = <String, dynamic>{};

    if (rawSnapshot is Map) {
      snapshot.addAll(
        rawSnapshot.map(
          (key, value) => MapEntry(key.toString(), value),
        ),
      );
    }

    return ProjectCheckpoint(
      id: rawId == null || rawId.isEmpty
          ? 'checkpoint_${DateTime.now().microsecondsSinceEpoch}'
          : rawId,
      name: rawName == null || rawName.isEmpty ? 'Контрольная версия' : rawName,
      note: json['note']?.toString() ?? '',
      authorId: rawAuthorId == null || rawAuthorId.isEmpty ? null : rawAuthorId,
      createdAt: json['createdAt']?.toString() ?? '',
      snapshot: snapshot,
    );
  }
}

class ProjectVersioningSettings {
  const ProjectVersioningSettings({
    this.autoBackupMinutes = 10,
    this.maxAutomaticBackups = 20,
    this.teamPackageBaseFingerprint = '',
  });

  final int autoBackupMinutes;
  final int maxAutomaticBackups;
  final String teamPackageBaseFingerprint;

  ProjectVersioningSettings copyWith({
    int? autoBackupMinutes,
    int? maxAutomaticBackups,
    String? teamPackageBaseFingerprint,
  }) {
    return ProjectVersioningSettings(
      autoBackupMinutes: _clampInt(
        autoBackupMinutes ?? this.autoBackupMinutes,
        min: 1,
        max: 1440,
      ),
      maxAutomaticBackups: _clampInt(
        maxAutomaticBackups ?? this.maxAutomaticBackups,
        min: 1,
        max: 100,
      ),
      teamPackageBaseFingerprint:
          teamPackageBaseFingerprint ?? this.teamPackageBaseFingerprint,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'autoBackupMinutes': autoBackupMinutes,
      'maxAutomaticBackups': maxAutomaticBackups,
      'teamPackageBaseFingerprint': teamPackageBaseFingerprint,
    };
  }

  factory ProjectVersioningSettings.fromJson(Map<String, dynamic> json) {
    return ProjectVersioningSettings(
      autoBackupMinutes: _clampInt(
        _readInt(json['autoBackupMinutes'], fallback: 10),
        min: 1,
        max: 1440,
      ),
      maxAutomaticBackups: _clampInt(
        _readInt(json['maxAutomaticBackups'], fallback: 20),
        min: 1,
        max: 100,
      ),
      teamPackageBaseFingerprint:
          json['teamPackageBaseFingerprint']?.toString() ?? '',
    );
  }
}

int _readInt(Object? value, {required int fallback}) {
  if (value is int) {
    return value;
  }

  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int _clampInt(int value, {required int min, required int max}) {
  if (value < min) {
    return min;
  }

  if (value > max) {
    return max;
  }

  return value;
}
