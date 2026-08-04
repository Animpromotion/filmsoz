import 'dart:convert';
import 'dart:typed_data';

enum ShotSize {
  extremeWide,
  wide,
  full,
  mediumWide,
  medium,
  mediumCloseUp,
  closeUp,
  extremeCloseUp,
  insert,
}

extension ShotSizeLabel on ShotSize {
  String get label {
    return switch (this) {
      ShotSize.extremeWide => 'Сверхобщий',
      ShotSize.wide => 'Общий',
      ShotSize.full => 'Ростовой',
      ShotSize.mediumWide => 'Средне-общий',
      ShotSize.medium => 'Средний',
      ShotSize.mediumCloseUp => 'Крупно-средний',
      ShotSize.closeUp => 'Крупный',
      ShotSize.extremeCloseUp => 'Деталь лица',
      ShotSize.insert => 'Деталь / вставка',
    };
  }
}

enum CameraAngle {
  eyeLevel,
  high,
  low,
  dutch,
  overhead,
  groundLevel,
  pointOfView,
}

extension CameraAngleLabel on CameraAngle {
  String get label {
    return switch (this) {
      CameraAngle.eyeLevel => 'На уровне глаз',
      CameraAngle.high => 'Верхний ракурс',
      CameraAngle.low => 'Нижний ракурс',
      CameraAngle.dutch => 'Голландский угол',
      CameraAngle.overhead => 'Вид сверху',
      CameraAngle.groundLevel => 'С уровня земли',
      CameraAngle.pointOfView => 'Субъективная камера',
    };
  }
}

enum CameraMovement {
  staticShot,
  pan,
  tilt,
  dolly,
  tracking,
  crane,
  handheld,
  steadicam,
  zoom,
  drone,
}

extension CameraMovementLabel on CameraMovement {
  String get label {
    return switch (this) {
      CameraMovement.staticShot => 'Статика',
      CameraMovement.pan => 'Панорама',
      CameraMovement.tilt => 'Наклон',
      CameraMovement.dolly => 'Долли',
      CameraMovement.tracking => 'Трекинг',
      CameraMovement.crane => 'Кран',
      CameraMovement.handheld => 'С рук',
      CameraMovement.steadicam => 'Стедикам',
      CameraMovement.zoom => 'Зум',
      CameraMovement.drone => 'Дрон',
    };
  }
}

class StoryboardShot {
  const StoryboardShot({
    required this.id,
    this.title = '',
    this.shotSize = ShotSize.medium,
    this.cameraAngle = CameraAngle.eyeLevel,
    this.cameraMovement = CameraMovement.staticShot,
    this.lens = '',
    this.fps = 24,
    this.durationSeconds = 0,
    this.equipment = const <String>[],
    this.visualDescription = '',
    this.actionDescription = '',
    this.dialogue = '',
    this.sound = '',
    this.notes = '',
    this.imageFileName,
    this.imageMimeType,
    this.imageBase64,
  });

  final String id;
  final String title;
  final ShotSize shotSize;
  final CameraAngle cameraAngle;
  final CameraMovement cameraMovement;
  final String lens;
  final double fps;
  final double durationSeconds;
  final List<String> equipment;
  final String visualDescription;
  final String actionDescription;
  final String dialogue;
  final String sound;
  final String notes;
  final String? imageFileName;
  final String? imageMimeType;
  final String? imageBase64;

  bool get hasImage => imageBase64?.trim().isNotEmpty == true;

  Uint8List? get imageBytes {
    final encoded = imageBase64;

    if (encoded == null || encoded.trim().isEmpty) {
      return null;
    }

    try {
      return base64Decode(encoded);
    } on FormatException {
      return null;
    }
  }

