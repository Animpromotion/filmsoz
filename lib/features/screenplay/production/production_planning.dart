enum ProductionPriority {
  low,
  normal,
  high,
  critical,
}

extension ProductionPriorityLabel on ProductionPriority {
  String get label {
    return switch (this) {
      ProductionPriority.low => 'Низкий',
      ProductionPriority.normal => 'Обычный',
      ProductionPriority.high => 'Высокий',
      ProductionPriority.critical => 'Критический',
    };
  }
}

enum ShootingDayStatus {
  planned,
  confirmed,
  completed,
}

extension ShootingDayStatusLabel on ShootingDayStatus {
  String get label {
    return switch (this) {
      ShootingDayStatus.planned => 'Запланирован',
      ShootingDayStatus.confirmed => 'Подтверждён',
      ShootingDayStatus.completed => 'Завершён',
    };
  }
}

class SceneProductionData {
  const SceneProductionData({
    this.cast = const <String>[],
    this.extras = 0,
    this.locations = const <String>[],
    this.props = const <String>[],
    this.costumes = const <String>[],
    this.makeup = const <String>[],
    this.vehicles = const <String>[],
    this.specialEquipment = const <String>[],
    this.notes = '',
    this.estimatedSetupMinutes = 0,
    this.estimatedShootMinutes = 0,
    this.priority = ProductionPriority.normal,
  });

  final List<String> cast;
  final int extras;
  final List<String> locations;
  final List<String> props;
  final List<String> costumes;
  final List<String> makeup;
  final List<String> vehicles;
  final List<String> specialEquipment;
  final String notes;
  final int estimatedSetupMinutes;
  final int estimatedShootMinutes;
  final ProductionPriority priority;

  SceneProductionData copyWith({
    List<String>? cast,
    int? extras,
    List<String>? locations,
    List<String>? props,
    List<String>? costumes,
    List<String>? makeup,
    List<String>? vehicles,
    List<String>? specialEquipment,
    String? notes,
    int? estimatedSetupMinutes,
    int? estimatedShootMinutes,
    ProductionPriority? priority,
  }) {
    return SceneProductionData(
      cast: cast ?? this.cast,
      extras: extras ?? this.extras,
      locations: locations ?? this.locations,
      props: props ?? this.props,
      costumes: costumes ?? this.costumes,
      makeup: makeup ?? this.makeup,
      vehicles: vehicles ?? this.vehicles,
      specialEquipment: specialEquipment ?? this.specialEquipment,
      notes: notes ?? this.notes,
      estimatedSetupMinutes:
          estimatedSetupMinutes ?? this.estimatedSetupMinutes,
      estimatedShootMinutes:
          estimatedShootMinutes ?? this.estimatedShootMinutes,
      priority: priority ?? this.priority,
    );
  }

  bool get isDefault =>
      cast.isEmpty &&
      extras <= 0 &&
      locations.isEmpty &&
      props.isEmpty &&
      costumes.isEmpty &&
      makeup.isEmpty &&
      vehicles.isEmpty &&
      specialEquipment.isEmpty &&
      notes.trim().isEmpty &&
      estimatedSetupMinutes <= 0 &&
      estimatedShootMinutes <= 0 &&
      priority == ProductionPriority.normal;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'cast': cast,
      'extras': extras,
      'locations': locations,
      'props': props,
      'costumes': costumes,
      'makeup': makeup,
      'vehicles': vehicles,
      'specialEquipment': specialEquipment,
      'notes': notes,
      'estimatedSetupMinutes': estimatedSetupMinutes,
      'estimatedShootMinutes': estimatedShootMinutes,
      'priority': priority.name,
    };
  }

  factory SceneProductionData.fromJson(Map<String, dynamic> json) {
    return SceneProductionData(
      cast: _readStringList(json['cast']),
      extras: _readNonNegativeInt(json['extras']),
      locations: _readStringList(json['locations']),
      props: _readStringList(json['props']),
      costumes: _readStringList(json['costumes']),
      makeup: _readStringList(json['makeup']),
      vehicles: _readStringList(json['vehicles']),
      specialEquipment: _readStringList(json['specialEquipment']),
      notes: json['notes']?.toString() ?? '',
      estimatedSetupMinutes: _readNonNegativeInt(json['estimatedSetupMinutes']),
      estimatedShootMinutes: _readNonNegativeInt(json['estimatedShootMinutes']),
      priority: ProductionPriority.values.firstWhere(
        (value) => value.name == json['priority']?.toString(),
        orElse: () => ProductionPriority.normal,
      ),
    );
  }
}

class ShootingDayPlan {
  const ShootingDayPlan({
    required this.id,
    required this.title,
    this.date = '',
    this.location = '',
    this.crewCall = '',
    this.firstShot = '',
    this.estimatedWrap = '',
    this.sceneIds = const <String>[],
    this.notes = '',
    this.status = ShootingDayStatus.planned,
  });

  final String id;
  final String title;
  final String date;
  final String location;
  final String crewCall;
  final String firstShot;
  final String estimatedWrap;
  final List<String> sceneIds;
  final String notes;
  final ShootingDayStatus status;

  ShootingDayPlan copyWith({
    String? id,
    String? title,
    String? date,
    String? location,
    String? crewCall,
    String? firstShot,
    String? estimatedWrap,
    List<String>? sceneIds,
    String? notes,
    ShootingDayStatus? status,
  }) {
    return ShootingDayPlan(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      location: location ?? this.location,
      crewCall: crewCall ?? this.crewCall,
      firstShot: firstShot ?? this.firstShot,
      estimatedWrap: estimatedWrap ?? this.estimatedWrap,
      sceneIds: sceneIds ?? this.sceneIds,
      notes: notes ?? this.notes,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'date': date,
      'location': location,
      'crewCall': crewCall,
      'firstShot': firstShot,
      'estimatedWrap': estimatedWrap,
      'sceneIds': sceneIds,
      'notes': notes,
      'status': status.name,
    };
  }

  factory ShootingDayPlan.fromJson(Map<String, dynamic> json) {
    final fallbackId = DateTime.now().microsecondsSinceEpoch.toString();
    final id = json['id']?.toString().trim();
    final title = json['title']?.toString().trim();

    return ShootingDayPlan(
      id: id == null || id.isEmpty ? fallbackId : id,
      title: title == null || title.isEmpty ? 'Съёмочный день' : title,
      date: json['date']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      crewCall: json['crewCall']?.toString() ?? '',
      firstShot: json['firstShot']?.toString() ?? '',
      estimatedWrap: json['estimatedWrap']?.toString() ?? '',
      sceneIds: _readStringList(json['sceneIds']),
      notes: json['notes']?.toString() ?? '',
      status: ShootingDayStatus.values.firstWhere(
        (value) => value.name == json['status']?.toString(),
        orElse: () => ShootingDayStatus.planned,
      ),
    );
  }
}

List<String> _readStringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }

  final result = <String>[];
  final seen = <String>{};

  for (final item in value) {
    final text = item?.toString().trim() ?? '';

    if (text.isEmpty) {
      continue;
    }

    final key = text.toUpperCase();

    if (seen.add(key)) {
      result.add(text);
    }
  }

  return result;
}

int _readNonNegativeInt(Object? value) {
  final parsed = switch (value) {
    int number => number,
    num number => number.toInt(),
    _ => int.tryParse(value?.toString() ?? '') ?? 0,
  };

  return parsed < 0 ? 0 : parsed;
}
