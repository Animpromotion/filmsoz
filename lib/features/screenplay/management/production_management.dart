enum ProductionPersonType {
  cast,
  crew,
}

extension ProductionPersonTypeLabel on ProductionPersonType {
  String get label {
    return switch (this) {
      ProductionPersonType.cast => 'Актёр',
      ProductionPersonType.crew => 'Съёмочная группа',
    };
  }
}

enum CrewDepartment {
  cast,
  directing,
  production,
  camera,
  lighting,
  sound,
  art,
  costume,
  makeup,
  locations,
  transport,
  postProduction,
  marketing,
  other,
}

extension CrewDepartmentLabel on CrewDepartment {
  String get label {
    return switch (this) {
      CrewDepartment.cast => 'Актёрский состав',
      CrewDepartment.directing => 'Режиссура',
      CrewDepartment.production => 'Продюсирование',
      CrewDepartment.camera => 'Камера',
      CrewDepartment.lighting => 'Свет',
      CrewDepartment.sound => 'Звук',
      CrewDepartment.art => 'Художественный отдел',
      CrewDepartment.costume => 'Костюм',
      CrewDepartment.makeup => 'Грим',
      CrewDepartment.locations => 'Локации',
      CrewDepartment.transport => 'Транспорт',
      CrewDepartment.postProduction => 'Постпродакшн',
      CrewDepartment.marketing => 'Маркетинг',
      CrewDepartment.other => 'Другое',
    };
  }
}

class ProductionPerson {
  const ProductionPerson({
    required this.id,
    required this.name,
    this.type = ProductionPersonType.crew,
    this.department = CrewDepartment.other,
    this.jobTitle = '',
    this.phone = '',
    this.email = '',
    this.notes = '',
    this.linkedCharacters = const <String>[],
    this.unavailableDates = const <String>[],
    this.dailyRate = 0,
  });

  final String id;
  final String name;
  final ProductionPersonType type;
  final CrewDepartment department;
  final String jobTitle;
  final String phone;
  final String email;
  final String notes;
  final List<String> linkedCharacters;
  final List<String> unavailableDates;
  final double dailyRate;

  ProductionPerson copyWith({
    String? id,
    String? name,
    ProductionPersonType? type,
    CrewDepartment? department,
    String? jobTitle,
    String? phone,
    String? email,
    String? notes,
    List<String>? linkedCharacters,
    List<String>? unavailableDates,
    double? dailyRate,
  }) {
    return ProductionPerson(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      department: department ?? this.department,
      jobTitle: jobTitle ?? this.jobTitle,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      notes: notes ?? this.notes,
      linkedCharacters: linkedCharacters ?? this.linkedCharacters,
      unavailableDates: unavailableDates ?? this.unavailableDates,
      dailyRate: dailyRate ?? this.dailyRate,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'type': type.name,
      'department': department.name,
      'jobTitle': jobTitle,
      'phone': phone,
      'email': email,
      'notes': notes,
      'linkedCharacters': linkedCharacters,
      'unavailableDates': unavailableDates,
      'dailyRate': dailyRate,
    };
  }

  factory ProductionPerson.fromJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString().trim();
    final rawName = json['name']?.toString().trim();

    return ProductionPerson(
      id: rawId == null || rawId.isEmpty
          ? DateTime.now().microsecondsSinceEpoch.toString()
          : rawId,
      name: rawName == null || rawName.isEmpty ? 'Без имени' : rawName,
      type: ProductionPersonType.values.firstWhere(
        (value) => value.name == json['type']?.toString(),
        orElse: () => ProductionPersonType.crew,
      ),
      department: CrewDepartment.values.firstWhere(
        (value) => value.name == json['department']?.toString(),
        orElse: () => CrewDepartment.other,
      ),
      jobTitle: json['jobTitle']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      linkedCharacters: _readUniqueStrings(json['linkedCharacters']),
      unavailableDates: _readUniqueStrings(json['unavailableDates']),
      dailyRate: _readNonNegativeDouble(json['dailyRate']),
    );
  }
}

enum BudgetCategory {
  cast,
  crew,
  equipment,
  locations,
  art,
  costumeMakeup,
  transport,
  catering,
  postProduction,
  marketing,
  contingency,
  other,
}

