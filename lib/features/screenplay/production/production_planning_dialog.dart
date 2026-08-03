import 'dart:async';

import 'package:flutter/material.dart';
import 'package:filmsoz_studio/features/screenplay/document/scene_section.dart';
import 'package:filmsoz_studio/features/screenplay/editor/controller/screenplay_editor_controller.dart';
import 'package:filmsoz_studio/features/screenplay/production/production_planning.dart';
import 'package:filmsoz_studio/features/screenplay/production/production_planning_file_service.dart';
import 'package:filmsoz_studio/features/screenplay/production/production_planning_service.dart';

class ProductionPlanningDialog extends StatefulWidget {
  const ProductionPlanningDialog({
    super.key,
    required this.controller,
    required this.projectName,
    required this.onSceneSelected,
  });

  final ScreenplayEditorController controller;
  final String projectName;
  final ValueChanged<SceneSection> onSceneSelected;

  @override
  State<ProductionPlanningDialog> createState() =>
      _ProductionPlanningDialogState();
}

class _ProductionPlanningDialogState extends State<ProductionPlanningDialog> {
  final ProductionPlanningService _service = const ProductionPlanningService();
  final ProductionPlanningFileService _fileService =
      const ProductionPlanningFileService();

  bool _isExporting = false;
  String _sceneQuery = '';

