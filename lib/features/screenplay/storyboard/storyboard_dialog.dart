import 'dart:async';

import 'package:flutter/material.dart';
import 'package:filmsoz_studio/features/screenplay/document/scene_section.dart';
import 'package:filmsoz_studio/features/screenplay/editor/controller/screenplay_editor_controller.dart';
import 'package:filmsoz_studio/features/screenplay/storyboard/storyboard_file_service.dart';
import 'package:filmsoz_studio/features/screenplay/storyboard/storyboard_pdf_service.dart';
import 'package:filmsoz_studio/features/screenplay/storyboard/storyboard_service.dart';
import 'package:filmsoz_studio/features/screenplay/storyboard/storyboard_shot.dart';

class StoryboardDialog extends StatefulWidget {
  const StoryboardDialog({
    super.key,
    required this.controller,
    required this.projectName,
    required this.onSceneSelected,
  });

  final ScreenplayEditorController controller;
  final String projectName;
  final ValueChanged<SceneSection> onSceneSelected;

  @override
  State<StoryboardDialog> createState() => _StoryboardDialogState();
}

class _StoryboardDialogState extends State<StoryboardDialog> {
  final StoryboardService _service = const StoryboardService();
  final StoryboardFileService _fileService = const StoryboardFileService();
  final StoryboardPdfService _pdfService = StoryboardPdfService();