  StoryboardShot copyWith({
    String? id,
    String? title,
    ShotSize? shotSize,
    CameraAngle? cameraAngle,
    CameraMovement? cameraMovement,
    String? lens,
    double? fps,
    double? durationSeconds,
    List<String>? equipment,
    String? visualDescription,
    String? actionDescription,
    String? dialogue,
    String? sound,
    String? notes,
    String? imageFileName,
    String? imageMimeType,
    String? imageBase64,
    bool clearImage = false,
  }) {
    return StoryboardShot(
      id: id ?? this.id,
      title: title ?? this.title,
      shotSize: shotSize ?? this.shotSize,
      cameraAngle: cameraAngle ?? this.cameraAngle,
      cameraMovement: cameraMovement ?? this.cameraMovement,
      lens: lens ?? this.lens,
      fps: fps ?? this.fps,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      equipment: equipment ?? this.equipment,
      visualDescription: visualDescription ?? this.visualDescription,
      actionDescription: actionDescription ?? this.actionDescription,
      dialogue: dialogue ?? this.dialogue,
      sound: sound ?? this.sound,
      notes: notes ?? this.notes,
      imageFileName: clearImage ? null : imageFileName ?? this.imageFileName,
      imageMimeType: clearImage ? null : imageMimeType ?? this.imageMimeType,
      imageBase64: clearImage ? null : imageBase64 ?? this.imageBase64,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'shotSize': shotSize.name,
      'cameraAngle': cameraAngle.name,
      'cameraMovement': cameraMovement.name,
      'lens': lens,
      'fps': fps,
      'durationSeconds': durationSeconds,
      'equipment': equipment,
      'visualDescription': visualDescription,
      'actionDescription': actionDescription,
      'dialogue': dialogue,
      'sound': sound,
      'notes': notes,
      if (imageFileName != null) 'imageFileName': imageFileName,
      if (imageMimeType != null) 'imageMimeType': imageMimeType,
      if (imageBase64 != null) 'imageBase64': imageBase64,
    };
  }

  factory StoryboardShot.fromJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString().trim();

    return StoryboardShot(
      id: rawId == null || rawId.isEmpty
          ? DateTime.now().microsecondsSinceEpoch.toString()
          : rawId,
      title: json['title']?.toString() ?? '',
      shotSize: ShotSize.values.firstWhere(
        (value) => value.name == json['shotSize']?.toString(),
        orElse: () => ShotSize.medium,
      ),
      cameraAngle: CameraAngle.values.firstWhere(
        (value) => value.name == json['cameraAngle']?.toString(),
        orElse: () => CameraAngle.eyeLevel,
      ),
      cameraMovement: CameraMovement.values.firstWhere(
        (value) => value.name == json['cameraMovement']?.toString(),
        orElse: () => CameraMovement.staticShot,
      ),
      lens: json['lens']?.toString() ?? '',
      fps: _readPositiveDouble(json['fps'], fallback: 24),
      durationSeconds: _readNonNegativeDouble(json['durationSeconds']),
      equipment: _readUniqueStrings(json['equipment']),
      visualDescription: json['visualDescription']?.toString() ?? '',
      actionDescription: json['actionDescription']?.toString() ?? '',
      dialogue: json['dialogue']?.toString() ?? '',
      sound: json['sound']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      imageFileName: _readNullableString(json['imageFileName']),
      imageMimeType: _readNullableString(json['imageMimeType']),
      imageBase64: _readNullableString(json['imageBase64']),
    );
  }
}

List<String> readStoryboardStringList(String value) {
  return _normalizeStrings(value.split(RegExp(r'[,;\n]')));
}

List<String> normalizeStoryboardStrings(Iterable<String> values) {
  return _normalizeStrings(values);
}

List<String> _readUniqueStrings(Object? value) {
  if (value is! List) {
    return const <String>[];
  }

  return _normalizeStrings(value.map((item) => item?.toString() ?? ''));
}

List<String> _normalizeStrings(Iterable<String> values) {
  final result = <String>[];
  final seen = <String>{};

  for (final rawValue in values) {
    final value = rawValue.trim();

    if (value.isEmpty || !seen.add(value.toUpperCase())) {
      continue;
    }

    result.add(value);
  }

  return result;
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

double _readPositiveDouble(Object? value, {required double fallback}) {
  final parsed = _readNonNegativeDouble(value);
  return parsed <= 0 ? fallback : parsed;
}