  List<SceneSection> get _visibleScenes {
    final query = _sceneQuery.trim().toLowerCase();
    final scenes = widget.controller.document.sceneSections;

    if (query.isEmpty) {
      return scenes;
    }

    return scenes.where((scene) {
      final production = widget.controller.document.sceneProductionFor(
        scene.id,
      );
      final searchable = <String>[
        scene.number.toString(),
        scene.title,
        ...production.cast,
        ...production.locations,
        ...production.props,
        production.notes,
      ].join('\n').toLowerCase();
      return searchable.contains(query);
    }).toList(growable: false);
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

  Future<void> _editBreakdown(SceneSection scene) async {
    final initial = _service.suggestedBreakdown(
      widget.controller.document,
      scene,
    );
    final castController = TextEditingController(text: initial.cast.join(', '));
    final extrasController = TextEditingController(
      text: initial.extras <= 0 ? '' : '${initial.extras}',
    );
    final locationController = TextEditingController(
      text: initial.locations.join(', '),
    );
    final propsController = TextEditingController(
      text: initial.props.join(', '),
    );
    final costumesController = TextEditingController(
      text: initial.costumes.join(', '),
    );
    final makeupController = TextEditingController(
      text: initial.makeup.join(', '),
    );
    final vehiclesController = TextEditingController(
      text: initial.vehicles.join(', '),
    );
    final equipmentController = TextEditingController(
      text: initial.specialEquipment.join(', '),
    );
    final setupController = TextEditingController(
      text: initial.estimatedSetupMinutes <= 0
          ? ''
          : '${initial.estimatedSetupMinutes}',
    );
    final shootController = TextEditingController(
      text: initial.estimatedShootMinutes <= 0
          ? ''
          : '${initial.estimatedShootMinutes}',
    );
    final notesController = TextEditingController(text: initial.notes);
    var priority = initial.priority;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF29292D),
              title: Text('Разбор сцены ${scene.number}'),
              content: SizedBox(
                width: 760,
                height: 650,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scene.title,
                        style: const TextStyle(
                          color: Color(0xFFE5A93C),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _TextField(
                        controller: castController,
                        label: 'Актёры',
                        hint: 'ФАРХОД, АННА',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _TextField(
                              controller: locationController,
                              label: 'Локации',
                              hint: 'Дом, двор',
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 170,
                            child: _TextField(
                              controller: extrasController,
                              label: 'Массовка',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _TextField(
                        controller: propsController,
                        label: 'Реквизит',
                        hint: 'Телефон, письмо, чемодан',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _TextField(
                              controller: costumesController,
                              label: 'Костюмы',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _TextField(
                              controller: makeupController,
                              label: 'Грим',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _TextField(
                              controller: vehiclesController,
                              label: 'Транспорт',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _TextField(
                              controller: equipmentController,
                              label: 'Спецоборудование',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _TextField(
                              controller: setupController,
                              label: 'Подготовка, минут',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _TextField(
                              controller: shootController,
                              label: 'Съёмка, минут',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<ProductionPriority>(
                              initialValue: priority,
                              decoration: const InputDecoration(
                                labelText: 'Приоритет',
                              ),
                              items: ProductionPriority.values
                                  .map(
                                    (value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(value.label),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (value) {
                                if (value != null) {
                                  setDialogState(() => priority = value);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _TextField(
                        controller: notesController,
                        label: 'Производственные примечания',
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
      widget.controller.setSceneProduction(
        scene.id,
        SceneProductionData(
          cast: _splitList(castController.text),
          extras: int.tryParse(extrasController.text.trim()) ?? 0,
          locations: _splitList(locationController.text),
          props: _splitList(propsController.text),
          costumes: _splitList(costumesController.text),
          makeup: _splitList(makeupController.text),
          vehicles: _splitList(vehiclesController.text),
          specialEquipment: _splitList(equipmentController.text),
          notes: notesController.text,
          estimatedSetupMinutes: int.tryParse(setupController.text.trim()) ?? 0,
          estimatedShootMinutes: int.tryParse(shootController.text.trim()) ?? 0,
          priority: priority,
        ),
      );
    }

    castController.dispose();
    extrasController.dispose();
    locationController.dispose();
    propsController.dispose();
    costumesController.dispose();
    makeupController.dispose();
    vehiclesController.dispose();
    equipmentController.dispose();
    setupController.dispose();
    shootController.dispose();
    notesController.dispose();
  }

  Future<void> _createShootingDay() async {
    final dayId = widget.controller.createShootingDay();
    final day = widget.controller.document.shootingDayById(dayId);

    if (day != null) {
      await _editShootingDay(day);
    }
  }

  Future<void> _editShootingDay(ShootingDayPlan day) async {
    final titleController = TextEditingController(text: day.title);
    final dateController = TextEditingController(text: day.date);
    final locationController = TextEditingController(text: day.location);
    final crewCallController = TextEditingController(text: day.crewCall);
    final firstShotController = TextEditingController(text: day.firstShot);
    final wrapController = TextEditingController(text: day.estimatedWrap);
    final notesController = TextEditingController(text: day.notes);
    final selectedSceneIds = day.sceneIds.toSet();
    var status = day.status;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final scenes = widget.controller.document.sceneSections;

            return AlertDialog(
              backgroundColor: const Color(0xFF29292D),
              title: const Text('Съёмочный день'),
              content: SizedBox(
                width: 820,
                height: 680,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _TextField(
                            controller: titleController,
                            label: 'Название дня',
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 170,
                          child: _TextField(
                            controller: dateController,
                            label: 'Дата',
                            hint: '2026-08-15',
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 180,
                          child: DropdownButtonFormField<ShootingDayStatus>(
                            initialValue: status,
                            decoration: const InputDecoration(
                              labelText: 'Статус',
                            ),
                            items: ShootingDayStatus.values
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(value.label),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() => status = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _TextField(
                      controller: locationController,
                      label: 'Основная локация / база',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _TextField(
                            controller: crewCallController,
                            label: 'Сбор группы',
                            hint: '07:00',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TextField(
                            controller: firstShotController,
                            label: 'Первый кадр',
                            hint: '08:00',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TextField(
                            controller: wrapController,
                            label: 'Окончание',
                            hint: '19:00',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _TextField(
                      controller: notesController,
                      label: 'Примечания дня',
                      minLines: 2,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Text(
                          'Сцены дня',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        Text('${selectedSceneIds.length} выбрано'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Material(
                        color: const Color(0xFF202024),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Color(0xFF3B3B41)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ListView.builder(
                          itemCount: scenes.length,
                          itemBuilder: (context, index) {
                            final scene = scenes[index];
                            final selected =
                                selectedSceneIds.contains(scene.id);

                            return CheckboxListTile(
                              value: selected,
                              dense: true,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(
                                '${scene.number}. ${scene.title}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                _service
                                    .suggestedBreakdown(
                                      widget.controller.document,
                                      scene,
                                    )
                                    .cast
                                    .join(', '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onChanged: (value) {
                                setDialogState(() {
                                  if (value == true) {
                                    selectedSceneIds.add(scene.id);
                                  } else {
                                    selectedSceneIds.remove(scene.id);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ],
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
      final sceneOrder = widget.controller.document.sceneSections
          .map((scene) => scene.id)
          .where(selectedSceneIds.contains)
          .toList(growable: false);
      widget.controller.updateShootingDay(
        day.copyWith(
          title: titleController.text,
          date: dateController.text,
          location: locationController.text,
          crewCall: crewCallController.text,
          firstShot: firstShotController.text,
          estimatedWrap: wrapController.text,
          sceneIds: sceneOrder,
          notes: notesController.text,
          status: status,
        ),
      );
    }

    titleController.dispose();
    dateController.dispose();
    locationController.dispose();
    crewCallController.dispose();
    firstShotController.dispose();
    wrapController.dispose();
    notesController.dispose();
  }

  Future<void> _deleteShootingDay(ShootingDayPlan day) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить съёмочный день?'),
        content: Text('«${day.title}» будет удалён из плана.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      widget.controller.deleteShootingDay(day.id);
    }
  }

  Future<void> _exportSchedule() async {
    await _exportCsv(
      suffix: 'shooting_schedule',
      build: () => _service.buildScheduleCsv(
        widget.controller.document,
        projectName: widget.projectName,
      ),
    );
  }

  Future<void> _exportCallSheet(ShootingDayPlan day) async {
    await _exportCsv(
      suffix: 'call_sheet_${day.title.replaceAll(' ', '_')}',
      build: () => _service.buildCallSheetCsv(
        widget.controller.document,
        projectName: widget.projectName,
        day: day,
      ),
    );
  }

  Future<void> _exportCsv({
    required String suffix,
    required String Function() build,
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

      if (filePath == null) {
        return;
      }

      final savedPath = await _fileService.writeCsv(filePath, build());

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Отчёт сохранён: $savedPath')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить отчёт: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      backgroundColor: const Color(0xFF1E1E22),
      child: SizedBox(
        width: 1420,
        height: 880,
        child: DefaultTabController(
          length: 3,
          child: AnimatedBuilder(
            animation: widget.controller,
            builder: (context, _) {
              return Column(
                children: [
                  _buildHeader(),
                  const Divider(height: 1, color: Color(0xFF39393E)),
                  const TabBar(
                    tabs: [
                      Tab(
                          icon: Icon(Icons.fact_check_outlined),
                          text: 'Разбор сцен'),
                      Tab(
                          icon: Icon(Icons.calendar_month_outlined),
                          text: 'Съёмочные дни'),
                      Tab(icon: Icon(Icons.summarize_outlined), text: 'Отчёты'),
                    ],
                  ),
                  const Divider(height: 1, color: Color(0xFF39393E)),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildBreakdownTab(),
                        _buildScheduleTab(),
                        _buildReportsTab(),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final summary = _service.summarize(widget.controller.document);

    return SizedBox(
      height: 62,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: [
            const Icon(Icons.movie_filter_outlined, color: Color(0xFFE5A93C)),
            const SizedBox(width: 10),
            const Text(
              'Производственное планирование',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 24),
            _HeaderMetric(
              label: 'Разобрано',
              value: '${summary.brokenDownSceneCount}/${summary.sceneCount}',
            ),
            _HeaderMetric(
              label: 'Запланировано',
              value: '${summary.scheduledSceneCount}/${summary.sceneCount}',
            ),
            _HeaderMetric(
              label: 'Съёмочных дней',
              value: '${summary.shootingDayCount}',
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Закрыть',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownTab() {
    final scenes = _visibleScenes;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Поиск по сценам, актёрам, локациям и реквизиту',
            ),
            onChanged: (value) => setState(() => _sceneQuery = value),
          ),
        ),
        Expanded(
          child: scenes.isEmpty
              ? const Center(child: Text('Сцены не найдены.'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                  itemCount: scenes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final scene = scenes[index];
                    final data = _service.suggestedBreakdown(
                      widget.controller.document,
                      scene,
                    );
                    final stored =
                        widget.controller.document.sceneProduction[scene.id];

                    return Card(
                      color: const Color(0xFF29292D),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: stored == null
                              ? const Color(0xFF4A4A50)
                              : const Color(0xFFE5A93C),
                          foregroundColor:
                              stored == null ? Colors.white : Colors.black,
                          child: Text('${scene.number}'),
                        ),
                        title: Text(
                          scene.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            <String>[
                              if (data.locations.isNotEmpty)
                                'Локация: ${data.locations.join(', ')}',
                              if (data.cast.isNotEmpty)
                                'Актёры: ${data.cast.join(', ')}',
                              'Подготовка ${data.estimatedSetupMinutes} мин • съёмка ${data.estimatedShootMinutes} мин',
                            ].join('  |  '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: 'Открыть сцену',
                              onPressed: () => widget.onSceneSelected(scene),
                              icon: const Icon(Icons.open_in_new, size: 19),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: () => unawaited(_editBreakdown(scene)),
                              icon: const Icon(Icons.edit_note, size: 18),
                              label: Text(
                                  stored == null ? 'Разобрать' : 'Изменить'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildScheduleTab() {
    final days = widget.controller.document.shootingDays;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Text(
                'Съёмочные дни: ${days.length}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => unawaited(_createShootingDay()),
                icon: const Icon(Icons.add),
                label: const Text('Добавить день'),
              ),
            ],
          ),
        ),
        Expanded(
          child: days.isEmpty
              ? const Center(
                  child: Text('Создайте первый съёмочный день.'),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                  itemCount: days.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final day = days[index];
                    final cast = _service.castForDay(
                      widget.controller.document,
                      day,
                    );
                    final estimatedMinutes = _service.estimatedMinutesForDay(
                      widget.controller.document,
                      day,
                    );

                    return Card(
                      color: const Color(0xFF29292D),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              child: Text('${index + 1}'),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    day.title,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    <String>[
                                      if (day.date.isNotEmpty) day.date,
                                      day.status.label,
                                      '${day.sceneIds.length} сцен',
                                      '$estimatedMinutes мин',
                                      if (day.location.isNotEmpty) day.location,
                                    ].join(' • '),
                                  ),
                                  if (cast.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Актёры: ${cast.join(', ')}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFFAAAAAF),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Выше',
                              onPressed: index == 0
                                  ? null
                                  : () => widget.controller.moveShootingDay(
                                        day.id,
                                        -1,
                                      ),
                              icon: const Icon(Icons.arrow_upward),
                            ),
                            IconButton(
                              tooltip: 'Ниже',
                              onPressed: index == days.length - 1
                                  ? null
                                  : () => widget.controller.moveShootingDay(
                                        day.id,
                                        1,
                                      ),
                              icon: const Icon(Icons.arrow_downward),
                            ),
                            IconButton(
                              tooltip: 'Лист вызова',
                              onPressed: day.sceneIds.isEmpty || _isExporting
                                  ? null
                                  : () => unawaited(_exportCallSheet(day)),
                              icon: const Icon(Icons.assignment_outlined),
                            ),
                            IconButton(
                              tooltip: 'Изменить',
                              onPressed: () => unawaited(_editShootingDay(day)),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Удалить',
                              onPressed: () =>
                                  unawaited(_deleteShootingDay(day)),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildReportsTab() {
    final document = widget.controller.document;
    final summary = _service.summarize(document);
    final unassigned = _service.unassignedSceneIds(document);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Сводка производства',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SummaryCard(
                label: 'Сцен',
                value: '${summary.sceneCount}',
                icon: Icons.movie_outlined,
              ),
              _SummaryCard(
                label: 'Разобрано',
                value: '${summary.brokenDownSceneCount}',
                icon: Icons.fact_check_outlined,
              ),
              _SummaryCard(
                label: 'Запланировано',
                value: '${summary.scheduledSceneCount}',
                icon: Icons.event_available_outlined,
              ),
              _SummaryCard(
                label: 'Без даты',
                value: '${unassigned.length}',
                icon: Icons.event_busy_outlined,
              ),
              _SummaryCard(
                label: 'Подготовка',
                value: '${summary.totalSetupMinutes} мин',
                icon: Icons.build_outlined,
              ),
              _SummaryCard(
                label: 'Съёмка',
                value: '${summary.totalShootMinutes} мин',
                icon: Icons.videocam_outlined,
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Text(
            'Экспорт',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: document.shootingDays.isEmpty || _isExporting
                ? null
                : () => unawaited(_exportSchedule()),
            icon: _isExporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.table_view_outlined),
            label: const Text('Экспорт календарного плана CSV'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Лист вызова отдельного дня экспортируется кнопкой с иконкой документа в разделе «Съёмочные дни».',
            style: TextStyle(color: Color(0xFFAAAAAF)),
          ),
          if (unassigned.isNotEmpty) ...[
            const SizedBox(height: 28),
            const Text(
              'Незапланированные сцены',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            ...unassigned.map((sceneId) {
              final scene = document.sceneById(sceneId)!;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Text('${scene.number}')),
                title: Text(scene.title),
                trailing: TextButton(
                  onPressed: () => widget.onSceneSelected(scene),
                  child: const Text('Открыть'),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF9B9BA1), fontSize: 10),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF29292D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF3B3B41)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFE5A93C)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Color(0xFFAAAAAF), fontSize: 11),
              ),
              Text(
                value,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