extension BudgetCategoryLabel on BudgetCategory {
  String get label {
    return switch (this) {
      BudgetCategory.cast => 'Актёры',
      BudgetCategory.crew => 'Съёмочная группа',
      BudgetCategory.equipment => 'Оборудование',
      BudgetCategory.locations => 'Локации',
      BudgetCategory.art => 'Реквизит и декорации',
      BudgetCategory.costumeMakeup => 'Костюм и грим',
      BudgetCategory.transport => 'Транспорт',
      BudgetCategory.catering => 'Питание',
      BudgetCategory.postProduction => 'Постпродакшн',
      BudgetCategory.marketing => 'Маркетинг',
      BudgetCategory.contingency => 'Резерв',
      BudgetCategory.other => 'Другое',
    };
  }
}

class BudgetItem {
  const BudgetItem({
    required this.id,
    required this.title,
    this.category = BudgetCategory.other,
    this.plannedAmount = 0,
    this.actualAmount = 0,
    this.paidAmount = 0,
    this.payee = '',
    this.sceneId,
    this.shootingDayId,
    this.notes = '',
  });

  final String id;
  final String title;
  final BudgetCategory category;
  final double plannedAmount;
  final double actualAmount;
  final double paidAmount;
  final String payee;
  final String? sceneId;
  final String? shootingDayId;
  final String notes;

  double get outstandingAmount {
    final result = actualAmount - paidAmount;
    return result > 0 ? result : 0.0;
  }

  double get variance => plannedAmount - actualAmount;

  BudgetItem copyWith({
    String? id,
    String? title,
    BudgetCategory? category,
    double? plannedAmount,
    double? actualAmount,
    double? paidAmount,
    String? payee,
    String? sceneId,
    bool clearSceneId = false,
    String? shootingDayId,
    bool clearShootingDayId = false,
    String? notes,
  }) {
    return BudgetItem(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      plannedAmount: plannedAmount ?? this.plannedAmount,
      actualAmount: actualAmount ?? this.actualAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      payee: payee ?? this.payee,
      sceneId: clearSceneId ? null : sceneId ?? this.sceneId,
      shootingDayId:
          clearShootingDayId ? null : shootingDayId ?? this.shootingDayId,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'category': category.name,
      'plannedAmount': plannedAmount,
      'actualAmount': actualAmount,
      'paidAmount': paidAmount,
      'payee': payee,
      'sceneId': sceneId,
      'shootingDayId': shootingDayId,
      'notes': notes,
    };
  }

  factory BudgetItem.fromJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString().trim();
    final rawTitle = json['title']?.toString().trim();
    final rawSceneId = json['sceneId']?.toString().trim();
    final rawDayId = json['shootingDayId']?.toString().trim();

    return BudgetItem(
      id: rawId == null || rawId.isEmpty
          ? DateTime.now().microsecondsSinceEpoch.toString()
          : rawId,
      title: rawTitle == null || rawTitle.isEmpty ? 'Статья бюджета' : rawTitle,
      category: BudgetCategory.values.firstWhere(
        (value) => value.name == json['category']?.toString(),
        orElse: () => BudgetCategory.other,
      ),
      plannedAmount: _readNonNegativeDouble(json['plannedAmount']),
      actualAmount: _readNonNegativeDouble(json['actualAmount']),
      paidAmount: _readNonNegativeDouble(json['paidAmount']),
      payee: json['payee']?.toString() ?? '',
      sceneId: rawSceneId == null || rawSceneId.isEmpty ? null : rawSceneId,
      shootingDayId: rawDayId == null || rawDayId.isEmpty ? null : rawDayId,
      notes: json['notes']?.toString() ?? '',
    );
  }
}

List<String> _readUniqueStrings(Object? value) {
  if (value is! List) {
    return const <String>[];
  }

  final result = <String>[];
  final seen = <String>{};

  for (final item in value) {
    final text = item?.toString().trim() ?? '';

    if (text.isEmpty || !seen.add(text.toUpperCase())) {
      continue;
    }

    result.add(text);
  }

  return result;
}

double _readNonNegativeDouble(Object? value) {
  final parsed = switch (value) {
    num number => number.toDouble(),
    _ => double.tryParse(
          value?.toString().replaceAll(',', '.') ?? '',
        ) ??
        0,
  };

  return parsed < 0 ? 0.0 : parsed;
}
