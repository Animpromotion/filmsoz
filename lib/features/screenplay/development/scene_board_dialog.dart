import 'dart:async';

import 'package:flutter/material.dart';
import 'package:filmsoz_studio/features/screenplay/development/production_report_file_service.dart';
import 'package:filmsoz_studio/features/screenplay/development/scene_development.dart';
import 'package:filmsoz_studio/features/screenplay/development/screenplay_development_service.dart';
import 'package:filmsoz_studio/features/screenplay/document/scene_section.dart';
import 'package:filmsoz_studio/features/screenplay/editor/controller/screenplay_editor_controller.dart';

class SceneBoardDialog extends StatefulWidget {
  const SceneBoardDialog({
    super.key,
    required this.controller,
    required this.projectName,
    required this.onSceneSelected,
  });

  final ScreenplayEditorController controller;
  final String projectName;
  final ValueChanged<SceneSection> onSceneSelected;

  @override
  State<SceneBoardDialog> createState() => _SceneBoardDialogState();
}

class _SceneBoardDialogState extends State<SceneBoardDialog> {
  final ScreenplayDevelopmentService _service =
      const ScreenplayDevelopmentService();
  final ProductionReportFileService _reportFileService =
      const ProductionReportFileService();
  final TextEditingController _searchController = TextEditingController();

  bool _boardView = true;
  SceneWorkStatus? _statusFilter;
  SceneColorTag? _colorFilter;
  String? _characterFilter;
  String? _locationFilter;
  bool _isExporting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SceneSection> _filteredScenes() {
    return _service.filterScenes(
      widget.controller.document,
      query: _searchController.text,
      status: _statusFilter,
      colorTag: _colorFilter,
      character: _characterFilter,
      location: _locationFilter,
    );
  }

