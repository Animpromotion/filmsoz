import 'dart:async';

import 'package:flutter/material.dart';
import 'package:filmsoz_studio/features/screenplay/document/scene_section.dart';
import 'package:filmsoz_studio/features/screenplay/editor/controller/screenplay_editor_controller.dart';
import 'package:filmsoz_studio/features/screenplay/shooting_control/shooting_control.dart';
import 'package:filmsoz_studio/features/screenplay/shooting_control/shooting_control_file_service.dart';
import 'package:filmsoz_studio/features/screenplay/shooting_control/shooting_control_pdf_service.dart';
import 'package:filmsoz_studio/features/screenplay/shooting_control/shooting_control_service.dart';
import 'package:filmsoz_studio/features/screenplay/storyboard/storyboard_shot.dart';

class ShootingControlDialog extends StatefulWidget {
  const ShootingControlDialog({
    super.key,
    required this.controller,
    required this.projectName,
    required this.onSceneSelected,
  });

  final ScreenplayEditorController controller;
  final String projectName;
  final ValueChanged<SceneSection> onSceneSelected;

  @override
  State<ShootingControlDialog> createState() => _ShootingControlDialogState();
}

class _ShootingControlDialogState extends State<ShootingControlDialog> {
  final ShootingControlService _service = const ShootingControlService();
  final ShootingControlFileService _fileService =
      const ShootingControlFileService();
  final ShootingControlPdfService _pdfService = ShootingControlPdfService();