  String? _selectedSceneId;
  String? _selectedShotId;
  String _query = '';
  String _sceneQuery = '';
  ShotSize? _shotSizeFilter;
  String _equipmentFilter = '';
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    final firstScene = widget.controller.document.sceneSections.firstOrNull;
    _selectedSceneId = firstScene?.id;
    _selectedShotId = firstScene == null
        ? null
        : widget.controller.document
            .storyboardShotsFor(firstScene.id)
            .firstOrNull
            ?.id;
  }

  SceneSection? get _selectedScene {
    final sceneId = _selectedSceneId;
    return sceneId == null
        ? null
        : widget.controller.document.sceneById(sceneId);
  }

  List<StoryboardShot> get _sceneShots {
    final sceneId = _selectedSceneId;
    return sceneId == null
        ? const <StoryboardShot>[]
        : widget.controller.document.storyboardShotsFor(sceneId);
  }

  bool get _isFiltering =>
      _query.trim().isNotEmpty ||
      _shotSizeFilter != null ||
      _equipmentFilter.trim().isNotEmpty;

  List<StoryboardShot> get _visibleShots {
    final shots = _sceneShots;
    final query = _query.trim().toLowerCase();
    final equipment = _equipmentFilter.trim().toLowerCase();

    return shots.where((shot) {
      if (_shotSizeFilter != null && shot.shotSize != _shotSizeFilter) {
        return false;
      }

      if (equipment.isNotEmpty &&
          !shot.equipment.any(
            (item) => item.toLowerCase().contains(equipment),
          )) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final searchable = <String>[
        shot.title,
        shot.shotSize.label,
        shot.cameraAngle.label,
        shot.cameraMovement.label,
        shot.lens,
        ...shot.equipment,
        shot.visualDescription,
        shot.actionDescription,
        shot.dialogue,
        shot.sound,
        shot.notes,
      ].join('\n').toLowerCase();

      return searchable.contains(query);
    }).toList(growable: false);
  }

  void _selectScene(SceneSection scene) {
    final shots = widget.controller.document.storyboardShotsFor(scene.id);

    setState(() {
      _selectedSceneId = scene.id;
      _selectedShotId = shots.firstOrNull?.id;
    });
  }

  Future<void> _addShot() async {
    final sceneId = _selectedSceneId;

    if (sceneId == null) {
      return;
    }

    final shotId = widget.controller.createStoryboardShot(sceneId);

    if (shotId == null) {
      return;
    }

    setState(() => _selectedShotId = shotId);
    final shot = widget.controller.document.storyboardShotById(sceneId, shotId);

    if (shot != null) {
      await _editShot(shot);
    }
  }

  Future<void> _editShot(StoryboardShot shot) async {
    final sceneId = _selectedSceneId;

    if (sceneId == null) {
      return;
    }

    final titleController = TextEditingController(text: shot.title);
    final lensController = TextEditingController(text: shot.lens);
    final fpsController = TextEditingController(text: _formatNumber(shot.fps));
    final durationController = TextEditingController(
      text: _formatNumber(shot.durationSeconds),
    );
    final equipmentController = TextEditingController(
      text: shot.equipment.join(', '),
    );
    final visualController = TextEditingController(
      text: shot.visualDescription,
    );
    final actionController = TextEditingController(
      text: shot.actionDescription,
    );
    final dialogueController = TextEditingController(text: shot.dialogue);
    final soundController = TextEditingController(text: shot.sound);
    final notesController = TextEditingController(text: shot.notes);
    var shotSize = shot.shotSize;
    var cameraAngle = shot.cameraAngle;
    var cameraMovement = shot.cameraMovement;

    final shouldSave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF29292D),
              title: const Text('Параметры кадра'),
              content: SizedBox(
                width: 820,
                height: 650,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _ShotTextField(
                        controller: titleController,
                        label: 'Название кадра',
                        hint: 'Герой входит в комнату',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: DropdownButtonFormField<ShotSize>(
                              initialValue: shotSize,
                              decoration: const InputDecoration(
                                labelText: 'Тип плана',
                              ),
                              items: ShotSize.values
                                  .map(
                                    (value) => DropdownMenuItem<ShotSize>(
                                      value: value,
                                      child: Text(value.label),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (value) {
                                if (value != null) {
                                  setDialogState(() => shotSize = value);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<CameraAngle>(
                              initialValue: cameraAngle,
                              decoration: const InputDecoration(
                                labelText: 'Ракурс',
                              ),
                              items: CameraAngle.values
                                  .map(
                                    (value) => DropdownMenuItem<CameraAngle>(
                                      value: value,
                                      child: Text(value.label),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (value) {
                                if (value != null) {
                                  setDialogState(() => cameraAngle = value);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<CameraMovement>(
                              initialValue: cameraMovement,
                              decoration: const InputDecoration(
                                labelText: 'Движение камеры',
                              ),
                              items: CameraMovement.values
                                  .map(
                                    (value) => DropdownMenuItem<CameraMovement>(
                                      value: value,
                                      child: Text(value.label),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (value) {
                                if (value != null) {
                                  setDialogState(
                                    () => cameraMovement = value,
                                  );
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
                            child: _ShotTextField(
                              controller: lensController,
                              label: 'Объектив',
                              hint: '35 мм',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ShotTextField(
                              controller: fpsController,
                              label: 'FPS',
                              hint: '24',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ShotTextField(
                              controller: durationController,
                              label: 'Длительность, секунд',
                              hint: '5',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _ShotTextField(
                        controller: equipmentController,
                        label: 'Оборудование',
                        hint: 'Штатив, рельсы, дым-машина',
                      ),
                      const SizedBox(height: 12),
                      _ShotTextField(
                        controller: visualController,
                        label: 'Описание изображения / композиции',
                        minLines: 2,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 12),
                      _ShotTextField(
                        controller: actionController,
                        label: 'Действие в кадре',
                        minLines: 2,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: _ShotTextField(
                              controller: dialogueController,
                              label: 'Диалог / текст',
                              minLines: 3,
                              maxLines: 6,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ShotTextField(
                              controller: soundController,
                              label: 'Звук / музыка',
                              minLines: 3,
                              maxLines: 6,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _ShotTextField(
                        controller: notesController,
                        label: 'Режиссёрские и монтажные примечания',
                        minLines: 2,
                        maxLines: 5,
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
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
      widget.controller.updateStoryboardShot(
        sceneId,
        shot.copyWith(
          title: titleController.text,
          shotSize: shotSize,
          cameraAngle: cameraAngle,
          cameraMovement: cameraMovement,
          lens: lensController.text,
          fps: _parsePositiveDouble(fpsController.text, fallback: 24),
          durationSeconds: _parseNonNegativeDouble(durationController.text),
          equipment: readStoryboardStringList(equipmentController.text),
          visualDescription: visualController.text,
          actionDescription: actionController.text,
          dialogue: dialogueController.text,
          sound: soundController.text,
          notes: notesController.text,
        ),
      );

      if (mounted) {
        setState(() {});
      }
    }

    titleController.dispose();
    lensController.dispose();
    fpsController.dispose();
    durationController.dispose();
    equipmentController.dispose();
    visualController.dispose();
    actionController.dispose();
    dialogueController.dispose();
    soundController.dispose();
    notesController.dispose();
  }

  Future<void> _attachImage(StoryboardShot shot) async {
    final sceneId = _selectedSceneId;

    if (sceneId == null || _isBusy) {
      return;
    }

    setState(() => _isBusy = true);

    try {
      final image = await _fileService.chooseImage();

      if (image == null || !mounted) {
        return;
      }

      widget.controller.updateStoryboardShot(
        sceneId,
        shot.copyWith(
          imageFileName: image.fileName,
          imageMimeType: image.mimeType,
          imageBase64: image.base64Data,
        ),
      );
      setState(() {});
    } catch (error) {
      if (mounted) {
        _showMessage('Не удалось добавить изображение: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  void _clearImage(StoryboardShot shot) {
    final sceneId = _selectedSceneId;

    if (sceneId == null) {
      return;
    }

    widget.controller.updateStoryboardShot(
      sceneId,
      shot.copyWith(clearImage: true),
    );
    setState(() {});
  }

  void _duplicateShot(StoryboardShot shot) {
    final sceneId = _selectedSceneId;

    if (sceneId == null) {
      return;
    }

    final id = widget.controller.duplicateStoryboardShot(sceneId, shot.id);

    if (id != null) {
      setState(() => _selectedShotId = id);
    }
  }

  Future<void> _deleteShot(StoryboardShot shot) async {
    final sceneId = _selectedSceneId;

    if (sceneId == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить кадр?'),
        content: Text(
          shot.title.trim().isEmpty
              ? 'Кадр будет удалён из монтажного сценария.'
              : '«${shot.title.trim()}» будет удалён из монтажного сценария.',
        ),
        actions: <Widget>[
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

    if (!mounted || confirmed != true) {
      return;
    }

    widget.controller.deleteStoryboardShot(sceneId, shot.id);
    final shots = widget.controller.document.storyboardShotsFor(sceneId);

    setState(() {
      _selectedShotId = shots.firstOrNull?.id;
    });
  }

  void _reorderShots(int oldIndex, int newIndex) {
    final sceneId = _selectedSceneId;

    if (sceneId == null || _isFiltering) {
      return;
    }

    if (widget.controller.moveStoryboardShot(
      sceneId,
      oldIndex: oldIndex,
      newIndex: newIndex,
    )) {
      setState(() {});
    }
  }

  Future<void> _exportCsv() async {
    await _runExport(() async {
      final path = await _fileService.chooseCsvSavePath(
        projectName: widget.projectName,
      );

      if (path == null) {
        return null;
      }

      final csv = _service.buildShotListCsv(
        widget.controller.document,
        projectName: widget.projectName,
      );
      return _fileService.writeCsv(path, csv);
    });
  }

  Future<void> _exportPdf() async {
    await _runExport(() async {
      final path = await _fileService.choosePdfSavePath(
        projectName: widget.projectName,
      );

      if (path == null) {
        return null;
      }

      final bytes = await _pdfService.buildPdf(
        widget.controller.document,
        projectName: widget.projectName,
      );
      return _fileService.writePdf(path, bytes);
    });
  }

  Future<void> _runExport(Future<String?> Function() action) async {
    if (_isBusy) {
      return;
    }

    setState(() => _isBusy = true);

    try {
      final savedPath = await action();

      if (savedPath != null && mounted) {
        _showMessage('Файл сохранён: $savedPath');
      }
    } catch (error) {
      if (mounted) {
        _showMessage('Не удалось выполнить экспорт: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  void _undo() {
    if (widget.controller.undo()) {
      _repairSelection();
      setState(() {});
    }
  }

  void _redo() {
    if (widget.controller.redo()) {
      _repairSelection();
      setState(() {});
    }
  }

  void _repairSelection() {
    final scenes = widget.controller.document.sceneSections;

    if (_selectedSceneId == null ||
        !scenes.any((scene) => scene.id == _selectedSceneId)) {
      _selectedSceneId = scenes.firstOrNull?.id;
    }

    final shots = _sceneShots;

    if (_selectedShotId == null ||
        !shots.any((shot) => shot.id == _selectedShotId)) {
      _selectedShotId = shots.firstOrNull?.id;
    }
  }

  void _openSelectedScene() {
    final scene = _selectedScene;

    if (scene == null) {
      return;
    }

    Navigator.of(context).pop();
    widget.onSceneSelected(scene);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sceneQuery = _sceneQuery.trim().toLowerCase();
    final scenes = widget.controller.document.sceneSections.where((scene) {
      if (sceneQuery.isEmpty) {
        return true;
      }

      return '${scene.number} ${scene.title}'
          .toLowerCase()
          .contains(sceneQuery);
    }).toList(growable: false);
    final allShots = _service.numberedShots(widget.controller.document);
    final totalDuration = _service.totalDurationSeconds(
      widget.controller.document,
    );

    return AlertDialog(
      insetPadding: const EdgeInsets.all(18),
      backgroundColor: const Color(0xFF202024),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: <Widget>[
          const Icon(Icons.movie_creation_outlined),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Монтажный сценарий и раскадровка'),
          ),
          Text(
            '${allShots.length} кадров • ${_service.formatDuration(totalDuration)}',
            style: const TextStyle(
              color: Color(0xFFAAAAAA),
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: widget.controller.canUndo ? _undo : null,
            tooltip: 'Отменить',
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            onPressed: widget.controller.canRedo ? _redo : null,
            tooltip: 'Вернуть',
            icon: const Icon(Icons.redo),
          ),
          IconButton(
            onPressed: _isBusy ? null : () => unawaited(_exportCsv()),
            tooltip: 'Экспорт съёмочного листа CSV',
            icon: const Icon(Icons.table_view_outlined),
          ),
          IconButton(
            onPressed: _isBusy ? null : () => unawaited(_exportPdf()),
            tooltip: 'Экспорт раскадровки PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Закрыть',
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: SizedBox(
        width: 1240,
        height: 760,
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 275,
              child: _buildScenePanel(scenes),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: <Widget>[
                  _buildFilterBar(),
                  const Divider(height: 1),
                  Expanded(child: _buildShotList()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScenePanel(List<SceneSection> scenes) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'СЦЕНЫ',
                      style: TextStyle(
                        color: Color(0xFFAAAAAA),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed:
                        _selectedSceneId == null ? null : _openSelectedScene,
                    tooltip: 'Открыть сцену в сценарии',
                    icon: const Icon(Icons.open_in_new, size: 18),
                  ),
                ],
              ),
              TextField(
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.search, size: 17),
                  hintText: 'Найти сцену...',
                ),
                onChanged: (value) => setState(() => _sceneQuery = value),
              ),
            ],
          ),
        ),
        Expanded(
          child: scenes.isEmpty
              ? const Center(child: Text('Нет сцен'))
              : ListView.builder(
                  itemCount: scenes.length,
                  itemBuilder: (context, index) {
                    final scene = scenes[index];
                    final shots =
                        widget.controller.document.storyboardShotsFor(scene.id);
                    final selected = scene.id == _selectedSceneId;
                    final duration = _service.sceneDurationSeconds(
                      widget.controller.document,
                      scene.id,
                    );

                    return Material(
                      color: selected
                          ? const Color(0xFF34343A)
                          : Colors.transparent,
                      child: ListTile(
                        dense: true,
                        selected: selected,
                        onTap: () => _selectScene(scene),
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: selected
                              ? const Color(0xFFE5A93C)
                              : const Color(0xFF3A3A40),
                          foregroundColor: selected
                              ? const Color(0xFF151515)
                              : const Color(0xFFE0E0E0),
                          child: Text(
                            '${scene.number}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        title: Text(
                          scene.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                        subtitle: Text(
                          '${shots.length} кадров • ${_service.formatDuration(duration)}',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 18),
                hintText: 'Поиск по кадрам...',
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 190,
            child: DropdownButtonFormField<String>(
              initialValue: _shotSizeFilter?.name ?? '',
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Тип плана',
              ),
              items: <DropdownMenuItem<String>>[
                const DropdownMenuItem<String>(
                  value: '',
                  child: Text('Все планы'),
                ),
                ...ShotSize.values.map(
                  (value) => DropdownMenuItem<String>(
                    value: value.name,
                    child: Text(value.label),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _shotSizeFilter = value == null || value.isEmpty
                      ? null
                      : ShotSize.values.byName(value);
                });
              },
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 210,
            child: TextField(
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.videocam_outlined, size: 18),
                hintText: 'Оборудование',
              ),
              onChanged: (value) => setState(() => _equipmentFilter = value),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: _selectedSceneId == null || _isBusy
                ? null
                : () => unawaited(_addShot()),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Добавить кадр'),
          ),
        ],
      ),
    );
  }

  Widget _buildShotList() {
    final scene = _selectedScene;

    if (scene == null) {
      return const Center(child: Text('Выберите сцену.'));
    }

    final visibleShots = _visibleShots;

    if (visibleShots.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.photo_library_outlined,
              size: 54,
              color: Color(0xFF777777),
            ),
            const SizedBox(height: 12),
            Text(
              _isFiltering
                  ? 'По заданным фильтрам кадры не найдены.'
                  : 'Для этой сцены пока нет кадров.',
            ),
            if (!_isFiltering) ...<Widget>[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => unawaited(_addShot()),
                icon: const Icon(Icons.add),
                label: const Text('Создать первый кадр'),
              ),
            ],
          ],
        ),
      );
    }

    if (_isFiltering) {
      return ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: visibleShots.length,
        itemBuilder: (context, index) {
          final shot = visibleShots[index];
          final originalIndex = _sceneShots.indexWhere(
            (item) => item.id == shot.id,
          );
          return _buildShotCard(
            scene: scene,
            shot: shot,
            shotIndex: originalIndex,
          );
        },
      );
    }

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.all(14),
      itemCount: visibleShots.length,
      onReorderItem: _reorderShots,
      proxyDecorator: (child, index, animation) {
        return Material(
          color: Colors.transparent,
          elevation: 10,
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final shot = visibleShots[index];
        return _buildShotCard(
          key: ValueKey<String>('storyboard-${shot.id}'),
          scene: scene,
          shot: shot,
          shotIndex: index,
          dragHandle: ReorderableDragStartListener(
            index: index,
            child: const Tooltip(
              message: 'Перетащить кадр',
              child: Icon(Icons.drag_indicator),
            ),
          ),
        );
      },
    );
  }

  Widget _buildShotCard({
    Key? key,
    required SceneSection scene,
    required StoryboardShot shot,
    required int shotIndex,
    Widget? dragHandle,
  }) {
    final selected = shot.id == _selectedShotId;
    final imageBytes = shot.imageBytes;
    final number = '${scene.number}.${shotIndex + 1}';

    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: selected ? const Color(0xFF333338) : const Color(0xFF29292D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected ? const Color(0xFFE5A93C) : const Color(0xFF414148),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() => _selectedShotId = shot.id),
          onDoubleTap: () => unawaited(_editShot(shot)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 230,
                  height: 130,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      Container(
                        color: const Color(0xFF17171A),
                        child: imageBytes == null
                            ? const Center(
                                child: Icon(
                                  Icons.image_outlined,
                                  size: 40,
                                  color: Color(0xFF666666),
                                ),
                              )
                            : Image.memory(
                                imageBytes,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      color: Color(0xFF888888),
                                    ),
                                  );
                                },
                              ),
                      ),
                      Positioned(
                        left: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xDD111111),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            number,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Row(
                          children: <Widget>[
                            _ImageActionButton(
                              tooltip: imageBytes == null
                                  ? 'Добавить изображение'
                                  : 'Заменить изображение',
                              icon: Icons.add_photo_alternate_outlined,
                              onPressed: _isBusy
                                  ? null
                                  : () => unawaited(_attachImage(shot)),
                            ),
                            if (imageBytes != null)
                              _ImageActionButton(
                                tooltip: 'Удалить изображение',
                                icon: Icons.hide_image_outlined,
                                onPressed: () => _clearImage(shot),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              shot.title.trim().isEmpty
                                  ? 'Кадр $number'
                                  : shot.title.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (dragHandle != null) dragHandle,
                        ],
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 6,
                        runSpacing: 5,
                        children: <Widget>[
                          _ShotChip(shot.shotSize.label),
                          _ShotChip(shot.cameraAngle.label),
                          _ShotChip(shot.cameraMovement.label),
                          if (shot.lens.trim().isNotEmpty)
                            _ShotChip(shot.lens.trim()),
                          _ShotChip('${_formatNumber(shot.fps)} FPS'),
                          _ShotChip(
                            _service.formatDuration(shot.durationSeconds),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _shotSummary(shot),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFCCCCCC),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                      if (shot.equipment.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(
                          'Оборудование: ${shot.equipment.join(', ')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF9E9E9E),
                            fontSize: 11,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          TextButton.icon(
                            onPressed: () => unawaited(_editShot(shot)),
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text('Редактировать'),
                          ),
                          TextButton.icon(
                            onPressed: () => _duplicateShot(shot),
                            icon: const Icon(Icons.copy_outlined, size: 16),
                            label: const Text('Дублировать'),
                          ),
                          TextButton.icon(
                            onPressed: () => unawaited(_deleteShot(shot)),
                            icon: const Icon(Icons.delete_outline, size: 16),
                            label: const Text('Удалить'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _shotSummary(StoryboardShot shot) {
    for (final value in <String>[
      shot.visualDescription,
      shot.actionDescription,
      shot.dialogue,
      shot.sound,
      shot.notes,
    ]) {
      if (value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return 'Описание кадра пока не заполнено.';
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return '${value.toInt()}';
    }

    return value.toStringAsFixed(2);
  }

  double _parseNonNegativeDouble(String value) {
    final parsed = double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;
    return parsed < 0 ? 0 : parsed;
  }

  double _parsePositiveDouble(String value, {required double fallback}) {
    final parsed = _parseNonNegativeDouble(value);
    return parsed <= 0 ? fallback : parsed;
  }
}

class _ShotChip extends StatelessWidget {
  const _ShotChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF3A3A40),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10.5),
      ),
    );
  }
}

class _ImageActionButton extends StatelessWidget {
  const _ImageActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 17),
      color: Colors.white,
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xCC111111),
        minimumSize: const Size(30, 30),
        padding: const EdgeInsets.all(5),
      ),
    );
  }
}

class _ShotTextField extends StatelessWidget {
  const _ShotTextField({
    required this.controller,
    required this.label,
    this.hint,
    this.minLines = 1,
    this.maxLines = 1,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final int minLines;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
    );
  }
}