  bool get _hasFilters =>
      _searchController.text.trim().isNotEmpty ||
      _statusFilter != null ||
      _colorFilter != null ||
      _characterFilter != null ||
      _locationFilter != null;

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _statusFilter = null;
      _colorFilter = null;
      _characterFilter = null;
      _locationFilter = null;
    });
  }

  void _reorderVisibleScenes(
    int oldIndex,
    int newIndex,
    List<SceneSection> visibleScenes,
  ) {
    if (visibleScenes.length < 2) {
      return;
    }

    var destinationIndex = newIndex;

    if (destinationIndex > oldIndex) {
      destinationIndex--;
    }

    if (destinationIndex == oldIndex) {
      return;
    }

    final reordered = List<SceneSection>.of(visibleScenes);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(destinationIndex, moved);

    if (destinationIndex == 0) {
      widget.controller.moveSceneRelativeToTarget(
        sceneId: moved.id,
        targetSceneId: reordered[1].id,
        placeAfter: false,
      );
    } else {
      widget.controller.moveSceneRelativeToTarget(
        sceneId: moved.id,
        targetSceneId: reordered[destinationIndex - 1].id,
        placeAfter: true,
      );
    }
  }

  Future<void> _editScene(SceneSection scene) async {
    final current = widget.controller.document.sceneDevelopmentFor(scene.id);
    final summaryController = TextEditingController(text: current.summary);
    var status = current.status;
    var colorTag = current.colorTag;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF29292D),
              title: Text(
                '${scene.number}. ${scene.title}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: summaryController,
                      autofocus: true,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Краткое описание сцены',
                        hintText: 'Что происходит и зачем нужна эта сцена?',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<SceneWorkStatus>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: 'Статус'),
                      items: SceneWorkStatus.values
                          .map(
                            (value) => DropdownMenuItem<SceneWorkStatus>(
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
                    const SizedBox(height: 12),
                    DropdownButtonFormField<SceneColorTag>(
                      initialValue: colorTag,
                      decoration: const InputDecoration(
                        labelText: 'Сюжетная линия',
                      ),
                      items: SceneColorTag.values
                          .map(
                            (value) => DropdownMenuItem<SceneColorTag>(
                              value: value,
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: _sceneColor(value),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF77777D),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(value.label),
                                ],
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => colorTag = value);
                        }
                      },
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
      widget.controller.setSceneDevelopment(
        scene.id,
        summary: summaryController.text,
        status: status,
        colorTag: colorTag,
      );
    }

    summaryController.dispose();
  }

  Future<void> _editGoals() async {
    final goals = widget.controller.document.goals;
    final scenesController = TextEditingController(
      text: goals.targetSceneCount <= 0 ? '' : '${goals.targetSceneCount}',
    );
    final pagesController = TextEditingController(
      text: goals.targetPageCount <= 0 ? '' : '${goals.targetPageCount}',
    );
    final minutesController = TextEditingController(
      text: goals.targetMinutes <= 0 ? '' : '${goals.targetMinutes}',
    );

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF29292D),
          title: const Text('Цели сценария'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _GoalField(
                  controller: scenesController,
                  label: 'Цель по количеству сцен',
                ),
                const SizedBox(height: 12),
                _GoalField(
                  controller: pagesController,
                  label: 'Цель по количеству страниц',
                ),
                const SizedBox(height: 12),
                _GoalField(
                  controller: minutesController,
                  label: 'Цель по хронометражу, минут',
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

    if (shouldSave == true) {
      widget.controller.setScreenplayGoals(
        ScreenplayGoals(
          targetSceneCount: int.tryParse(scenesController.text.trim()) ?? 0,
          targetPageCount: int.tryParse(pagesController.text.trim()) ?? 0,
          targetMinutes: int.tryParse(minutesController.text.trim()) ?? 0,
        ),
      );
    }

    scenesController.dispose();
    pagesController.dispose();
    minutesController.dispose();
  }

  Future<void> _exportReport() async {
    if (_isExporting) {
      return;
    }

    setState(() => _isExporting = true);

    try {
      final filePath = await _reportFileService.chooseSavePath(
        suggestedName: widget.projectName,
      );

      if (filePath == null) {
        return;
      }

      final csv = _service.buildProductionReportCsv(
        widget.controller.document,
        projectName: widget.projectName,
      );
      final savedPath = await _reportFileService.writeReport(filePath, csv);

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
        SnackBar(content: Text('Не удалось экспортировать отчёт: $error')),
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
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final document = widget.controller.document;
            final visibleScenes = _filteredScenes();
            final characters = _service.characterReport(document);
            final locations = _service.locationReport(document);

            if (_characterFilter != null &&
                !characters.any((item) => item.name == _characterFilter)) {
              _characterFilter = null;
            }

            if (_locationFilter != null &&
                !locations.any((item) => item.location == _locationFilter)) {
              _locationFilter = null;
            }

            return Column(
              children: [
                _buildHeader(
                    visibleScenes.length, document.sceneSections.length),
                const Divider(height: 1, color: Color(0xFF39393E)),
                _buildFilters(characters, locations),
                const Divider(height: 1, color: Color(0xFF39393E)),
                Expanded(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 292,
                        child: _DevelopmentSummaryPanel(
                          controller: widget.controller,
                          service: _service,
                          onEditGoals: () => unawaited(_editGoals()),
                          onExportReport: () => unawaited(_exportReport()),
                          isExporting: _isExporting,
                        ),
                      ),
                      const VerticalDivider(
                        width: 1,
                        color: Color(0xFF39393E),
                      ),
                      Expanded(
                        child: visibleScenes.isEmpty
                            ? _EmptyBoard(hasFilters: _hasFilters)
                            : _boardView
                                ? _buildBoard(visibleScenes)
                                : _buildList(visibleScenes),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(int visibleCount, int totalCount) {
    return SizedBox(
      height: 58,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const Icon(Icons.view_kanban_outlined, color: Color(0xFFE5A93C)),
            const SizedBox(width: 10),
            const Text(
              'СТРУКТУРА ФИЛЬМА',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              visibleCount == totalCount
                  ? '$totalCount сцен'
                  : '$visibleCount из $totalCount сцен',
              style: const TextStyle(color: Color(0xFF9B9BA4), fontSize: 12),
            ),
            const Spacer(),
            SegmentedButton<bool>(
              segments: const <ButtonSegment<bool>>[
                ButtonSegment<bool>(
                  value: true,
                  icon: Icon(Icons.view_kanban_outlined, size: 17),
                  label: Text('Карточки'),
                ),
                ButtonSegment<bool>(
                  value: false,
                  icon: Icon(Icons.view_list_outlined, size: 17),
                  label: Text('Список'),
                ),
              ],
              selected: <bool>{_boardView},
              onSelectionChanged: (values) {
                setState(() => _boardView = values.first);
              },
              showSelectedIcon: false,
            ),
            const SizedBox(width: 12),
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

  Widget _buildFilters(
    List<CharacterDevelopmentStat> characters,
    List<LocationDevelopmentStat> locations,
  ) {
    return Container(
      constraints: const BoxConstraints(minHeight: 62),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: const Color(0xFF25252A),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 250,
            height: 38,
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Поиск по сценам...',
                prefixIcon: Icon(Icons.search, size: 18),
                isDense: true,
              ),
            ),
          ),
          _FilterDropdown<SceneWorkStatus>(
            width: 160,
            value: _statusFilter,
            hint: 'Все статусы',
            items: SceneWorkStatus.values,
            label: (value) => value.label,
            onChanged: (value) => setState(() => _statusFilter = value),
          ),
          _FilterDropdown<SceneColorTag>(
            width: 175,
            value: _colorFilter,
            hint: 'Все линии',
            items: SceneColorTag.values
                .where((value) => value != SceneColorTag.none)
                .toList(growable: false),
            label: (value) => value.label,
            onChanged: (value) => setState(() => _colorFilter = value),
          ),
          _FilterDropdown<String>(
            width: 170,
            value: _characterFilter,
            hint: 'Все персонажи',
            items: characters.map((item) => item.name).toList(growable: false),
            label: (value) => value,
            onChanged: (value) => setState(() => _characterFilter = value),
          ),
          _FilterDropdown<String>(
            width: 180,
            value: _locationFilter,
            hint: 'Все локации',
            items:
                locations.map((item) => item.location).toList(growable: false),
            label: (value) => value,
            onChanged: (value) => setState(() => _locationFilter = value),
          ),
          if (_hasFilters)
            TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.filter_alt_off_outlined, size: 17),
              label: const Text('Сбросить'),
            ),
        ],
      ),
    );
  }

  Widget _buildBoard(List<SceneSection> scenes) {
    return ReorderableListView.builder(
      scrollDirection: Axis.horizontal,
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.all(18),
      itemExtent: 304,
      itemCount: scenes.length,
      onReorder: (oldIndex, newIndex) {
        _reorderVisibleScenes(oldIndex, newIndex, scenes);
      },
      proxyDecorator: (child, index, animation) {
        return Material(
          color: Colors.transparent,
          elevation: 10,
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final scene = scenes[index];
        return Padding(
          key: ValueKey<String>('board-${scene.id}'),
          padding: const EdgeInsets.only(right: 14),
          child: _SceneDevelopmentCard(
            scene: scene,
            data: widget.controller.document.sceneDevelopmentFor(scene.id),
            service: _service,
            dragHandle: ReorderableDragStartListener(
              index: index,
              child: const Tooltip(
                message: 'Перетащить сцену',
                child: Icon(Icons.drag_indicator, size: 19),
              ),
            ),
            onOpen: () {
              widget.onSceneSelected(scene);
              Navigator.of(context).pop();
            },
            onEdit: () => unawaited(_editScene(scene)),
          ),
        );
      },
    );
  }

  Widget _buildList(List<SceneSection> scenes) {
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.all(16),
      itemCount: scenes.length,
      onReorder: (oldIndex, newIndex) {
        _reorderVisibleScenes(oldIndex, newIndex, scenes);
      },
      itemBuilder: (context, index) {
        final scene = scenes[index];
        final metadata =
            widget.controller.document.sceneDevelopmentFor(scene.id);

        return _SceneDevelopmentListTile(
          key: ValueKey<String>('list-${scene.id}'),
          scene: scene,
          data: metadata,
          service: _service,
          dragHandle: ReorderableDragStartListener(
            index: index,
            child: const Tooltip(
              message: 'Перетащить сцену',
              child: Icon(Icons.drag_indicator, size: 19),
            ),
          ),
          onOpen: () {
            widget.onSceneSelected(scene);
            Navigator.of(context).pop();
          },
          onEdit: () => unawaited(_editScene(scene)),
        );
      },
    );
  }
}

