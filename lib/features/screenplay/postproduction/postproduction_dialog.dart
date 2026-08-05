import 'dart:async';

import 'package:flutter/material.dart';
import 'package:filmsoz_studio/features/screenplay/document/scene_section.dart';
import 'package:filmsoz_studio/features/screenplay/editor/controller/screenplay_editor_controller.dart';
import 'package:filmsoz_studio/features/screenplay/postproduction/postproduction.dart';
import 'package:filmsoz_studio/features/screenplay/postproduction/postproduction_file_service.dart';
import 'package:filmsoz_studio/features/screenplay/postproduction/postproduction_pdf_service.dart';
import 'package:filmsoz_studio/features/screenplay/postproduction/postproduction_service.dart';
import 'package:filmsoz_studio/features/screenplay/shooting_control/shooting_control.dart';

class PostProductionDialog extends StatefulWidget {
  const PostProductionDialog({
    super.key,
    required this.controller,
    required this.projectName,
    required this.onSceneSelected,
  });

  final ScreenplayEditorController controller;
  final String projectName;
  final ValueChanged<SceneSection> onSceneSelected;

  @override
  State<PostProductionDialog> createState() => _PostProductionDialogState();
}

class _PostProductionDialogState extends State<PostProductionDialog> {
  final PostProductionService _service = const PostProductionService();
  final PostProductionFileService _fileService =
      const PostProductionFileService();
  final PostProductionPdfService _pdfService = PostProductionPdfService();

  String _sceneQuery = '';
  String _taskQuery = '';
  String _missingQuery = '';
  PostSceneStatus? _sceneStatusFilter;
  PostTaskDepartment? _taskDepartmentFilter;
  PostTaskStatus? _taskStatusFilter;
  MissingMaterialStatus? _missingStatusFilter;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  List<SceneSection> get _visibleScenes {
    final query = _sceneQuery.trim().toLowerCase();

    return widget.controller.document.sceneSections.where((scene) {
      final data = widget.controller.document.scenePostProductionFor(scene.id);

      if (_sceneStatusFilter != null && data.status != _sceneStatusFilter) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      return <String>[
        '${scene.number}',
        scene.title,
        data.status.label,
        data.editorNotes,
        data.directorNotes,
      ].join('\n').toLowerCase().contains(query);
    }).toList(growable: false);
  }

  List<PostProductionTask> get _visibleTasks {
    final query = _taskQuery.trim().toLowerCase();
    final tasks = widget.controller.document.postProductionTasks.where((task) {
      if (_taskDepartmentFilter != null &&
          task.department != _taskDepartmentFilter) {
        return false;
      }

      if (_taskStatusFilter != null && task.status != _taskStatusFilter) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      return <String>[
        task.title,
        task.department.label,
        task.status.label,
        task.priority.label,
        task.assignee,
        task.dueDate,
        task.notes,
      ].join('\n').toLowerCase().contains(query);
    }).toList(growable: false);

    tasks.sort((first, second) {
      final priorityCompare = second.priority.index.compareTo(
        first.priority.index,
      );
      if (priorityCompare != 0) {
        return priorityCompare;
      }
      return first.title.toLowerCase().compareTo(second.title.toLowerCase());
    });
    return tasks;
  }