  int _pageIndex = 0;
  String? _selectedSceneId;
  String? _selectedShotId;
  String? _selectedTakeId;
  String? _selectedDayId;
  String _query = '';
  ShotTakeStatus? _statusFilter;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    final scenes = widget.controller.document.sceneSections;
    final firstScene = scenes.isEmpty ? null : scenes.first;
    _selectedSceneId = firstScene?.id;
    final shots = firstScene == null
        ? const <StoryboardShot>[]
        : widget.controller.document.storyboardShotsFor(firstScene.id);
    _selectedShotId = shots.isEmpty ? null : shots.first.id;
    final takes = _selectedShotId == null
        ? const <ShotTake>[]
        : widget.controller.document.shotTakesFor(_selectedShotId!);
    _selectedTakeId = takes.isEmpty ? null : takes.first.id;
    final days = widget.controller.document.shootingDays;
    _selectedDayId = days.isEmpty ? null : days.first.id;
  }

  SceneSection? get _selectedScene {
    final sceneId = _selectedSceneId;
    return sceneId == null
        ? null
        : widget.controller.document.sceneById(sceneId);
  }

  ShotTake? get _selectedTake {
    final shotId = _selectedShotId;
    final takeId = _selectedTakeId;

    if (shotId == null || takeId == null) {
      return null;
    }

    return widget.controller.document.shotTakeById(shotId, takeId);
  }

  List<ShotTake> get _visibleTakes {
    final shotId = _selectedShotId;

    if (shotId == null) {
      return const <ShotTake>[];
    }

    final query = _query.trim().toLowerCase();
    return widget.controller.document.shotTakesFor(shotId).where((take) {
      if (_statusFilter != null && take.status != _statusFilter) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      return <String>[
        '${take.takeNumber}',
        take.status.label,
        take.timecode,
        take.mediaCard,
        take.camera,
        take.fileName,
        take.directorNotes,
        take.cameraNotes,
        take.soundNotes,
        take.rejectionReason,
      ].join('\n').toLowerCase().contains(query);
    }).toList(growable: false);
  }

  void _selectScene(String? sceneId) {
    if (sceneId == null) {
      return;
    }

    final scene = widget.controller.document.sceneById(sceneId);
    final shots = widget.controller.document.storyboardShotsFor(sceneId);
    final shotId = shots.isEmpty ? null : shots.first.id;
    final takes = shotId == null
        ? const <ShotTake>[]
        : widget.controller.document.shotTakesFor(shotId);

    setState(() {
      _selectedSceneId = sceneId;
      _selectedShotId = shotId;
      _selectedTakeId = takes.isEmpty ? null : takes.first.id;
    });

    if (scene != null) {
      widget.onSceneSelected(scene);
    }
  }

  void _selectShot(String? shotId) {
    if (shotId == null) {
      return;
    }

    final takes = widget.controller.document.shotTakesFor(shotId);
    setState(() {
      _selectedShotId = shotId;
      _selectedTakeId = takes.isEmpty ? null : takes.first.id;
    });
  }

  Future<void> _addTake() async {
    final shotId = _selectedShotId;

    if (shotId == null) {
      _showMessage('Сначала создайте кадр в разделе «Раскадровка».');
      return;
    }

    final takeId = widget.controller.createShotTake(
      shotId,
      shootingDayId: _selectedDayId,
    );

    if (takeId == null) {
      return;
    }

    setState(() => _selectedTakeId = takeId);
    final take = widget.controller.document.shotTakeById(shotId, takeId);

    if (take != null) {
      await _editTake(take);
    }
  }

  Future<void> _editTake(ShotTake take) async {
    final edited = await _showTakeEditor(take);

    if (edited == null || !mounted) {
      return;
    }

    widget.controller.updateShotTake(_selectedShotId!, edited);
    setState(() => _selectedTakeId = edited.id);
  }

  Future<ShotTake?> _showTakeEditor(ShotTake take) async {
    final takeNumberController =
        TextEditingController(text: '${take.takeNumber}');
    final timecodeController = TextEditingController(text: take.timecode);
    final durationController = TextEditingController(
      text: _formatNumber(take.durationSeconds),
    );
    final mediaCardController = TextEditingController(text: take.mediaCard);
    final cameraController = TextEditingController(text: take.camera);
    final fileNameController = TextEditingController(text: take.fileName);
    final directorController = TextEditingController(text: take.directorNotes);
    final cameraNotesController = TextEditingController(text: take.cameraNotes);
    final soundController = TextEditingController(text: take.soundNotes);
    final rejectionController =
        TextEditingController(text: take.rejectionReason);
    final costumeController =
        TextEditingController(text: take.costumeContinuity);
    final makeupController = TextEditingController(text: take.makeupContinuity);
    final propsController = TextEditingController(text: take.propsContinuity);
    final positionsController =
        TextEditingController(text: take.actorPositions);
    var status = take.status;
    var rating = take.rating;
    var shootingDayId = take.shootingDayId;
    var photos = List<ContinuityPhoto>.of(take.continuityPhotos);

    final result = await showDialog<ShotTake>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> addPhoto() async {
              try {
                final photo = await _fileService.chooseContinuityPhoto();

                if (photo == null || !dialogContext.mounted) {
                  return;
                }

                setDialogState(() {
                  photos = <ContinuityPhoto>[
                    ...photos,
                    ContinuityPhoto(
                      id: 'photo_${DateTime.now().microsecondsSinceEpoch}',
                      fileName: photo.fileName,
                      mimeType: photo.mimeType,
                      base64Data: photo.base64Data,
                    ),
                  ];
                });
              } catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('$error')),
                  );
                }
              }
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF29292D),
              title: Text('Дубль ${take.takeNumber}'),
              content: SizedBox(
                width: 900,
                height: 680,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _ControlTextField(
                              controller: takeNumberController,
                              label: 'Номер дубля',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<ShotTakeStatus>(
                              initialValue: status,
                              decoration: const InputDecoration(
                                labelText: 'Статус',
                              ),
                              items: ShotTakeStatus.values
                                  .map(
                                    (value) => DropdownMenuItem<ShotTakeStatus>(
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
                            child: DropdownButtonFormField<String?>(
                              initialValue: shootingDayId,
                              decoration: const InputDecoration(
                                labelText: 'Съёмочный день',
                              ),
                              items: <DropdownMenuItem<String?>>[
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Не назначен'),
                                ),
                                ...widget.controller.document.shootingDays.map(
                                  (day) => DropdownMenuItem<String?>(
                                    value: day.id,
                                    child: Text(day.title),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setDialogState(() => shootingDayId = value);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _ControlTextField(
                              controller: timecodeController,
                              label: 'Таймкод',
                              hint: '01:12:34:08',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ControlTextField(
                              controller: durationController,
                              label: 'Длительность, сек',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ControlTextField(
                              controller: mediaCardController,
                              label: 'Карта памяти',
                              hint: 'A012',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ControlTextField(
                              controller: cameraController,
                              label: 'Камера',
                              hint: 'Камера A',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _ControlTextField(
                        controller: fileNameController,
                        label: 'Имя видеофайла',
                        hint: 'A012_C003_0805AB.mov',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          const Text('Оценка режиссёра:'),
                          const SizedBox(width: 8),
                          ...List<Widget>.generate(6, (index) {
                            return IconButton(
                              tooltip: '$index из 5',
                              onPressed: () {
                                setDialogState(() => rating = index);
                              },
                              icon: Icon(
                                index > 0 && index <= rating
                                    ? Icons.star
                                    : Icons.star_border,
                                color: const Color(0xFFE5A93C),
                              ),
                            );
                          }),
                        ],
                      ),
                      const Divider(height: 28),
                      const _SectionTitle('Заметки по дублю'),
                      _ControlTextField(
                        controller: directorController,
                        label: 'Заметки режиссёра',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: _ControlTextField(
                              controller: cameraNotesController,
                              label: 'Заметки оператора',
                              maxLines: 3,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ControlTextField(
                              controller: soundController,
                              label: 'Заметки звукорежиссёра',
                              maxLines: 3,
                            ),
                          ),
                        ],
                      ),
                      if (status == ShotTakeStatus.rejected) ...<Widget>[
                        const SizedBox(height: 10),
                        _ControlTextField(
                          controller: rejectionController,
                          label: 'Причина брака',
                          maxLines: 2,
                        ),
                      ],
                      const Divider(height: 28),
                      const _SectionTitle('Контроль непрерывности'),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: _ControlTextField(
                              controller: costumeController,
                              label: 'Костюм',
                              maxLines: 3,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ControlTextField(
                              controller: makeupController,
                              label: 'Грим и причёска',
                              maxLines: 3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: _ControlTextField(
                              controller: propsController,
                              label: 'Реквизит',
                              maxLines: 3,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ControlTextField(
                              controller: positionsController,
                              label: 'Положение актёров',
                              maxLines: 3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          const _SectionTitle('Фотографии непрерывности'),
                          const Spacer(),
                          OutlinedButton.icon(
                            onPressed: addPhoto,
                            icon: const Icon(Icons.add_a_photo_outlined),
                            label: const Text('Добавить фото'),
                          ),
                        ],
                      ),
                      if (photos.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('Фотографии не добавлены.'),
                        )
                      else
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: photos.map((photo) {
                            final bytes = photo.bytes;
                            return SizedBox(
                              width: 150,
                              child: Card(
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  children: <Widget>[
                                    SizedBox(
                                      height: 90,
                                      width: double.infinity,
                                      child: bytes == null
                                          ? const ColoredBox(
                                              color: Color(0xFF202024),
                                              child: Icon(Icons.broken_image),
                                            )
                                          : Image.memory(bytes,
                                              fit: BoxFit.cover),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        8,
                                        6,
                                        4,
                                        4,
                                      ),
                                      child: Row(
                                        children: <Widget>[
                                          Expanded(
                                            child: Text(
                                              photo.fileName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style:
                                                  const TextStyle(fontSize: 11),
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Удалить фото',
                                            iconSize: 18,
                                            onPressed: () {
                                              setDialogState(() {
                                                photos = photos
                                                    .where(
                                                      (item) =>
                                                          item.id != photo.id,
                                                    )
                                                    .toList(growable: false);
                                              });
                                            },
                                            icon: const Icon(Icons.close),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(growable: false),
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
                      take.copyWith(
                        takeNumber:
                            int.tryParse(takeNumberController.text.trim()) ?? 1,
                        status: status,
                        shootingDayId: shootingDayId,
                        clearShootingDayId: shootingDayId == null,
                        timecode: timecodeController.text,
                        durationSeconds: double.tryParse(
                              durationController.text
                                  .trim()
                                  .replaceAll(',', '.'),
                            ) ??
                            0,
                        mediaCard: mediaCardController.text,
                        camera: cameraController.text,
                        fileName: fileNameController.text,
                        rating: rating,
                        directorNotes: directorController.text,
                        cameraNotes: cameraNotesController.text,
                        soundNotes: soundController.text,
                        rejectionReason: rejectionController.text,
                        costumeContinuity: costumeController.text,
                        makeupContinuity: makeupController.text,
                        propsContinuity: propsController.text,
                        actorPositions: positionsController.text,
                        continuityPhotos: photos,
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

    for (final controller in <TextEditingController>[
      takeNumberController,
      timecodeController,
      durationController,
      mediaCardController,
      cameraController,
      fileNameController,
      directorController,
      cameraNotesController,
      soundController,
      rejectionController,
      costumeController,
      makeupController,
      propsController,
      positionsController,
    ]) {
      controller.dispose();
    }

    return result;
  }

  void _duplicateTake() {
    final shotId = _selectedShotId;
    final takeId = _selectedTakeId;

    if (shotId == null || takeId == null) {
      return;
    }

    final duplicateId = widget.controller.duplicateShotTake(shotId, takeId);

    if (duplicateId != null) {
      setState(() => _selectedTakeId = duplicateId);
    }
  }

  Future<void> _deleteTake() async {
    final shotId = _selectedShotId;
    final takeId = _selectedTakeId;

    if (shotId == null || takeId == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Удалить дубль?'),
            content: const Text(
              'Данные дубля и фотографии непрерывности будут удалены.',
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
        ) ??
        false;

    if (!confirmed || !mounted) {
      return;
    }

    widget.controller.deleteShotTake(shotId, takeId);
    final remaining = widget.controller.document.shotTakesFor(shotId);
    setState(() {
      _selectedTakeId = remaining.isEmpty ? null : remaining.first.id;
    });
  }

  void _markSelected() {
    final shotId = _selectedShotId;
    final take = _selectedTake;

    if (shotId == null || take == null) {
      return;
    }

    widget.controller.updateShotTake(
      shotId,
      take.copyWith(status: ShotTakeStatus.selected),
    );
    setState(() {});
  }

  Future<void> _editJournal() async {
    final dayId = _selectedDayId;

    if (dayId == null) {
      _showMessage('Сначала создайте съёмочный день в разделе «Съёмки».');
      return;
    }

    final current = widget.controller.document.shootingDayJournalFor(dayId);
    final callController = TextEditingController(text: current.actualCrewCall);
    final firstController =
        TextEditingController(text: current.actualFirstShot);
    final wrapController = TextEditingController(text: current.actualWrap);
    final weatherController = TextEditingController(text: current.weather);
    final summaryController = TextEditingController(text: current.summary);
    final incidentsController = TextEditingController(text: current.incidents);
    final backupController = TextEditingController(text: current.mediaBackup);
    final cameraController = TextEditingController(text: current.cameraReport);
    final soundController = TextEditingController(text: current.soundReport);
    final notesController = TextEditingController(text: current.notes);

    final result = await showDialog<ShootingDayJournal>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF29292D),
        title: const Text('Журнал съёмочного дня'),
        content: SizedBox(
          width: 800,
          height: 620,
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _ControlTextField(
                        controller: callController,
                        label: 'Фактический сбор',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ControlTextField(
                        controller: firstController,
                        label: 'Первый кадр',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ControlTextField(
                        controller: wrapController,
                        label: 'Фактическое окончание',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _ControlTextField(
                  controller: weatherController,
                  label: 'Погода и условия',
                ),
                const SizedBox(height: 12),
                _ControlTextField(
                  controller: summaryController,
                  label: 'Итог съёмочного дня',
                  maxLines: 4,
                ),
                const SizedBox(height: 12),
                _ControlTextField(
                  controller: incidentsController,
                  label: 'Инциденты и задержки',
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                _ControlTextField(
                  controller: backupController,
                  label: 'Резервные копии материала',
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: _ControlTextField(
                        controller: cameraController,
                        label: 'Отчёт камеры',
                        maxLines: 3,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ControlTextField(
                        controller: soundController,
                        label: 'Отчёт звука',
                        maxLines: 3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _ControlTextField(
                  controller: notesController,
                  label: 'Общие примечания',
                  maxLines: 3,
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
                ShootingDayJournal(
                  actualCrewCall: callController.text,
                  actualFirstShot: firstController.text,
                  actualWrap: wrapController.text,
                  weather: weatherController.text,
                  summary: summaryController.text,
                  incidents: incidentsController.text,
                  mediaBackup: backupController.text,
                  cameraReport: cameraController.text,
                  soundReport: soundController.text,
                  notes: notesController.text,
                ),
              );
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    for (final controller in <TextEditingController>[
      callController,
      firstController,
      wrapController,
      weatherController,
      summaryController,
      incidentsController,
      backupController,
      cameraController,
      soundController,
      notesController,
    ]) {
      controller.dispose();
    }

    if (result != null && mounted) {
      widget.controller.setShootingDayJournal(dayId, result);
      setState(() {});
    }
  }

  Future<void> _exportEditingCsv() async {
    await _runBusy(() async {
      final path = await _fileService.chooseEditingLogCsvPath(
        projectName: widget.projectName,
      );

      if (path == null) {
        return;
      }

      final csv = _service.buildEditingLogCsv(
        widget.controller.document,
        projectName: widget.projectName,
      );
      final saved = await _fileService.writeCsv(path, csv);

      if (mounted) {
        _showMessage('Монтажная ведомость сохранена: $saved');
      }
    });
  }

  Future<void> _exportJournalCsv() async {
    await _runBusy(() async {
      final path = await _fileService.chooseJournalCsvPath(
        projectName: widget.projectName,
      );

      if (path == null) {
        return;
      }

      final csv = _service.buildShootingDayJournalCsv(
        widget.controller.document,
        projectName: widget.projectName,
      );
      final saved = await _fileService.writeCsv(path, csv);

      if (mounted) {
        _showMessage('Журнал съёмочных дней сохранён: $saved');
      }
    });
  }

  Future<void> _exportPdf() async {
    await _runBusy(() async {
      final path = await _fileService.choosePdfPath(
        projectName: widget.projectName,
      );

      if (path == null) {
        return;
      }

      final bytes = await _pdfService.buildPdf(
        widget.controller.document,
        projectName: widget.projectName,
      );
      final saved = await _fileService.writePdf(path, bytes);

      if (mounted) {
        _showMessage('PDF-отчёт сохранён: $saved');
      }
    });
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_isBusy) {
      return;
    }

    setState(() => _isBusy = true);

    try {
      await action();
    } catch (error) {
      if (mounted) {
        _showMessage('$error');
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

    if (scenes.isEmpty) {
      _selectedSceneId = null;
      _selectedShotId = null;
      _selectedTakeId = null;
      return;
    }

    if (_selectedSceneId == null ||
        widget.controller.document.sceneById(_selectedSceneId!) == null) {
      _selectedSceneId = scenes.first.id;
    }

    final shots = widget.controller.document.storyboardShotsFor(
      _selectedSceneId!,
    );

    if (shots.isEmpty) {
      _selectedShotId = null;
      _selectedTakeId = null;
      return;
    }

    if (_selectedShotId == null ||
        widget.controller.document.storyboardShotById(
              _selectedSceneId!,
              _selectedShotId!,
            ) ==
            null) {
      _selectedShotId = shots.first.id;
    }

    final takes = widget.controller.document.shotTakesFor(_selectedShotId!);

    if (_selectedTakeId == null ||
        widget.controller.document.shotTakeById(
              _selectedShotId!,
              _selectedTakeId!,
            ) ==
            null) {
      _selectedTakeId = takes.isEmpty ? null : takes.first.id;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = _service.summarize(widget.controller.document);

    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      backgroundColor: const Color(0xFF1E1E22),
      child: SizedBox(
        width: 1380,
        height: 850,
        child: Column(
          children: <Widget>[
            _buildHeader(summary),
            const Divider(height: 1),
            Expanded(
              child: IndexedStack(
                index: _pageIndex,
                children: <Widget>[
                  _buildTakesPage(),
                  _buildJournalPage(),
                  _buildReportsPage(summary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ShootingControlSummary summary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: <Widget>[
          const Icon(Icons.video_file_outlined, color: Color(0xFFE5A93C)),
          const SizedBox(width: 10),
          const Text(
            'Контроль съёмок и монтажный учёт',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 20),
          _TopTab(
            label: 'Дубли',
            selected: _pageIndex == 0,
            onPressed: () => setState(() => _pageIndex = 0),
          ),
          _TopTab(
            label: 'Журнал дня',
            selected: _pageIndex == 1,
            onPressed: () => setState(() => _pageIndex = 1),
          ),
          _TopTab(
            label: 'Отчёты',
            selected: _pageIndex == 2,
            onPressed: () => setState(() => _pageIndex = 2),
          ),
          const Spacer(),
          Text(
            '${summary.takeCount} дублей • ${summary.selectedCount} выбрано',
            style: const TextStyle(color: Color(0xFFB8B8BE)),
          ),
          const SizedBox(width: 10),
          IconButton(
            tooltip: 'Отменить',
            onPressed: widget.controller.canUndo ? _undo : null,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: 'Вернуть',
            onPressed: widget.controller.canRedo ? _redo : null,
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

  Widget _buildTakesPage() {
    final scenes = widget.controller.document.sceneSections;
    final scene = _selectedScene;
    final shots = scene == null
        ? const <StoryboardShot>[]
        : widget.controller.document.storyboardShotsFor(scene.id);
    final visibleTakes = _visibleTakes;
    final take = _selectedTake;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedSceneId,
                  decoration: const InputDecoration(labelText: 'Сцена'),
                  items: scenes
                      .map(
                        (item) => DropdownMenuItem<String>(
                          value: item.id,
                          child: Text('${item.number}. ${item.title}'),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _selectScene,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedShotId,
                  decoration: const InputDecoration(labelText: 'Кадр'),
                  items: List<DropdownMenuItem<String>>.generate(
                    shots.length,
                    (index) {
                      final shot = shots[index];
                      return DropdownMenuItem<String>(
                        value: shot.id,
                        child: Text(
                          '${scene?.number}.${index + 1} — '
                          '${shot.title.trim().isEmpty ? shot.shotSize.label : shot.title}',
                        ),
                      );
                    },
                  ),
                  onChanged: _selectShot,
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _selectedShotId == null ? null : _addTake,
                icon: const Icon(Icons.add),
                label: const Text('Добавить дубль'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Поиск по дублям',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<ShotTakeStatus?>(
                  initialValue: _statusFilter,
                  decoration: const InputDecoration(labelText: 'Статус'),
                  items: <DropdownMenuItem<ShotTakeStatus?>>[
                    const DropdownMenuItem<ShotTakeStatus?>(
                      value: null,
                      child: Text('Все статусы'),
                    ),
                    ...ShotTakeStatus.values.map(
                      (value) => DropdownMenuItem<ShotTakeStatus?>(
                        value: value,
                        child: Text(value.label),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _statusFilter = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 370,
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: visibleTakes.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Для выбранного кадра дублей пока нет.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: visibleTakes.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = visibleTakes[index];
                              return Material(
                                color: item.id == _selectedTakeId
                                    ? const Color(0xFF3A352A)
                                    : Colors.transparent,
                                child: ListTile(
                                  selected: item.id == _selectedTakeId,
                                  leading: CircleAvatar(
                                    backgroundColor: _statusColor(item.status),
                                    child: Text('${item.takeNumber}'),
                                  ),
                                  title: Text('Дубль ${item.takeNumber}'),
                                  subtitle: Text(
                                    '${item.status.label} • '
                                    '${_service.formatDuration(item.durationSeconds)}\n'
                                    '${item.fileName.trim().isEmpty ? 'Файл не указан' : item.fileName}',
                                  ),
                                  isThreeLine: true,
                                  trailing:
                                      item.status == ShotTakeStatus.selected
                                          ? const Icon(
                                              Icons.check_circle,
                                              color: Colors.greenAccent,
                                            )
                                          : null,
                                  onTap: () {
                                    setState(() => _selectedTakeId = item.id);
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: take == null
                      ? const Card(
                          margin: EdgeInsets.zero,
                          child: Center(
                            child: Text('Выберите дубль для просмотра.'),
                          ),
                        )
                      : _buildTakeDetails(take),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTakeDetails(ShotTake take) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: _statusColor(take.status),
                  child: Text('${take.takeNumber}'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Дубль ${take.takeNumber}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${take.status.label} • '
                        '${_service.shootingDayLabel(widget.controller.document, take.shootingDayId)}',
                        style: const TextStyle(color: Color(0xFFB8B8BE)),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => unawaited(_editTake(take)),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Изменить'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _duplicateTake,
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Дублировать'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Удалить',
                  onPressed: () => unawaited(_deleteTake()),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const Divider(height: 28),
            Wrap(
              spacing: 20,
              runSpacing: 10,
              children: <Widget>[
                _DetailChip('Таймкод', take.timecode),
                _DetailChip(
                  'Длительность',
                  _service.formatDuration(take.durationSeconds),
                ),
                _DetailChip('Карта', take.mediaCard),
                _DetailChip('Камера', take.camera),
                _DetailChip('Файл', take.fileName),
                _DetailChip('Оценка', '${take.rating}/5'),
                _DetailChip('Фото', '${take.continuityPhotos.length}'),
              ],
            ),
            const SizedBox(height: 18),
            if (take.status != ShotTakeStatus.selected)
              FilledButton.icon(
                onPressed: _markSelected,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Выбрать для монтажа'),
              ),
            const SizedBox(height: 18),
            Expanded(
              child: ListView(
                children: <Widget>[
                  _DetailSection('Заметки режиссёра', take.directorNotes),
                  _DetailSection('Заметки оператора', take.cameraNotes),
                  _DetailSection('Заметки звука', take.soundNotes),
                  if (take.status == ShotTakeStatus.rejected)
                    _DetailSection('Причина брака', take.rejectionReason),
                  const _SectionTitle('Непрерывность'),
                  _DetailSection('Костюм', take.costumeContinuity),
                  _DetailSection('Грим', take.makeupContinuity),
                  _DetailSection('Реквизит', take.propsContinuity),
                  _DetailSection('Положение актёров', take.actorPositions),
                  if (take.continuityPhotos.isNotEmpty)
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: take.continuityPhotos.map((photo) {
                        final bytes = photo.bytes;
                        return SizedBox(
                          width: 180,
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: <Widget>[
                                SizedBox(
                                  height: 110,
                                  width: double.infinity,
                                  child: bytes == null
                                      ? const ColoredBox(
                                          color: Color(0xFF202024),
                                          child: Icon(Icons.broken_image),
                                        )
                                      : Image.memory(bytes, fit: BoxFit.cover),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    photo.fileName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(growable: false),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJournalPage() {
    final days = widget.controller.document.shootingDays;
    final dayId = _selectedDayId;
    final day = dayId == null
        ? null
        : widget.controller.document.shootingDayById(dayId);
    final journal = dayId == null
        ? const ShootingDayJournal()
        : widget.controller.document.shootingDayJournalFor(dayId);
    final takes = dayId == null
        ? const <NumberedShotTake>[]
        : _service.takesForDay(widget.controller.document, dayId);

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              SizedBox(
                width: 420,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedDayId,
                  decoration: const InputDecoration(
                    labelText: 'Съёмочный день',
                  ),
                  items: days
                      .map(
                        (item) => DropdownMenuItem<String>(
                          value: item.id,
                          child: Text(
                            '${item.title}${item.date.isEmpty ? '' : ' • ${item.date}'}',
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    setState(() => _selectedDayId = value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: day == null ? null : _editJournal,
                icon: const Icon(Icons.edit_note_outlined),
                label: const Text('Заполнить журнал'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: day == null
                ? const Card(
                    child: Center(
                      child: Text(
                        'Съёмочные дни пока не созданы.\n'
                        'Добавьте их в разделе «Съёмки».',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : Row(
                    children: <Widget>[
                      Expanded(
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: ListView(
                              children: <Widget>[
                                Text(
                                  day.title,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${day.date.isEmpty ? 'Дата не указана' : day.date} • '
                                  '${day.location.isEmpty ? 'Локация не указана' : day.location}',
                                  style: const TextStyle(
                                    color: Color(0xFFB8B8BE),
                                  ),
                                ),
                                const Divider(height: 28),
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 10,
                                  children: <Widget>[
                                    _DetailChip(
                                      'Фактический сбор',
                                      journal.actualCrewCall,
                                    ),
                                    _DetailChip(
                                      'Первый кадр',
                                      journal.actualFirstShot,
                                    ),
                                    _DetailChip(
                                      'Окончание',
                                      journal.actualWrap,
                                    ),
                                    _DetailChip('Погода', journal.weather),
                                    _DetailChip('Дублей', '${takes.length}'),
                                    _DetailChip(
                                      'Выбрано',
                                      '${takes.where((entry) => entry.take.status == ShotTakeStatus.selected).length}',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                _DetailSection('Итог дня', journal.summary),
                                _DetailSection(
                                  'Инциденты и задержки',
                                  journal.incidents,
                                ),
                                _DetailSection(
                                  'Резервные копии',
                                  journal.mediaBackup,
                                ),
                                _DetailSection(
                                  'Отчёт камеры',
                                  journal.cameraReport,
                                ),
                                _DetailSection(
                                  'Отчёт звука',
                                  journal.soundReport,
                                ),
                                _DetailSection('Примечания', journal.notes),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      SizedBox(
                        width: 430,
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Padding(
                                padding: EdgeInsets.all(14),
                                child: Text(
                                  'Материал дня',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const Divider(height: 1),
                              Expanded(
                                child: takes.isEmpty
                                    ? const Center(
                                        child: Text(
                                          'Дубли к этому дню не назначены.',
                                        ),
                                      )
                                    : ListView.separated(
                                        itemCount: takes.length,
                                        separatorBuilder: (_, __) =>
                                            const Divider(height: 1),
                                        itemBuilder: (context, index) {
                                          final entry = takes[index];
                                          return Material(
                                            color: Colors.transparent,
                                            child: ListTile(
                                              leading: CircleAvatar(
                                                backgroundColor: _statusColor(
                                                  entry.take.status,
                                                ),
                                                child: Text(
                                                  '${entry.take.takeNumber}',
                                                ),
                                              ),
                                              title: Text(entry.takeLabel),
                                              subtitle: Text(
                                                '${entry.take.status.label} • '
                                                '${entry.take.fileName.isEmpty ? 'Файл не указан' : entry.take.fileName}',
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsPage(ShootingControlSummary summary) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: <Widget>[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _SummaryCard(label: 'Кадров', value: '${summary.shotCount}'),
              _SummaryCard(label: 'Дублей', value: '${summary.takeCount}'),
              _SummaryCard(
                label: 'Снято',
                value: '${summary.recordedCount}',
              ),
              _SummaryCard(
                label: 'Брак',
                value: '${summary.rejectedCount}',
              ),
              _SummaryCard(
                label: 'Выбрано',
                value: '${summary.selectedCount}',
              ),
              _SummaryCard(
                label: 'Без выбранного дубля',
                value: '${summary.shotsWithoutSelectedTake}',
              ),
              _SummaryCard(
                label: 'Объём материала',
                value: _service.formatDuration(summary.totalRecordedSeconds),
              ),
            ],
          ),
          const SizedBox(height: 30),
          const Text(
            'Экспорт документов',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _ExportCard(
            icon: Icons.table_view_outlined,
            title: 'Монтажная ведомость CSV',
            description:
                'Все дубли, статусы, файлы, таймкоды, оценки и заметки.',
            onPressed: _isBusy ? null : _exportEditingCsv,
          ),
          _ExportCard(
            icon: Icons.event_note_outlined,
            title: 'Журнал съёмочных дней CSV',
            description:
                'Фактическое время, материал дня, инциденты и резервные копии.',
            onPressed: _isBusy ? null : _exportJournalCsv,
          ),
          _ExportCard(
            icon: Icons.picture_as_pdf_outlined,
            title: 'Отчёт о снятом материале PDF',
            description:
                'Печатная монтажная ведомость с выбранными дублями и непрерывностью.',
            onPressed: _isBusy ? null : _exportPdf,
          ),
          if (_isBusy) ...<Widget>[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }

  Color _statusColor(ShotTakeStatus status) {
    return switch (status) {
      ShotTakeStatus.planned => const Color(0xFF66666D),
      ShotTakeStatus.recorded => const Color(0xFF315C8A),
      ShotTakeStatus.rejected => const Color(0xFF8A3B3B),
      ShotTakeStatus.selected => const Color(0xFF347A50),
    };
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return '${value.toInt()}';
    }

    return value.toStringAsFixed(2);
  }
}

class _TopTab extends StatelessWidget {
  const _TopTab({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor:
              selected ? const Color(0xFF3A352A) : Colors.transparent,
          foregroundColor:
              selected ? const Color(0xFFE5A93C) : const Color(0xFFCCCCCC),
        ),
        child: Text(label),
      ),
    );
  }
}

class _ControlTextField extends StatelessWidget {
  const _ControlTextField({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF25252A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3B3B41)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF9999A1)),
          ),
          const SizedBox(height: 2),
          Text(value.trim().isEmpty ? '—' : value),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          SelectableText(value.trim()),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(color: Color(0xFF9999A1)),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExportCard extends StatelessWidget {
  const _ExportCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFE5A93C)),
        title: Text(title),
        subtitle: Text(description),
        trailing: FilledButton(
          onPressed: onPressed,
          child: const Text('Экспорт'),
        ),
      ),
    );
  }
}