class _SceneDevelopmentCard extends StatelessWidget {
  const _SceneDevelopmentCard({
    required this.scene,
    required this.data,
    required this.service,
    required this.dragHandle,
    required this.onOpen,
    required this.onEdit,
  });

  final SceneSection scene;
  final SceneDevelopmentData data;
  final ScreenplayDevelopmentService service;
  final Widget dragHandle;
  final VoidCallback onOpen;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final characters = service.charactersForScene(scene);
    final color = _sceneColor(data.colorTag);

    return Card(
      margin: EdgeInsets.zero,
      color: const Color(0xFF29292E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: data.colorTag == SceneColorTag.none
              ? const Color(0xFF414147)
              : color,
          width: data.colorTag == SceneColorTag.none ? 1 : 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onDoubleTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  dragHandle,
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5A93C).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'СЦЕНА ${scene.number}',
                      style: const TextStyle(
                        color: Color(0xFFE5A93C),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Редактировать карточку',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                scene.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                data.summary.trim().isEmpty
                    ? 'Добавьте краткое описание сцены.'
                    : data.summary,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: data.summary.trim().isEmpty
                      ? const Color(0xFF777780)
                      : const Color(0xFFC9C9D0),
                  fontSize: 12,
                  height: 1.4,
                  fontStyle: data.summary.trim().isEmpty
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
              ),
              const Spacer(),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _StatusChip(status: data.status),
                  _InfoChip(
                    icon: Icons.schedule_outlined,
                    label:
                        '${service.estimatedMinutesForScene(scene).toStringAsFixed(1)} мин',
                  ),
                  _InfoChip(
                    icon: Icons.notes_outlined,
                    label: '${scene.wordCount} слов',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                service.locationForScene(scene),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF9D9DA7),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                characters.isEmpty ? 'Персонажи: —' : characters.join(', '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF868690),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Открыть в сценарии'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SceneDevelopmentListTile extends StatelessWidget {
  const _SceneDevelopmentListTile({
    super.key,
    required this.scene,
    required this.data,
    required this.service,
    required this.dragHandle,
    required this.onOpen,
    required this.onEdit,
  });

  final SceneSection scene;
  final SceneDevelopmentData data;
  final ScreenplayDevelopmentService service;
  final Widget dragHandle;
  final VoidCallback onOpen;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final color = _sceneColor(data.colorTag);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: const Color(0xFF29292E),
      child: InkWell(
        onDoubleTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              dragHandle,
              const SizedBox(width: 8),
              Container(
                width: 5,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 48,
                child: Text(
                  '${scene.number}',
                  style: const TextStyle(
                    color: Color(0xFFE5A93C),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scene.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.summary.trim().isEmpty
                          ? 'Описание не добавлено'
                          : data.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF96969F),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 160,
                child: Text(
                  service.locationForScene(scene),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              SizedBox(
                width: 120,
                child: _StatusChip(status: data.status),
              ),
              SizedBox(
                width: 100,
                child: Text(
                  '${service.estimatedMinutesForScene(scene).toStringAsFixed(1)} мин',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              IconButton(
                tooltip: 'Редактировать карточку',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
              ),
              IconButton(
                tooltip: 'Открыть в сценарии',
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DevelopmentSummaryPanel extends StatelessWidget {
  const _DevelopmentSummaryPanel({
    required this.controller,
    required this.service,
    required this.onEditGoals,
    required this.onExportReport,
    required this.isExporting,
  });

  final ScreenplayEditorController controller;
  final ScreenplayDevelopmentService service;
  final VoidCallback onEditGoals;
  final VoidCallback onExportReport;
  final bool isExporting;

  @override
  Widget build(BuildContext context) {
    final document = controller.document;
    final summary = service.summarize(document);
    final goals = document.goals;
    final characters = service.characterReport(document);
    final locations = service.locationReport(document);

    return ColoredBox(
      color: const Color(0xFF232328),
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          const Text(
            'ПРОГРЕСС',
            style: TextStyle(
              color: Color(0xFF9B9BA4),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          _MetricTile(
            label: 'Сцены',
            value: '${summary.sceneCount}',
            target: goals.targetSceneCount,
            current: summary.sceneCount.toDouble(),
          ),
          _MetricTile(
            label: 'Страницы, оценка',
            value: summary.estimatedPages.toStringAsFixed(1),
            target: goals.targetPageCount,
            current: summary.estimatedPages,
          ),
          _MetricTile(
            label: 'Хронометраж, оценка',
            value: '${summary.estimatedMinutes.toStringAsFixed(1)} мин',
            target: goals.targetMinutes,
            current: summary.estimatedMinutes,
          ),
          _MetricTile(
            label: 'Готовые сцены',
            value: '${summary.readySceneCount}/${summary.sceneCount}',
            target: summary.sceneCount,
            current: summary.readySceneCount.toDouble(),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onEditGoals,
            icon: const Icon(Icons.flag_outlined, size: 17),
            label: const Text('Изменить цели'),
          ),
          const SizedBox(height: 18),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: Text('ПЕРСОНАЖИ (${characters.length})'),
            children: [
              for (final stat in characters.take(12))
                _ReportLine(
                  title: stat.name,
                  value:
                      '${stat.sceneCount} сцен • ${stat.dialogueCount} реплик',
                ),
              if (characters.isEmpty)
                const _ReportLine(title: 'Нет данных', value: '—'),
            ],
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: Text('ЛОКАЦИИ (${locations.length})'),
            children: [
              for (final stat in locations.take(12))
                _ReportLine(
                  title: stat.location,
                  value:
                      '${stat.sceneCount} сцен • ${stat.estimatedMinutes.toStringAsFixed(1)} мин',
                ),
              if (locations.isEmpty)
                const _ReportLine(title: 'Нет данных', value: '—'),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: isExporting ? null : onExportReport,
            icon: isExporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.table_view_outlined, size: 17),
            label: Text(isExporting ? 'Экспорт...' : 'Производственный отчёт'),
          ),
          const SizedBox(height: 8),
          const Text(
            'CSV открывается в Excel и сохраняет кириллицу.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF7F7F88), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.target,
    required this.current,
  });

  final String label;
  final String value;
  final int target;
  final double current;

  @override
  Widget build(BuildContext context) {
    final progress = target <= 0 ? null : (current / target).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style:
                      const TextStyle(color: Color(0xFF9C9CA5), fontSize: 11),
                ),
              ),
              Text(
                target <= 0 ? value : '$value / $target',
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReportLine extends StatelessWidget {
  const _ReportLine({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(color: Color(0xFF8C8C95), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _GoalField extends StatelessWidget {
  const _GoalField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        hintText: '0 — без цели',
      ),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.width,
    required this.value,
    required this.hint,
    required this.items,
    required this.label,
    required this.onChanged,
  });

  final double width;
  final T? value;
  final String hint;
  final List<T> items;
  final String Function(T value) label;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 38,
      child: DropdownButtonFormField<T>(
        key: ValueKey<Object?>(value),
        initialValue: value,
        isExpanded: true,
        decoration: const InputDecoration(isDense: true),
        hint: Text(hint, overflow: TextOverflow.ellipsis),
        items: <DropdownMenuItem<T>>[
          DropdownMenuItem<T>(
            value: null,
            child: Text(hint, overflow: TextOverflow.ellipsis),
          ),
          ...items.map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(label(item), overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final SceneWorkStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      SceneWorkStatus.draft => const Color(0xFF85858E),
      SceneWorkStatus.inProgress => const Color(0xFF4F8FD8),
      SceneWorkStatus.revise => const Color(0xFFE29A43),
      SceneWorkStatus.ready => const Color(0xFF5CB87A),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        status.label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF34343A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFFAAAAAE)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Color(0xFFB8B8BE), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _EmptyBoard extends StatelessWidget {
  const _EmptyBoard({required this.hasFilters});

  final bool hasFilters;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.view_kanban_outlined,
            size: 54,
            color: Color(0xFF5D5D65),
          ),
          const SizedBox(height: 14),
          Text(
            hasFilters
                ? 'По фильтрам ничего не найдено'
                : 'В сценарии нет сцен',
            style: const TextStyle(color: Color(0xFF9A9AA3)),
          ),
        ],
      ),
    );
  }
}

Color _sceneColor(SceneColorTag tag) {
  return switch (tag) {
    SceneColorTag.none => const Color(0xFF55555D),
    SceneColorTag.red => const Color(0xFFD55C5C),
    SceneColorTag.orange => const Color(0xFFE08B45),
    SceneColorTag.yellow => const Color(0xFFD9B84C),
    SceneColorTag.green => const Color(0xFF58B977),
    SceneColorTag.blue => const Color(0xFF568FD8),
    SceneColorTag.purple => const Color(0xFF9A6AD6),
  };
}