  List<MissingMaterialItem> get _visibleMissingMaterials {
    final query = _missingQuery.trim().toLowerCase();
    final items = widget.controller.document.missingMaterials.where((item) {
      if (_missingStatusFilter != null && item.status != _missingStatusFilter) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      return <String>[
        item.title,
        item.type.label,
        item.status.label,
        item.description,
        item.scheduledDate,
        item.assignee,
      ].join('\n').toLowerCase().contains(query);
    }).toList(growable: false);

    items.sort((first, second) {
      final statusCompare = first.status.index.compareTo(second.status.index);
      if (statusCompare != 0) {
        return statusCompare;
      }
      return first.title.toLowerCase().compareTo(second.title.toLowerCase());
    });
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final summary = _service.summarize(widget.controller.document);

    return Dialog(
      insetPadding: const EdgeInsets.all(22),
      backgroundColor: const Color(0xFF202024),
      child: SizedBox(
        width: 1240,
        height: 820,
        child: DefaultTabController(
          length: 6,
          child: Column(
            children: <Widget>[
              _buildHeader(summary),
              const Divider(height: 1),
              const TabBar(
                isScrollable: true,
                tabs: <Tab>[
                  Tab(icon: Icon(Icons.dashboard_outlined), text: 'Обзор'),
                  Tab(icon: Icon(Icons.movie_filter_outlined), text: 'Сцены'),
                  Tab(
                      icon: Icon(Icons.video_library_outlined),
                      text: 'Эпизоды и версии'),
                  Tab(icon: Icon(Icons.task_alt_outlined), text: 'Задачи'),
                  Tab(
                      icon: Icon(Icons.warning_amber_outlined),
                      text: 'Материал'),
                  Tab(icon: Icon(Icons.download_outlined), text: 'Экспорт'),
                ],
              ),
              const Divider(height: 1),
              Expanded(
                child: TabBarView(
                  children: <Widget>[
                    _buildOverview(summary),
                    _buildScenesTab(),
                    _buildSequencesAndVersionsTab(),
                    _buildTasksTab(),
                    _buildMissingMaterialsTab(),
                    _buildExportTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(PostProductionSummary summary) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: <Widget>[
          const Icon(Icons.edit_note_rounded,
              color: Color(0xFFE5A93C), size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Постпродакшн и контроль монтажа',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                Text(
                  '${widget.projectName} • Общая готовность ${summary.overallProgress.toStringAsFixed(0)}%',
                  style:
                      const TextStyle(color: Color(0xFF9A9AA2), fontSize: 12),
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
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            label: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Widget _buildOverview(PostProductionSummary summary) {
    final statuses = <PostSceneStatus, int>{
      for (final status in PostSceneStatus.values) status: 0,
    };
    for (final scene in widget.controller.document.sceneSections) {
      final status =
          widget.controller.document.scenePostProductionFor(scene.id).status;
      statuses[status] = (statuses[status] ?? 0) + 1;
    }

    final departments = <PostTaskDepartment, int>{
      for (final department in PostTaskDepartment.values) department: 0,
    };
    for (final task in widget.controller.document.postProductionTasks) {
      if (task.status != PostTaskStatus.done) {
        departments[task.department] = (departments[task.department] ?? 0) + 1;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _MetricCard(
                icon: Icons.percent,
                label: 'Общая готовность',
                value: '${summary.overallProgress.toStringAsFixed(0)}%',
              ),
              _MetricCard(
                icon: Icons.movie_outlined,
                label: 'Готовые сцены',
                value: '${summary.readySceneCount}/${summary.sceneCount}',
              ),
              _MetricCard(
                icon: Icons.task_alt,
                label: 'Выполненные задачи',
                value: '${summary.completedTaskCount}/${summary.taskCount}',
              ),
              _MetricCard(
                icon: Icons.event_busy_outlined,
                label: 'Просрочено',
                value: '${summary.overdueTaskCount}',
                isWarning: summary.overdueTaskCount > 0,
              ),
              _MetricCard(
                icon: Icons.warning_amber_outlined,
                label: 'Не хватает материала',
                value: '${summary.openMissingMaterialCount}',
                isWarning: summary.openMissingMaterialCount > 0,
              ),
              _MetricCard(
                icon: Icons.history,
                label: 'Текущие версии',
                value: '${summary.currentVersionCount}',
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Статусы сцен',
            child: Column(
              children: statuses.entries.map((entry) {
                final total = summary.sceneCount == 0 ? 1 : summary.sceneCount;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: <Widget>[
                      SizedBox(width: 130, child: Text(entry.key.label)),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: entry.value / total,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(width: 36, child: Text('${entry.value}')),
                    ],
                  ),
                );
              }).toList(growable: false),
            ),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Открытые задачи по отделам',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: departments.entries
                  .where((entry) => entry.value > 0)
                  .map(
                    (entry) => Chip(
                      avatar: const Icon(Icons.circle, size: 10),
                      label: Text('${entry.key.label}: ${entry.value}'),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScenesTab() {
    final scenes = _visibleScenes;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  onChanged: (value) => setState(() => _sceneQuery = value),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Поиск по сценам и заметкам',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 210,
                child: DropdownButtonFormField<PostSceneStatus?>(
                  initialValue: _sceneStatusFilter,
                  decoration: const InputDecoration(labelText: 'Статус'),
                  items: <DropdownMenuItem<PostSceneStatus?>>[
                    const DropdownMenuItem<PostSceneStatus?>(
                      value: null,
                      child: Text('Все статусы'),
                    ),
                    ...PostSceneStatus.values.map(
                      (status) => DropdownMenuItem<PostSceneStatus?>(
                        value: status,
                        child: Text(status.label),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _sceneStatusFilter = value),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: scenes.isEmpty
              ? const Center(child: Text('Сцены не найдены.'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: scenes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final scene = scenes[index];
                    final data = widget.controller.document
                        .scenePostProductionFor(scene.id);
                    return Material(
                      color: const Color(0xFF29292D),
                      borderRadius: BorderRadius.circular(10),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Color(0xFF3C3C43)),
                        ),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFE5A93C),
                          foregroundColor: const Color(0xFF211A0D),
                          child: Text('${scene.number}'),
                        ),
                        title: Text(scene.title),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '${data.status.label} • ${data.progress}% • '
                                'Дублей в монтаже: ${data.selectedTakeIds.length}',
                              ),
                              const SizedBox(height: 6),
                              LinearProgressIndicator(
                                value: data.progress / 100,
                                minHeight: 7,
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ],
                          ),
                        ),
                        trailing: Wrap(
                          spacing: 2,
                          children: <Widget>[
                            IconButton(
                              tooltip: 'Перейти к сцене',
                              onPressed: () {
                                widget.onSceneSelected(scene);
                                Navigator.of(context).pop();
                              },
                              icon: const Icon(Icons.open_in_new),
                            ),
                            IconButton(
                              tooltip: 'Редактировать постпродакшн сцены',
                              onPressed: () => unawaited(_editScene(scene)),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                          ],
                        ),
                        onTap: () => unawaited(_editScene(scene)),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSequencesAndVersionsTab() {
    final sequences = widget.controller.document.postProductionSequences;
    final versions = widget.controller.document.editVersions;

    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            children: <Widget>[
              _ListHeader(
                title: 'Монтажные эпизоды',
                buttonLabel: 'Добавить эпизод',
                onPressed: () {
                  final id = widget.controller.createPostProductionSequence();
                  final item =
                      widget.controller.document.postProductionSequenceById(id);
                  if (item != null) {
                    unawaited(_editSequence(item));
                  }
                },
              ),
              Expanded(
                child: sequences.isEmpty
                    ? const Center(child: Text('Монтажные эпизоды не созданы.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: sequences.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final sequence = sequences[index];
                          return _ActionListTile(
                            icon: Icons.video_collection_outlined,
                            title: sequence.title,
                            subtitle:
                                'Сцен: ${sequence.sceneIds.length} • Версий: ${versions.where((v) => v.sequenceId == sequence.id).length}',
                            onTap: () => unawaited(_editSequence(sequence)),
                            onDelete: () => _confirmDelete(
                              title: 'Удалить монтажный эпизод?',
                              message:
                                  'Версии сохранятся, но потеряют привязку к эпизоду.',
                              onConfirmed: () => widget.controller
                                  .deletePostProductionSequence(sequence.id),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: Column(
            children: <Widget>[
              _ListHeader(
                title: 'Версии монтажа',
                buttonLabel: 'Добавить версию',
                onPressed: () {
                  final sequenceId = sequences.firstOrNull?.id;
                  final id = widget.controller.createEditVersion(
                    sequenceId: sequenceId,
                  );
                  final item = widget.controller.document.editVersionById(id);
                  if (item != null) {
                    unawaited(_editVersion(item));
                  }
                },
              ),
              Expanded(
                child: versions.isEmpty
                    ? const Center(child: Text('Версии монтажа не добавлены.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: versions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final version = versions[index];
                          final sequence = widget.controller.document
                              .postProductionSequenceById(
                            version.sequenceId ?? '',
                          );
                          return _ActionListTile(
                            icon: version.isCurrent
                                ? Icons.check_circle
                                : Icons.history,
                            iconColor: version.isCurrent
                                ? const Color(0xFF78C091)
                                : null,
                            title:
                                'v${version.versionNumber} — ${version.title}',
                            subtitle:
                                '${sequence?.title ?? 'Без эпизода'} • ${version.application.isEmpty ? 'Программа не указана' : version.application}',
                            onTap: () => unawaited(_editVersion(version)),
                            onDelete: () => _confirmDelete(
                              title: 'Удалить версию монтажа?',
                              message: version.title,
                              onConfirmed: () => widget.controller
                                  .deleteEditVersion(version.id),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTasksTab() {
    final tasks = _visibleTasks;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  onChanged: (value) => setState(() => _taskQuery = value),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Поиск задач',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<PostTaskDepartment?>(
                  initialValue: _taskDepartmentFilter,
                  decoration: const InputDecoration(labelText: 'Отдел'),
                  items: <DropdownMenuItem<PostTaskDepartment?>>[
                    const DropdownMenuItem<PostTaskDepartment?>(
                      value: null,
                      child: Text('Все отделы'),
                    ),
                    ...PostTaskDepartment.values.map(
                      (value) => DropdownMenuItem<PostTaskDepartment?>(
                        value: value,
                        child: Text(value.label),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _taskDepartmentFilter = value),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<PostTaskStatus?>(
                  initialValue: _taskStatusFilter,
                  decoration: const InputDecoration(labelText: 'Статус'),
                  items: <DropdownMenuItem<PostTaskStatus?>>[
                    const DropdownMenuItem<PostTaskStatus?>(
                      value: null,
                      child: Text('Все статусы'),
                    ),
                    ...PostTaskStatus.values.map(
                      (value) => DropdownMenuItem<PostTaskStatus?>(
                        value: value,
                        child: Text(value.label),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _taskStatusFilter = value),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: () {
                  final id = widget.controller.createPostProductionTask();
                  final task =
                      widget.controller.document.postProductionTaskById(id);
                  if (task != null) {
                    unawaited(_editTask(task));
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Задача'),
              ),
            ],
          ),
        ),
        Expanded(
          child: tasks.isEmpty
              ? const Center(child: Text('Задачи не найдены.'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: tasks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    final scene = task.sceneId == null
                        ? null
                        : widget.controller.document.sceneById(task.sceneId!);
                    return _ActionListTile(
                      icon: task.status == PostTaskStatus.done
                          ? Icons.check_circle_outline
                          : Icons.task_outlined,
                      iconColor: task.status == PostTaskStatus.blocked
                          ? const Color(0xFFD96A6A)
                          : task.status == PostTaskStatus.done
                              ? const Color(0xFF78C091)
                              : null,
                      title: task.title,
                      subtitle:
                          '${task.department.label} • ${task.status.label} • ${task.progress}% • '
                          '${task.assignee.isEmpty ? 'без ответственного' : task.assignee}'
                          '${scene == null ? '' : ' • Сцена ${scene.number}'}',
                      onTap: () => unawaited(_editTask(task)),
                      onDelete: () => _confirmDelete(
                        title: 'Удалить задачу?',
                        message: task.title,
                        onConfirmed: () =>
                            widget.controller.deletePostProductionTask(task.id),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMissingMaterialsTab() {
    final items = _visibleMissingMaterials;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  onChanged: (value) => setState(() => _missingQuery = value),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Поиск пересъёмок и отсутствующего материала',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<MissingMaterialStatus?>(
                  initialValue: _missingStatusFilter,
                  decoration: const InputDecoration(labelText: 'Статус'),
                  items: <DropdownMenuItem<MissingMaterialStatus?>>[
                    const DropdownMenuItem<MissingMaterialStatus?>(
                      value: null,
                      child: Text('Все статусы'),
                    ),
                    ...MissingMaterialStatus.values.map(
                      (value) => DropdownMenuItem<MissingMaterialStatus?>(
                        value: value,
                        child: Text(value.label),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _missingStatusFilter = value),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: () {
                  final id = widget.controller.createMissingMaterial();
                  final item =
                      widget.controller.document.missingMaterialById(id);
                  if (item != null) {
                    unawaited(_editMissingMaterial(item));
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Добавить'),
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text('Открытых позиций нет.'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final scene = item.sceneId == null
                        ? null
                        : widget.controller.document.sceneById(item.sceneId!);
                    return _ActionListTile(
                      icon: item.status == MissingMaterialStatus.completed
                          ? Icons.check_circle_outline
                          : Icons.warning_amber_outlined,
                      iconColor: item.status == MissingMaterialStatus.completed
                          ? const Color(0xFF78C091)
                          : const Color(0xFFE5A93C),
                      title: item.title,
                      subtitle: '${item.type.label} • ${item.status.label} • '
                          '${scene == null ? 'Сцена не указана' : 'Сцена ${scene.number}'} • '
                          '${item.scheduledDate.isEmpty ? 'дата не назначена' : item.scheduledDate}',
                      onTap: () => unawaited(_editMissingMaterial(item)),
                      onDelete: () => _confirmDelete(
                        title: 'Удалить позицию?',
                        message: item.title,
                        onConfirmed: () =>
                            widget.controller.deleteMissingMaterial(item.id),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildExportTab() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: <Widget>[
        _ExportCard(
          icon: Icons.table_view_outlined,
          title: 'План постпродакшна — CSV',
          subtitle: 'Сцены, задачи, сроки, ответственные и пересъёмки.',
          isBusy: _isExporting,
          onPressed: () => unawaited(_exportPlanCsv()),
        ),
        const SizedBox(height: 12),
        _ExportCard(
          icon: Icons.history_outlined,
          title: 'История версий монтажа — CSV',
          subtitle: 'Эпизоды, номера версий, программы, пути к файлам и даты.',
          isBusy: _isExporting,
          onPressed: () => unawaited(_exportVersionsCsv()),
        ),
        const SizedBox(height: 12),
        _ExportCard(
          icon: Icons.picture_as_pdf_outlined,
          title: 'Отчёт о готовности — PDF',
          subtitle: 'Готовность сцен, задачи, версии и отсутствующий материал.',
          isBusy: _isExporting,
          onPressed: () => unawaited(_exportReadinessPdf()),
        ),
      ],
    );
  }

  Future<void> _editScene(SceneSection scene) async {
    final current = widget.controller.document.scenePostProductionFor(scene.id);
    var status = current.status;
    var progress = current.progress.toDouble();
    var directorApproval = current.directorApproval;
    var producerApproval = current.producerApproval;
    var selectedTakeIds = current.selectedTakeIds.toSet();
    final editorNotes = TextEditingController(text: current.editorNotes);
    final directorNotes = TextEditingController(text: current.directorNotes);
    final availableTakes = _service.availableSelectedTakesForScene(
      widget.controller.document,
      scene.id,
    );

    final result = await showDialog<ScenePostProductionData>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Сцена ${scene.number}: ${scene.title}'),
              content: SizedBox(
                width: 820,
                height: 630,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: DropdownButtonFormField<PostSceneStatus>(
                              initialValue: status,
                              decoration:
                                  const InputDecoration(labelText: 'Статус'),
                              items: PostSceneStatus.values
                                  .map(
                                    (value) =>
                                        DropdownMenuItem<PostSceneStatus>(
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
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<ApprovalStatus>(
                              initialValue: directorApproval,
                              decoration:
                                  const InputDecoration(labelText: 'Режиссёр'),
                              items: ApprovalStatus.values
                                  .map(
                                    (value) => DropdownMenuItem<ApprovalStatus>(
                                      value: value,
                                      child: Text(value.label),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (value) {
                                if (value != null) {
                                  setDialogState(
                                      () => directorApproval = value);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<ApprovalStatus>(
                              initialValue: producerApproval,
                              decoration:
                                  const InputDecoration(labelText: 'Продюсер'),
                              items: ApprovalStatus.values
                                  .map(
                                    (value) => DropdownMenuItem<ApprovalStatus>(
                                      value: value,
                                      child: Text(value.label),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (value) {
                                if (value != null) {
                                  setDialogState(
                                      () => producerApproval = value);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text('Готовность: ${progress.round()}%'),
                      Slider(
                        value: progress,
                        max: 100,
                        divisions: 20,
                        label: '${progress.round()}%',
                        onChanged: (value) =>
                            setDialogState(() => progress = value),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: editorNotes,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(
                            labelText: 'Комментарии монтажёра'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: directorNotes,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(
                            labelText: 'Комментарии режиссёра'),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Дубли, выбранные для монтажа',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      if (availableTakes.isEmpty)
                        const Text(
                          'Для этой сцены нет снятых или выбранных дублей.',
                          style: TextStyle(color: Color(0xFF9A9AA2)),
                        ),
                      ...availableTakes.map(
                        (take) => CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: selectedTakeIds.contains(take.id),
                          title: Text(
                            'Дубль ${take.takeNumber} • ${take.fileName.isEmpty ? 'файл не указан' : take.fileName}',
                          ),
                          subtitle: Text(
                            '${take.status.label} • ${take.timecode.isEmpty ? 'таймкод не указан' : take.timecode}',
                          ),
                          onChanged: (value) {
                            setDialogState(() {
                              if (value == true) {
                                selectedTakeIds.add(take.id);
                              } else {
                                selectedTakeIds.remove(take.id);
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(
                      ScenePostProductionData(
                        status: status,
                        progress: progress.round(),
                        editorNotes: editorNotes.text,
                        directorNotes: directorNotes.text,
                        selectedTakeIds:
                            selectedTakeIds.toList(growable: false),
                        directorApproval: directorApproval,
                        producerApproval: producerApproval,
                      ),
                    );
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );

    editorNotes.dispose();
    directorNotes.dispose();

    if (result != null) {
      widget.controller.setScenePostProduction(scene.id, result);
    }
  }

  Future<void> _editSequence(PostProductionSequence sequence) async {
    final title = TextEditingController(text: sequence.title);
    final notes = TextEditingController(text: sequence.notes);
    var sceneIds = sequence.sceneIds.toSet();

    final result = await showDialog<PostProductionSequence>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Монтажный эпизод'),
              content: SizedBox(
                width: 720,
                height: 600,
                child: Column(
                  children: <Widget>[
                    TextField(
                      controller: title,
                      decoration: const InputDecoration(labelText: 'Название'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notes,
                      minLines: 2,
                      maxLines: 4,
                      decoration:
                          const InputDecoration(labelText: 'Примечания'),
                    ),
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Сцены эпизода',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: ListView(
                        children: widget.controller.document.sceneSections
                            .map(
                              (scene) => CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: sceneIds.contains(scene.id),
                                title: Text('${scene.number}. ${scene.title}'),
                                onChanged: (value) {
                                  setDialogState(() {
                                    if (value == true) {
                                      sceneIds.add(scene.id);
                                    } else {
                                      sceneIds.remove(scene.id);
                                    }
                                  });
                                },
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(
                    sequence.copyWith(
                      title: title.text,
                      notes: notes.text,
                      sceneIds: sceneIds.toList(growable: false),
                    ),
                  ),
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );

    title.dispose();
    notes.dispose();

    if (result != null) {
      widget.controller.updatePostProductionSequence(result);
    }
  }

  Future<void> _editVersion(EditVersion version) async {
    final title = TextEditingController(text: version.title);
    final number = TextEditingController(text: '${version.versionNumber}');
    final application = TextEditingController(text: version.application);
    final filePath = TextEditingController(text: version.filePath);
    final createdAt = TextEditingController(text: version.createdAt);
    final duration = TextEditingController(
      text: version.durationSeconds.toStringAsFixed(
        version.durationSeconds % 1 == 0 ? 0 : 1,
      ),
    );
    final notes = TextEditingController(text: version.notes);
    var sequenceId = version.sequenceId;
    var isCurrent = version.isCurrent;

    final result = await showDialog<EditVersion>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Версия монтажа'),
              content: SizedBox(
                width: 760,
                child: SingleChildScrollView(
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: title,
                              decoration:
                                  const InputDecoration(labelText: 'Название'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: number,
                              keyboardType: TextInputType.number,
                              decoration:
                                  const InputDecoration(labelText: 'Номер'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        initialValue: sequenceId,
                        decoration: const InputDecoration(
                            labelText: 'Монтажный эпизод'),
                        items: <DropdownMenuItem<String?>>[
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Без эпизода'),
                          ),
                          ...widget.controller.document.postProductionSequences
                              .map(
                            (item) => DropdownMenuItem<String?>(
                              value: item.id,
                              child: Text(item.title),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setDialogState(() => sequenceId = value),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: application,
                              decoration: const InputDecoration(
                                labelText: 'Программа',
                                hintText: 'Premiere Pro / DaVinci Resolve',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: createdAt,
                              decoration: const InputDecoration(
                                labelText: 'Дата',
                                hintText: '2026-08-05',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: duration,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                  labelText: 'Длительность, сек.'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: filePath,
                        decoration: const InputDecoration(
                          labelText: 'Путь к проекту или видеофайлу',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notes,
                        minLines: 3,
                        maxLines: 6,
                        decoration:
                            const InputDecoration(labelText: 'Примечания'),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: isCurrent,
                        title: const Text('Текущая версия'),
                        subtitle: const Text(
                            'Предыдущая текущая версия этого эпизода будет снята.'),
                        onChanged: (value) =>
                            setDialogState(() => isCurrent = value),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(
                    version.copyWith(
                      title: title.text,
                      sequenceId: sequenceId,
                      clearSequenceId: sequenceId == null,
                      versionNumber: int.tryParse(number.text) ?? 1,
                      application: application.text,
                      filePath: filePath.text,
                      createdAt: createdAt.text,
                      durationSeconds:
                          double.tryParse(duration.text.replaceAll(',', '.')) ??
                              0,
                      notes: notes.text,
                      isCurrent: isCurrent,
                    ),
                  ),
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );

    title.dispose();
    number.dispose();
    application.dispose();
    filePath.dispose();
    createdAt.dispose();
    duration.dispose();
    notes.dispose();

    if (result != null) {
      widget.controller.updateEditVersion(result);
    }
  }

  Future<void> _editTask(PostProductionTask task) async {
    final title = TextEditingController(text: task.title);
    final assignee = TextEditingController(text: task.assignee);
    final dueDate = TextEditingController(text: task.dueDate);
    final notes = TextEditingController(text: task.notes);
    var department = task.department;
    var status = task.status;
    var priority = task.priority;
    var progress = task.progress.toDouble();
    var sceneId = task.sceneId;
    var versionId = task.versionId;

    final result = await showDialog<PostProductionTask>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Задача постпродакшна'),
              content: SizedBox(
                width: 800,
                child: SingleChildScrollView(
                  child: Column(
                    children: <Widget>[
                      TextField(
                        controller: title,
                        decoration:
                            const InputDecoration(labelText: 'Название'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: DropdownButtonFormField<PostTaskDepartment>(
                              initialValue: department,
                              decoration:
                                  const InputDecoration(labelText: 'Отдел'),
                              items: PostTaskDepartment.values
                                  .map(
                                    (value) =>
                                        DropdownMenuItem<PostTaskDepartment>(
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
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<PostTaskStatus>(
                              initialValue: status,
                              decoration:
                                  const InputDecoration(labelText: 'Статус'),
                              items: PostTaskStatus.values
                                  .map(
                                    (value) => DropdownMenuItem<PostTaskStatus>(
                                      value: value,
                                      child: Text(value.label),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (value) {
                                if (value != null) {
                                  setDialogState(() {
                                    status = value;
                                    if (value == PostTaskStatus.done) {
                                      progress = 100;
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<PostTaskPriority>(
                              initialValue: priority,
                              decoration:
                                  const InputDecoration(labelText: 'Приоритет'),
                              items: PostTaskPriority.values
                                  .map(
                                    (value) =>
                                        DropdownMenuItem<PostTaskPriority>(
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
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: assignee,
                              decoration: const InputDecoration(
                                  labelText: 'Ответственный'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: dueDate,
                              decoration: const InputDecoration(
                                labelText: 'Срок',
                                hintText: '2026-08-20',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              initialValue: sceneId,
                              decoration:
                                  const InputDecoration(labelText: 'Сцена'),
                              items: <DropdownMenuItem<String?>>[
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Без сцены'),
                                ),
                                ...widget.controller.document.sceneSections.map(
                                  (scene) => DropdownMenuItem<String?>(
                                    value: scene.id,
                                    child:
                                        Text('${scene.number}. ${scene.title}'),
                                  ),
                                ),
                              ],
                              onChanged: (value) =>
                                  setDialogState(() => sceneId = value),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              initialValue: versionId,
                              decoration:
                                  const InputDecoration(labelText: 'Версия'),
                              items: <DropdownMenuItem<String?>>[
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Без версии'),
                                ),
                                ...widget.controller.document.editVersions.map(
                                  (version) => DropdownMenuItem<String?>(
                                    value: version.id,
                                    child: Text(
                                        'v${version.versionNumber} — ${version.title}'),
                                  ),
                                ),
                              ],
                              onChanged: (value) =>
                                  setDialogState(() => versionId = value),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Готовность: ${progress.round()}%'),
                      Slider(
                        value: progress,
                        max: 100,
                        divisions: 20,
                        label: '${progress.round()}%',
                        onChanged: status == PostTaskStatus.done
                            ? null
                            : (value) => setDialogState(() => progress = value),
                      ),
                      TextField(
                        controller: notes,
                        minLines: 3,
                        maxLines: 6,
                        decoration:
                            const InputDecoration(labelText: 'Примечания'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(
                    task.copyWith(
                      title: title.text,
                      department: department,
                      status: status,
                      priority: priority,
                      assignee: assignee.text,
                      dueDate: dueDate.text,
                      progress: progress.round(),
                      sceneId: sceneId,
                      clearSceneId: sceneId == null,
                      versionId: versionId,
                      clearVersionId: versionId == null,
                      notes: notes.text,
                    ),
                  ),
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );

    title.dispose();
    assignee.dispose();
    dueDate.dispose();
    notes.dispose();

    if (result != null) {
      widget.controller.updatePostProductionTask(result);
    }
  }

  Future<void> _editMissingMaterial(MissingMaterialItem item) async {
    final title = TextEditingController(text: item.title);
    final description = TextEditingController(text: item.description);
    final scheduledDate = TextEditingController(text: item.scheduledDate);
    final assignee = TextEditingController(text: item.assignee);
    var type = item.type;
    var status = item.status;
    var sceneId = item.sceneId;
    var shotId = item.shotId;

    final result = await showDialog<MissingMaterialItem>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final availableShots = sceneId == null
                ? widget.controller.document.storyboardShots.values
                    .expand((shots) => shots)
                    .toList(growable: false)
                : widget.controller.document.storyboardShotsFor(sceneId!);
            if (shotId != null &&
                !availableShots.any((shot) => shot.id == shotId)) {
              shotId = null;
            }

            return AlertDialog(
              title: const Text('Отсутствующий материал / пересъёмка'),
              content: SizedBox(
                width: 780,
                child: SingleChildScrollView(
                  child: Column(
                    children: <Widget>[
                      TextField(
                        controller: title,
                        decoration:
                            const InputDecoration(labelText: 'Название'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: DropdownButtonFormField<MissingMaterialType>(
                              initialValue: type,
                              decoration:
                                  const InputDecoration(labelText: 'Тип'),
                              items: MissingMaterialType.values
                                  .map(
                                    (value) =>
                                        DropdownMenuItem<MissingMaterialType>(
                                      value: value,
                                      child: Text(value.label),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (value) {
                                if (value != null) {
                                  setDialogState(() => type = value);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child:
                                DropdownButtonFormField<MissingMaterialStatus>(
                              initialValue: status,
                              decoration:
                                  const InputDecoration(labelText: 'Статус'),
                              items: MissingMaterialStatus.values
                                  .map(
                                    (value) =>
                                        DropdownMenuItem<MissingMaterialStatus>(
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
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              initialValue: sceneId,
                              decoration:
                                  const InputDecoration(labelText: 'Сцена'),
                              items: <DropdownMenuItem<String?>>[
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Без сцены'),
                                ),
                                ...widget.controller.document.sceneSections.map(
                                  (scene) => DropdownMenuItem<String?>(
                                    value: scene.id,
                                    child:
                                        Text('${scene.number}. ${scene.title}'),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setDialogState(() {
                                  sceneId = value;
                                  shotId = null;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              initialValue: shotId,
                              decoration:
                                  const InputDecoration(labelText: 'Кадр'),
                              items: <DropdownMenuItem<String?>>[
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Без кадра'),
                                ),
                                ...availableShots.asMap().entries.map(
                                      (entry) => DropdownMenuItem<String?>(
                                        value: entry.value.id,
                                        child: Text(
                                          entry.value.title.isEmpty
                                              ? 'Кадр ${entry.key + 1}'
                                              : entry.value.title,
                                        ),
                                      ),
                                    ),
                              ],
                              onChanged: (value) =>
                                  setDialogState(() => shotId = value),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: scheduledDate,
                              decoration: const InputDecoration(
                                labelText: 'Плановая дата',
                                hintText: '2026-08-25',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: assignee,
                              decoration: const InputDecoration(
                                  labelText: 'Ответственный'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: description,
                        minLines: 4,
                        maxLines: 8,
                        decoration:
                            const InputDecoration(labelText: 'Описание'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(
                    item.copyWith(
                      title: title.text,
                      type: type,
                      status: status,
                      sceneId: sceneId,
                      clearSceneId: sceneId == null,
                      shotId: shotId,
                      clearShotId: shotId == null,
                      description: description.text,
                      scheduledDate: scheduledDate.text,
                      assignee: assignee.text,
                    ),
                  ),
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );

    title.dispose();
    description.dispose();
    scheduledDate.dispose();
    assignee.dispose();

    if (result != null) {
      widget.controller.updateMissingMaterial(result);
    }
  }

  Future<void> _confirmDelete({
    required String title,
    required String message,
    required VoidCallback onConfirmed,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onConfirmed();
    }
  }

  Future<void> _exportPlanCsv() async {
    await _runExport(() async {
      final path = await _fileService.choosePlanCsvPath(
        projectName: widget.projectName,
      );
      if (path == null) {
        return;
      }
      final csv = _service.buildPostProductionPlanCsv(
        widget.controller.document,
        projectName: widget.projectName,
      );
      final saved = await _fileService.writeCsv(path, csv);
      _showMessage('План сохранён: $saved');
    });
  }

  Future<void> _exportVersionsCsv() async {
    await _runExport(() async {
      final path = await _fileService.chooseVersionCsvPath(
        projectName: widget.projectName,
      );
      if (path == null) {
        return;
      }
      final csv = _service.buildVersionHistoryCsv(
        widget.controller.document,
        projectName: widget.projectName,
      );
      final saved = await _fileService.writeCsv(path, csv);
      _showMessage('История версий сохранена: $saved');
    });
  }

  Future<void> _exportReadinessPdf() async {
    await _runExport(() async {
      final path = await _fileService.chooseReadinessPdfPath(
        projectName: widget.projectName,
      );
      if (path == null) {
        return;
      }
      final bytes = await _pdfService.buildReadinessPdf(
        widget.controller.document,
        projectName: widget.projectName,
      );
      final saved = await _fileService.writePdf(path, bytes);
      _showMessage('PDF сохранён: $saved');
    });
  }

  Future<void> _runExport(Future<void> Function() action) async {
    if (_isExporting) {
      return;
    }

    setState(() => _isExporting = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Ошибка экспорта'),
            content: Text('$error'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Закрыть'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    this.isWarning = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 185,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF29292D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isWarning ? const Color(0xFFD96A6A) : const Color(0xFF3C3C43),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            icon,
            color:
                isWarning ? const Color(0xFFD96A6A) : const Color(0xFFE5A93C),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label,
                    style: const TextStyle(
                        color: Color(0xFF9A9AA2), fontSize: 11)),
                const SizedBox(height: 3),
                Text(value,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF29292D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF3C3C43)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ListHeader extends StatelessWidget {
  const _ListHeader({
    required this.title,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String title;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.add),
            label: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

class _ActionListTile extends StatelessWidget {
  const _ActionListTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.onDelete,
    this.iconColor,
  });

  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback onDelete;

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
        leading: Icon(icon, color: iconColor ?? const Color(0xFFE5A93C)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: IconButton(
          tooltip: 'Удалить',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
        ),
        onTap: onTap,
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
        trailing: isBusy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.download_outlined),
        onTap: isBusy ? null : onPressed,
      ),
    );
  }
}
