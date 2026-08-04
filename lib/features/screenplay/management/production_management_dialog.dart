import 'dart:async';

import 'package:flutter/material.dart';
import 'package:filmsoz_studio/features/screenplay/editor/controller/screenplay_editor_controller.dart';
import 'package:filmsoz_studio/features/screenplay/management/production_management.dart';
import 'package:filmsoz_studio/features/screenplay/management/production_management_file_service.dart';
import 'package:filmsoz_studio/features/screenplay/management/production_management_service.dart';

class ProductionManagementDialog extends StatefulWidget {
  const ProductionManagementDialog({
    super.key,
    required this.controller,
    required this.projectName,
  });

  final ScreenplayEditorController controller;
  final String projectName;

  @override
  State<ProductionManagementDialog> createState() =>
      _ProductionManagementDialogState();
}

class _ProductionManagementDialogState
    extends State<ProductionManagementDialog> {
  final ProductionManagementService _service =
      const ProductionManagementService();
  final ProductionManagementFileService _fileService =
      const ProductionManagementFileService();

  String _personQuery = '';
  String _budgetQuery = '';
  CrewDepartment? _departmentFilter;
  BudgetCategory? _budgetCategoryFilter;
  String? _selectedDayId;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
    _selectedDayId = widget.controller.document.shootingDays.firstOrNull?.id;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) {
      return;
    }

    final validDayIds =
        widget.controller.document.shootingDays.map((day) => day.id).toSet();
    if (_selectedDayId != null && !validDayIds.contains(_selectedDayId)) {
      _selectedDayId = widget.controller.document.shootingDays.firstOrNull?.id;
    }

    setState(() {});
  }

  List<ProductionPerson> get _visiblePeople {
    final query = _personQuery.trim().toLowerCase();
    final result = widget.controller.document.productionPeople.where((person) {
      if (_departmentFilter != null && person.department != _departmentFilter) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      return <String>[
        person.name,
        person.jobTitle,
        person.department.label,
        person.phone,
        person.email,
        person.linkedCharacters.join(' '),
        person.notes,
      ].join('\n').toLowerCase().contains(query);
    }).toList(growable: false);

    result.sort((first, second) {
      final departmentCompare = first.department.index.compareTo(
        second.department.index,
      );
      if (departmentCompare != 0) {
        return departmentCompare;
      }
      return first.name.toLowerCase().compareTo(second.name.toLowerCase());
    });
    return result;
  }

  List<BudgetItem> get _visibleBudgetItems {
    final query = _budgetQuery.trim().toLowerCase();
    final result = widget.controller.document.budgetItems.where((item) {
      if (_budgetCategoryFilter != null &&
          item.category != _budgetCategoryFilter) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      return <String>[
        item.title,
        item.payee,
        item.category.label,
        item.notes,
      ].join('\n').toLowerCase().contains(query);
    }).toList(growable: false);

    result.sort((first, second) {
      final categoryCompare = first.category.index.compareTo(
        second.category.index,
      );
      if (categoryCompare != 0) {
        return categoryCompare;
      }
      return first.title.toLowerCase().compareTo(second.title.toLowerCase());
    });
    return result;
  }

  List<String> _splitList(String value) {
    final result = <String>[];
    final seen = <String>{};

    for (final part in value.split(RegExp(r'[,;\n]'))) {
      final text = part.trim();
      if (text.isEmpty || !seen.add(text.toUpperCase())) {
        continue;
      }
      result.add(text);
    }

    return result;
  }

  double _readAmount(String value) {
    return double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;
  }

  Future<void> _addPerson(ProductionPersonType type) async {
    final id = widget.controller.createProductionPerson(type: type);
    final person = widget.controller.document.productionPersonById(id);

    if (person != null) {
      await _editPerson(person);
    }
  }

  Future<void> _editPerson(ProductionPerson person) async {
    final nameController = TextEditingController(text: person.name);
    final jobController = TextEditingController(text: person.jobTitle);
    final phoneController = TextEditingController(text: person.phone);
    final emailController = TextEditingController(text: person.email);
    final charactersController = TextEditingController(
      text: person.linkedCharacters.join(', '),
    );
    final unavailableController = TextEditingController(
      text: person.unavailableDates.join(', '),
    );
    final rateController = TextEditingController(
      text: person.dailyRate <= 0 ? '' : person.dailyRate.toStringAsFixed(2),
    );
    final notesController = TextEditingController(text: person.notes);
    var type = person.type;
    var department = person.type == ProductionPersonType.cast
        ? CrewDepartment.cast
        : person.department == CrewDepartment.cast
            ? CrewDepartment.other
            : person.department;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF29292D),
              title: Text(
                person.name == 'Новый участник'
                    ? 'Новый участник проекта'
                    : 'Карточка участника',
              ),
              content: SizedBox(
                width: 760,
                height: 640,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _Field(
                          controller: nameController, label: 'Имя и фамилия'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child:
                                DropdownButtonFormField<ProductionPersonType>(
                              initialValue: type,
                              decoration:
                                  const InputDecoration(labelText: 'Тип'),
                              items: ProductionPersonType.values
                                  .map(
                                    (value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(value.label),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (value) {
                                if (value == null) {
                                  return;
                                }
                                setDialogState(() {
                                  type = value;
                                  if (type == ProductionPersonType.cast) {
                                    department = CrewDepartment.cast;
                                  } else if (department ==
                                      CrewDepartment.cast) {
                                    department = CrewDepartment.other;
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<CrewDepartment>(
                              initialValue: department,
                              decoration:
                                  const InputDecoration(labelText: 'Отдел'),
                              items: CrewDepartment.values
                                  .where(
                                    (value) => type == ProductionPersonType.cast
                                        ? value == CrewDepartment.cast
                                        : value != CrewDepartment.cast,
                                  )
                                  .map(
                                    (value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(value.label),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (value) {
                                if (value != null) {
                                  setDialogState(() => department = value);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        controller: jobController,
                        label: type == ProductionPersonType.cast
                            ? 'Роль / статус'
                            : 'Должность',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _Field(
                              controller: phoneController,
                              label: 'Телефон',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _Field(
                              controller: emailController,
                              label: 'Электронная почта',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        controller: charactersController,
                        label: 'Связанные персонажи',
                        hint: 'ФАРХОД, АННА',
                        enabled: type == ProductionPersonType.cast,
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        controller: unavailableController,
                        label: 'Недоступные даты',
                        hint: '2026-08-15, 2026-08-22',
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        controller: rateController,
                        label:
                            'Ставка за съёмочный день (${widget.controller.document.budgetCurrency})',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        controller: notesController,
                        label: 'Примечания',
                        minLines: 3,
                        maxLines: 6,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldSave == true) {
      widget.controller.updateProductionPerson(
        person.copyWith(
          name: nameController.text,
          type: type,
          department: department,
          jobTitle: jobController.text,
          phone: phoneController.text,
          email: emailController.text,
          linkedCharacters: type == ProductionPersonType.cast
              ? _splitList(charactersController.text)
              : const <String>[],
          unavailableDates: _splitList(unavailableController.text),
          dailyRate: _readAmount(rateController.text),
          notes: notesController.text,
        ),
      );
    }

    nameController.dispose();
    jobController.dispose();
    phoneController.dispose();
    emailController.dispose();
    charactersController.dispose();
    unavailableController.dispose();
    rateController.dispose();
    notesController.dispose();
  }

  Future<void> _deletePerson(ProductionPerson person) async {
    final confirmed = await _confirm(
      title: 'Удалить участника?',
      message: '«${person.name}» будет удалён из базы проекта.',
    );

    if (confirmed) {
      widget.controller.deleteProductionPerson(person.id);
    }
  }

  Future<void> _addBudgetItem() async {
    final id = widget.controller.createBudgetItem();
    final item = widget.controller.document.budgetItemById(id);

    if (item != null) {
      await _editBudgetItem(item);
    }
  }

  Future<void> _editBudgetItem(BudgetItem item) async {
    final titleController = TextEditingController(text: item.title);
    final payeeController = TextEditingController(text: item.payee);
    final plannedController = TextEditingController(
      text:
          item.plannedAmount <= 0 ? '' : item.plannedAmount.toStringAsFixed(2),
    );
    final actualController = TextEditingController(
      text: item.actualAmount <= 0 ? '' : item.actualAmount.toStringAsFixed(2),
    );
    final paidController = TextEditingController(
      text: item.paidAmount <= 0 ? '' : item.paidAmount.toStringAsFixed(2),
    );
    final notesController = TextEditingController(text: item.notes);
    var category = item.category;
    var sceneId = item.sceneId;
    var dayId = item.shootingDayId;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final scenes = widget.controller.document.sceneSections;
            final days = widget.controller.document.shootingDays;

            return AlertDialog(
              backgroundColor: const Color(0xFF29292D),
              title: const Text('Статья бюджета'),
              content: SizedBox(
                width: 780,
                height: 620,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _Field(
                          controller: titleController, label: 'Наименование'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<BudgetCategory>(
                              initialValue: category,
                              decoration:
                                  const InputDecoration(labelText: 'Категория'),
                              items: BudgetCategory.values
                                  .map(
                                    (value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(value.label),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (value) {
                                if (value != null) {
                                  setDialogState(() => category = value);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _Field(
                              controller: payeeController,
                              label: 'Получатель / поставщик',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _Field(
                              controller: plannedController,
                              label: 'План',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _Field(
                              controller: actualController,
                              label: 'Факт',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _Field(
                              controller: paidController,
                              label: 'Оплачено',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        initialValue: sceneId,
                        decoration: const InputDecoration(
                          labelText: 'Привязать к сцене',
                        ),
                        items: <DropdownMenuItem<String?>>[
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Без привязки'),
                          ),
                          ...scenes.map(
                            (scene) => DropdownMenuItem<String?>(
                              value: scene.id,
                              child: Text(
                                '${scene.number}. ${scene.title}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() => sceneId = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        initialValue: dayId,
                        decoration: const InputDecoration(
                          labelText: 'Привязать к съёмочному дню',
                        ),
                        items: <DropdownMenuItem<String?>>[
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Без привязки'),
                          ),
                          ...days.map(
                            (day) => DropdownMenuItem<String?>(
                              value: day.id,
                              child: Text(day.title),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() => dayId = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        controller: notesController,
                        label: 'Примечание',
                        minLines: 3,
                        maxLines: 6,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldSave == true) {
      widget.controller.updateBudgetItem(
        BudgetItem(
          id: item.id,
          title: titleController.text,
          category: category,
          plannedAmount: _readAmount(plannedController.text),
          actualAmount: _readAmount(actualController.text),
          paidAmount: _readAmount(paidController.text),
          payee: payeeController.text,
          sceneId: sceneId,
          shootingDayId: dayId,
          notes: notesController.text,
        ),
      );
    }

    titleController.dispose();
    payeeController.dispose();
    plannedController.dispose();
    actualController.dispose();
    paidController.dispose();
    notesController.dispose();
  }

  Future<void> _deleteBudgetItem(BudgetItem item) async {
    final confirmed = await _confirm(
      title: 'Удалить статью бюджета?',
      message: '«${item.title}» будет удалена.',
    );

    if (confirmed) {
      widget.controller.deleteBudgetItem(item.id);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Удалить'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _exportCsv({
    required String suffix,
    required String content,
  }) async {
    if (_isExporting) {
      return;
    }

    setState(() => _isExporting = true);

    try {
      final filePath = await _fileService.chooseSavePath(
        projectName: widget.projectName,
        suffix: suffix,
      );

      if (!mounted || filePath == null) {
        return;
      }

      final savedPath = await _fileService.writeCsv(filePath, content);
      if (!mounted) {
        return;
      }
      _message('Документ сохранён: $savedPath');
    } catch (error) {
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Ошибка экспорта'),
          content: Text('$error'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Закрыть'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: const Color(0xFF202024),
      child: SizedBox(
        width: 1180,
        height: 780,
        child: DefaultTabController(
          length: 3,
          child: Column(
            children: [
              _buildHeader(),
              const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.groups_outlined), text: 'Команда'),
                  Tab(
                      icon: Icon(Icons.account_balance_wallet_outlined),
                      text: 'Бюджет'),
                  Tab(
                      icon: Icon(Icons.description_outlined),
                      text: 'Документы'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildPeopleTab(),
                    _buildBudgetTab(),
                    _buildDocumentsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final document = widget.controller.document;
    final conflicts = _service.availabilityConflicts(document).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 10, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF29292D),
        border: Border(
          bottom: BorderSide(color: Color(0xFF3B3B42)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.movie_creation_outlined, color: Color(0xFFE5A93C)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Команда, актёры и бюджет',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                Text(
                  '${widget.projectName} • ${document.productionPeople.length} участников • ${document.budgetItems.length} статей • конфликтов: $conflicts',
                  style:
                      const TextStyle(color: Color(0xFF9B9BA5), fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Отменить',
            onPressed:
                widget.controller.canUndo ? widget.controller.undo : null,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: 'Вернуть',
            onPressed:
                widget.controller.canRedo ? widget.controller.redo : null,
            icon: const Icon(Icons.redo),
          ),
          IconButton(
            tooltip: 'Закрыть',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildPeopleTab() {
    final people = _visiblePeople;
    final document = widget.controller.document;
    final castCount = document.productionPeople
        .where((person) => person.type == ProductionPersonType.cast)
        .length;
    final crewCount = document.productionPeople.length - castCount;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              _MetricCard(label: 'Актёры', value: '$castCount'),
              const SizedBox(width: 10),
              _MetricCard(label: 'Команда', value: '$crewCount'),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Поиск по людям и персонажам',
                  ),
                  onChanged: (value) => setState(() => _personQuery = value),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<CrewDepartment?>(
                  initialValue: _departmentFilter,
                  decoration: const InputDecoration(labelText: 'Отдел'),
                  items: <DropdownMenuItem<CrewDepartment?>>[
                    const DropdownMenuItem<CrewDepartment?>(
                      value: null,
                      child: Text('Все отделы'),
                    ),
                    ...CrewDepartment.values.map(
                      (department) => DropdownMenuItem<CrewDepartment?>(
                        value: department,
                        child: Text(department.label),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _departmentFilter = value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              PopupMenuButton<ProductionPersonType>(
                tooltip: 'Добавить участника',
                onSelected: (type) => unawaited(_addPerson(type)),
                itemBuilder: (context) => ProductionPersonType.values
                    .map(
                      (type) => PopupMenuItem(
                        value: type,
                        child: Text(type == ProductionPersonType.cast
                            ? 'Добавить актёра'
                            : 'Добавить члена команды'),
                      ),
                    )
                    .toList(growable: false),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5A93C),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person_add_alt_1,
                        size: 18,
                        color: Colors.black,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Добавить',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: people.isEmpty
                ? const Center(
                    child: Text('Участники не найдены.'),
                  )
                : ListView.separated(
                    itemCount: people.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final person = people[index];
                      return Material(
                        color: const Color(0xFF29292D),
                        borderRadius: BorderRadius.circular(10),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: Color(0xFF3C3C43)),
                          ),
                          leading: CircleAvatar(
                            backgroundColor:
                                person.type == ProductionPersonType.cast
                                    ? const Color(0xFFE5A93C)
                                    : const Color(0xFF5B7DB1),
                            foregroundColor: Colors.black,
                            child: Icon(
                              person.type == ProductionPersonType.cast
                                  ? Icons.theater_comedy_outlined
                                  : Icons.engineering_outlined,
                            ),
                          ),
                          title: Text(
                            person.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            <String>[
                              person.department.label,
                              if (person.jobTitle.isNotEmpty) person.jobTitle,
                              if (person.linkedCharacters.isNotEmpty)
                                'Персонажи: ${person.linkedCharacters.join(', ')}',
                              if (person.phone.isNotEmpty) person.phone,
                              if (person.unavailableDates.isNotEmpty)
                                'Недоступен: ${person.unavailableDates.join(', ')}',
                            ].join(' • '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (person.dailyRate > 0)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Text(
                                    '${_money(person.dailyRate)} ${document.budgetCurrency}/день',
                                    style: const TextStyle(
                                      color: Color(0xFFE5A93C),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              IconButton(
                                tooltip: 'Редактировать',
                                onPressed: () => unawaited(_editPerson(person)),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'Удалить',
                                onPressed: () =>
                                    unawaited(_deletePerson(person)),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                          onTap: () => unawaited(_editPerson(person)),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetTab() {
    final document = widget.controller.document;
    final totals = _service.budgetTotals(document);
    final items = _visibleBudgetItems;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              _MetricCard(
                label: 'План',
                value: '${_money(totals.planned)} ${document.budgetCurrency}',
              ),
              const SizedBox(width: 8),
              _MetricCard(
                label: 'Факт',
                value: '${_money(totals.actual)} ${document.budgetCurrency}',
              ),
              const SizedBox(width: 8),
              _MetricCard(
                label: 'Оплачено',
                value: '${_money(totals.paid)} ${document.budgetCurrency}',
              ),
              const SizedBox(width: 8),
              _MetricCard(
                label: 'Задолженность',
                value:
                    '${_money(totals.outstanding)} ${document.budgetCurrency}',
                warning: totals.outstanding > 0,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Поиск по бюджету',
                  ),
                  onChanged: (value) => setState(() => _budgetQuery = value),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<BudgetCategory?>(
                  initialValue: _budgetCategoryFilter,
                  decoration: const InputDecoration(labelText: 'Категория'),
                  items: <DropdownMenuItem<BudgetCategory?>>[
                    const DropdownMenuItem<BudgetCategory?>(
                      value: null,
                      child: Text('Все категории'),
                    ),
                    ...BudgetCategory.values.map(
                      (category) => DropdownMenuItem<BudgetCategory?>(
                        value: category,
                        child: Text(category.label),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _budgetCategoryFilter = value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 105,
                child: DropdownButtonFormField<String>(
                  initialValue: document.budgetCurrency,
                  decoration: const InputDecoration(labelText: 'Валюта'),
                  items: <String>{
                    document.budgetCurrency,
                    'TJS',
                    'RUB',
                    'USD',
                    'EUR',
                  }
                      .map(
                        (currency) => DropdownMenuItem(
                          value: currency,
                          child: Text(currency),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) {
                      widget.controller.setBudgetCurrency(value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => unawaited(_addBudgetItem()),
                icon: const Icon(Icons.add),
                label: const Text('Статья'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('Статьи бюджета не найдены.'))
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final scene = item.sceneId == null
                          ? null
                          : document.sceneById(item.sceneId!);
                      final day = item.shootingDayId == null
                          ? null
                          : document.shootingDayById(item.shootingDayId!);

                      return Material(
                        color: const Color(0xFF29292D),
                        borderRadius: BorderRadius.circular(10),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: Color(0xFF3C3C43)),
                          ),
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFF3B3B42),
                            child: Icon(Icons.receipt_long_outlined),
                          ),
                          title: Text(
                            item.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            <String>[
                              item.category.label,
                              if (item.payee.isNotEmpty) item.payee,
                              if (scene != null) 'Сцена ${scene.number}',
                              if (day != null) day.title,
                            ].join(' • '),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 280,
                                child: Wrap(
                                  alignment: WrapAlignment.end,
                                  spacing: 10,
                                  children: [
                                    Text('План: ${_money(item.plannedAmount)}'),
                                    Text('Факт: ${_money(item.actualAmount)}'),
                                    Text(
                                      'Долг: ${_money(item.outstandingAmount)}',
                                      style: TextStyle(
                                        color: item.outstandingAmount > 0
                                            ? const Color(0xFFE57373)
                                            : const Color(0xFF80B980),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Редактировать',
                                onPressed: () =>
                                    unawaited(_editBudgetItem(item)),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'Удалить',
                                onPressed: () =>
                                    unawaited(_deleteBudgetItem(item)),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                          onTap: () => unawaited(_editBudgetItem(item)),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsTab() {
    final document = widget.controller.document;
    final conflicts = _service.availabilityConflicts(document);
    final categoryTotals = _service
        .budgetByCategory(document)
        .entries
        .where((entry) => entry.value.planned > 0 || entry.value.actual > 0)
        .toList(growable: false);
    final selectedDay = _selectedDayId == null
        ? null
        : document.shootingDayById(_selectedDayId!);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Экспорт документов',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                _ExportCard(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Бюджет проекта',
                  subtitle: 'План, факт, оплаты, задолженности и привязки.',
                  isBusy: _isExporting,
                  onPressed: () => unawaited(
                    _exportCsv(
                      suffix: 'budget',
                      content: _service.buildBudgetCsv(
                        document,
                        projectName: widget.projectName,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _ExportCard(
                  icon: Icons.groups_outlined,
                  title: 'Лист команды и актёров',
                  subtitle: 'Контакты, отделы, роли и доступность.',
                  isBusy: _isExporting,
                  onPressed: () => unawaited(
                    _exportCsv(
                      suffix: 'cast_crew',
                      content: _service.buildPeopleCsv(
                        document,
                        projectName: widget.projectName,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Material(
                  color: const Color(0xFF29292D),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Сводка съёмочного дня',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String?>(
                          initialValue: _selectedDayId,
                          decoration: const InputDecoration(
                              labelText: 'Съёмочный день'),
                          items: document.shootingDays
                              .map(
                                (day) => DropdownMenuItem<String?>(
                                  value: day.id,
                                  child: Text(day.title),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            setState(() => _selectedDayId = value);
                          },
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: _isExporting || selectedDay == null
                              ? null
                              : () => unawaited(
                                    _exportCsv(
                                      suffix: 'shooting_day',
                                      content: _service.buildDaySummaryCsv(
                                        document,
                                        projectName: widget.projectName,
                                        day: selectedDay,
                                      ),
                                    ),
                                  ),
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('Экспортировать сводку'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Бюджет по категориям',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: categoryTotals.isEmpty
                      ? const Center(child: Text('Бюджет пока не заполнен.'))
                      : ListView.builder(
                          itemCount: categoryTotals.length,
                          itemBuilder: (context, index) {
                            final entry = categoryTotals[index];
                            return ListTile(
                              dense: true,
                              title: Text(entry.key.label),
                              subtitle: Text(
                                'План: ${_money(entry.value.planned)} • Факт: ${_money(entry.value.actual)}',
                              ),
                              trailing: Text(
                                '${_money(entry.value.outstanding)} ${document.budgetCurrency}',
                                style: TextStyle(
                                  color: entry.value.outstanding > 0
                                      ? const Color(0xFFE57373)
                                      : const Color(0xFF80B980),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Конфликты доступности',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Chip(label: Text('${conflicts.length}')),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: conflicts.isEmpty
                      ? const Center(
                          child: Text(
                            'Конфликтов не обнаружено.\nУкажите даты съёмок и недоступности участников.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.separated(
                          itemCount: conflicts.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final conflict = conflicts[index];
                            return Material(
                              color: const Color(0xFF332A2A),
                              borderRadius: BorderRadius.circular(10),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Color(0xFFE5A93C),
                                ),
                                title: Text(conflict.person.name),
                                subtitle: Text(
                                  '${conflict.day.title} • ${conflict.day.date}\n${conflict.reasons.join(', ')}',
                                ),
                                isThreeLine: true,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _money(double value) {
    final rounded = value.roundToDouble();
    return value == rounded
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    this.warning = false,
  });

  final String label;
  final String value;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 130),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF29292D),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: warning ? const Color(0xFFE57373) : const Color(0xFF3C3C43),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF9B9BA5), fontSize: 11),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color:
                  warning ? const Color(0xFFE57373) : const Color(0xFFE5A93C),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportCard extends StatelessWidget {
  const _ExportCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isBusy,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isBusy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF29292D),
      borderRadius: BorderRadius.circular(10),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFF3C3C43)),
        ),
        leading: Icon(icon, color: const Color(0xFFE5A93C)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: IconButton(
          tooltip: 'Экспортировать',
          onPressed: isBusy ? null : onPressed,
          icon: isBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_outlined),
        ),
        onTap: isBusy ? null : onPressed,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.minLines = 1,
    this.maxLines = 1,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final int minLines;
  final int maxLines;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }
}
