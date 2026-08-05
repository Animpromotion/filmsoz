import 'dart:convert';
import 'dart:typed_data';

enum ShotTakeStatus {
  planned,
  recorded,
  rejected,
  selected,
}

extension ShotTakeStatusLabel on ShotTakeStatus {
  String get label {
    return switch (this) {
      ShotTakeStatus.planned => 'Запланирован',
      ShotTakeStatus.recorded => 'Снят',
      ShotTakeStatus.rejected => 'Брак',
      ShotTakeStatus.selected => 'Выбран',
    };
  }
}

class ContinuityPhoto {
  const ContinuityPhoto({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.base64Data,
    this.note = '',
  });

  final String id;
  final String fileName;
  final String mimeType;
  final String base64Data;
  final String note;

  Uint8List? get bytes {
    if (base64Data.trim().isEmpty) {
      return null;
    }

    try {
      return base64Decode(base64Data);
    } on FormatException {
      return null;
    }
  }

  ContinuityPhoto copyWith({
    String? id,
    String? fileName,
    String? mimeType,
    String? base64Data,
    String? note,
  }) {
    return ContinuityPhoto(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      base64Data: base64Data ?? this.base64Data,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'fileName': fileName,
      'mimeType': mimeType,
      'base64Data': base64Data,
      'note': note,
    };
  }

  factory ContinuityPhoto.fromJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString().trim();

    return ContinuityPhoto(
      id: rawId == null || rawId.isEmpty
          ? 'photo_${DateTime.now().microsecondsSinceEpoch}'
          : rawId,
      fileName: json['fileName']?.toString() ?? '',
      mimeType: json['mimeType']?.toString() ?? 'image/jpeg',
      base64Data: json['base64Data']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
    );
  }
}

class ShotTake {
  const ShotTake({
    required this.id,
    this.takeNumber = 1,
    this.status = ShotTakeStatus.planned,
    this.shootingDayId,
    this.timecode = '',
    this.durationSeconds = 0,
    this.mediaCard = '',
    this.camera = '',
    this.fileName = '',
    this.rating = 0,
    this.directorNotes = '',
    this.cameraNotes = '',
    this.soundNotes = '',
    this.rejectionReason = '',
    this.costumeContinuity = '',
    this.makeupContinuity = '',
    this.propsContinuity = '',
    this.actorPositions = '',
    this.continuityPhotos = const <ContinuityPhoto>[],
  });

  final String id;
  final int takeNumber;
  final ShotTakeStatus status;
  final String? shootingDayId;
  final String timecode;
  final double durationSeconds;
  final String mediaCard;
  final String camera;
  final String fileName;
  final int rating;
  final String directorNotes;
  final String cameraNotes;
  final String soundNotes;
  final String rejectionReason;
  final String costumeContinuity;
  final String makeupContinuity;
  final String propsContinuity;
  final String actorPositions;
  final List<ContinuityPhoto> continuityPhotos;

  bool get hasContinuityData =>
      costumeContinuity.trim().isNotEmpty ||
      makeupContinuity.trim().isNotEmpty ||
      propsContinuity.trim().isNotEmpty ||
      actorPositions.trim().isNotEmpty ||
      continuityPhotos.isNotEmpty;

  ShotTake copyWith({
    String? id,
    int? takeNumber,
    ShotTakeStatus? status,
    String? shootingDayId,
    bool clearShootingDayId = false,
    String? timecode,
    double? durationSeconds,
    String? mediaCard,
    String? camera,
    String? fileName,
    int? rating,
    String? directorNotes,
    String? cameraNotes,
    String? soundNotes,
    String? rejectionReason,
    String? costumeContinuity,
    String? makeupContinuity,
    String? propsContinuity,
    String? actorPositions,
    List<ContinuityPhoto>? continuityPhotos,
  }) {
    return ShotTake(
      id: id ?? this.id,
      takeNumber: takeNumber ?? this.takeNumber,
      status: status ?? this.status,
      shootingDayId:
          clearShootingDayId ? null : shootingDayId ?? this.shootingDayId,
      timecode: timecode ?? this.timecode,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      mediaCard: mediaCard ?? this.mediaCard,
      camera: camera ?? this.camera,
      fileName: fileName ?? this.fileName,
      rating: rating ?? this.rating,
      directorNotes: directorNotes ?? this.directorNotes,
      cameraNotes: cameraNotes ?? this.cameraNotes,
      soundNotes: soundNotes ?? this.soundNotes,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      costumeContinuity: costumeContinuity ?? this.costumeContinuity,
      makeupContinuity: makeupContinuity ?? this.makeupContinuity,
      propsContinuity: propsContinuity ?? this.propsContinuity,
      actorPositions: actorPositions ?? this.actorPositions,
      continuityPhotos: continuityPhotos ?? this.continuityPhotos,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'takeNumber': takeNumber,
      'status': status.name,
      if (shootingDayId != null) 'shootingDayId': shootingDayId,
      'timecode': timecode,
      'durationSeconds': durationSeconds,
      'mediaCard': mediaCard,
      'camera': camera,
      'fileName': fileName,
      'rating': rating,
      'directorNotes': directorNotes,
      'cameraNotes': cameraNotes,
      'soundNotes': soundNotes,
      'rejectionReason': rejectionReason,
      'costumeContinuity': costumeContinuity,
      'makeupContinuity': makeupContinuity,
      'propsContinuity': propsContinuity,
      'actorPositions': actorPositions,
      'continuityPhotos': continuityPhotos
          .map((photo) => photo.toJson())
          .toList(growable: false),
    };
  }

  factory ShotTake.fromJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString().trim();
    final photos = <ContinuityPhoto>[];
    final rawPhotos = json['continuityPhotos'];

    if (rawPhotos is List) {
      for (final rawPhoto in rawPhotos) {
        if (rawPhoto is! Map) {
          continue;
        }

        photos.add(
          ContinuityPhoto.fromJson(
            rawPhoto.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          ),
        );
      }
    }

    return ShotTake(
      id: rawId == null || rawId.isEmpty
          ? 'take_${DateTime.now().microsecondsSinceEpoch}'
          : rawId,
      takeNumber: _readPositiveInt(json['takeNumber'], fallback: 1),
      status: ShotTakeStatus.values.firstWhere(
        (value) => value.name == json['status']?.toString(),
        orElse: () => ShotTakeStatus.planned,
      ),
      shootingDayId: _readNullableString(json['shootingDayId']),
      timecode: json['timecode']?.toString() ?? '',
      durationSeconds: _readNonNegativeDouble(json['durationSeconds']),
      mediaCard: json['mediaCard']?.toString() ?? '',
      camera: json['camera']?.toString() ?? '',
      fileName: json['fileName']?.toString() ?? '',
      rating: _readBoundedInt(json['rating'], min: 0, max: 5),
      directorNotes: json['directorNotes']?.toString() ?? '',
      cameraNotes: json['cameraNotes']?.toString() ?? '',
      soundNotes: json['soundNotes']?.toString() ?? '',
      rejectionReason: json['rejectionReason']?.toString() ?? '',
      costumeContinuity: json['costumeContinuity']?.toString() ?? '',
      makeupContinuity: json['makeupContinuity']?.toString() ?? '',
      propsContinuity: json['propsContinuity']?.toString() ?? '',
      actorPositions: json['actorPositions']?.toString() ?? '',
      continuityPhotos: photos,
    );
  }
}

class ShootingDayJournal {
  const ShootingDayJournal({
    this.actualCrewCall = '',
    this.actualFirstShot = '',
    this.actualWrap = '',
    this.weather = '',
    this.summary = '',
    this.incidents = '',
    this.mediaBackup = '',
    this.cameraReport = '',
    this.soundReport = '',
    this.notes = '',
  });

  final String actualCrewCall;
  final String actualFirstShot;
  final String actualWrap;
  final String weather;
  final String summary;
  final String incidents;
  final String mediaBackup;
  final String cameraReport;
  final String soundReport;
  final String notes;

  bool get isDefault =>
      actualCrewCall.trim().isEmpty &&
      actualFirstShot.trim().isEmpty &&
      actualWrap.trim().isEmpty &&
      weather.trim().isEmpty &&
      summary.trim().isEmpty &&
      incidents.trim().isEmpty &&
      mediaBackup.trim().isEmpty &&
      cameraReport.trim().isEmpty &&
      soundReport.trim().isEmpty &&
      notes.trim().isEmpty;

  ShootingDayJournal copyWith({
    String? actualCrewCall,
    String? actualFirstShot,
    String? actualWrap,
    String? weather,
    String? summary,
    String? incidents,
    String? mediaBackup,
    String? cameraReport,
    String? soundReport,
    String? notes,
  }) {
    return ShootingDayJournal(
      actualCrewCall: actualCrewCall ?? this.actualCrewCall,
      actualFirstShot: actualFirstShot ?? this.actualFirstShot,
      actualWrap: actualWrap ?? this.actualWrap,
      weather: weather ?? this.weather,
      summary: summary ?? this.summary,
      incidents: incidents ?? this.incidents,
      mediaBackup: mediaBackup ?? this.mediaBackup,
      cameraReport: cameraReport ?? this.cameraReport,
      soundReport: soundReport ?? this.soundReport,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'actualCrewCall': actualCrewCall,
      'actualFirstShot': actualFirstShot,
      'actualWrap': actualWrap,
      'weather': weather,
      'summary': summary,
      'incidents': incidents,
      'mediaBackup': mediaBackup,
      'cameraReport': cameraReport,
      'soundReport': soundReport,
      'notes': notes,
    };
  }

  factory ShootingDayJournal.fromJson(Map<String, dynamic> json) {
    return ShootingDayJournal(
      actualCrewCall: json['actualCrewCall']?.toString() ?? '',
      actualFirstShot: json['actualFirstShot']?.toString() ?? '',
      actualWrap: json['actualWrap']?.toString() ?? '',
      weather: json['weather']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      incidents: json['incidents']?.toString() ?? '',
      mediaBackup: json['mediaBackup']?.toString() ?? '',
      cameraReport: json['cameraReport']?.toString() ?? '',
      soundReport: json['soundReport']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
    );
  }
}

String? _readNullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

double _readNonNegativeDouble(Object? value) {
  final parsed = switch (value) {
    num number => number.toDouble(),
    _ => double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0,
  };

  return parsed < 0 ? 0 : parsed;
}

int _readPositiveInt(Object? value, {required int fallback}) {
  final parsed = switch (value) {
    int number => number,
    num number => number.toInt(),
    _ => int.tryParse(value?.toString() ?? '') ?? fallback,
  };

  return parsed <= 0 ? fallback : parsed;
}

int _readBoundedInt(Object? value, {required int min, required int max}) {
  final parsed = switch (value) {
    int number => number,
    num number => number.toInt(),
    _ => int.tryParse(value?.toString() ?? '') ?? min,
  };

  return parsed.clamp(min, max).toInt();
}
