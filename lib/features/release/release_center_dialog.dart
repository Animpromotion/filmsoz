import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:filmsoz_studio/core/release/app_info.dart';
import 'package:filmsoz_studio/core/release/app_settings.dart';
import 'package:filmsoz_studio/core/release/app_settings_service.dart';
import 'package:filmsoz_studio/core/release/error_log_service.dart';
import 'package:filmsoz_studio/core/release/full_backup_service.dart';
import 'package:filmsoz_studio/core/release/project_diagnostics_service.dart';
import 'package:filmsoz_studio/core/release/project_recovery_service.dart';
import 'package:filmsoz_studio/core/release/session_recovery_service.dart';
import 'package:filmsoz_studio/features/screenplay/editor/controller/screenplay_editor_controller.dart';
import 'package:flutter/material.dart';

Future<void> showFilmsozReleaseCenter({
  required BuildContext context,
  required ScreenplayEditorController controller,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => FilmsozReleaseCenterDialog(
      controller: controller,
    ),
  );
}

class FilmsozReleaseCenterDialog extends StatefulWidget {
  const FilmsozReleaseCenterDialog({
    super.key,
    required this.controller,
  });

  final ScreenplayEditorController controller;

  @override
  State<FilmsozReleaseCenterDialog> createState() =>
      _FilmsozReleaseCenterDialogState();
}

class _FilmsozReleaseCenterDialogState extends State<FilmsozReleaseCenterDialog>
    with SingleTickerProviderStateMixin {
  static const XTypeGroup _filmsozTypeGroup = XTypeGroup(
    label: 'Filmsoz project',
    extensions: <String>['filmsoz'],
  );

  final FilmsozAppSettingsService _settingsService =
      const FilmsozAppSettingsService();
  final FilmsozErrorLogService _logService = const FilmsozErrorLogService();
  final FilmsozProjectDiagnosticsService _diagnosticsService =
      const FilmsozProjectDiagnosticsService();
  final FilmsozProjectRecoveryService _recoveryService =
      const FilmsozProjectRecoveryService();
  final FilmsozFullBackupService _backupService =
      const FilmsozFullBackupService();
  final FilmsozSessionRecoveryService _sessionService =
      const FilmsozSessionRecoveryService();

  late final TabController _tabController;
  late final TextEditingController _projectsDirectoryController;
  late final TextEditingController _backupsDirectoryController;

  FilmsozAppSettings _settings = const FilmsozAppSettings();
  FilmsozProjectDiagnosticReport? _diagnosticReport;
  List<FilmsozErrorLogEntry> _logEntries = const <FilmsozErrorLogEntry>[];
  FilmsozSessionState _sessionState = const FilmsozSessionState(
    previousSessionWasUnclean: false,
  );
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _projectsDirectoryController = TextEditingController();
    _backupsDirectoryController = TextEditingController();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      final settings = await _settingsService.load();
      final logs = await _logService.readRecent(maxEntries: 100);
      final session = await _sessionService.readState();

      if (!mounted) {
        return;
      }

      setState(() {
        _settings = settings;
        _projectsDirectoryController.text = settings.projectsDirectory;
        _backupsDirectoryController.text = settings.backupsDirectory;
        _logEntries = logs;
        _sessionState = session;
        _diagnosticReport = _diagnosticsService.inspect(
          widget.controller.document,
        );
        _loading = false;
      });
    } catch (error, stackTrace) {
      await _logService.record('release_center_init', error, stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _diagnosticReport = _diagnosticsService.inspect(
          widget.controller.document,
        );
        _loading = false;
      });
      _showMessage('Часть служебных данных не удалось загрузить: $error');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _projectsDirectoryController.dispose();
    _backupsDirectoryController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF242428),
      insetPadding: const EdgeInsets.all(20),
      child: SizedBox(
        width: 1120,
        height: 760,
        child: Column(
          children: <Widget>[
            _buildHeader(),
            Material(
              color: const Color(0xFF2D2D31),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: const <Widget>[
                  Tab(icon: Icon(Icons.settings_outlined), text: 'Настройки'),
                  Tab(
                      icon: Icon(Icons.health_and_safety_outlined),
                      text: 'Проверка'),
                  Tab(
                      icon: Icon(Icons.restore_outlined),
                      text: 'Восстановление'),
                  Tab(
                      icon: Icon(Icons.article_outlined),
                      text: 'Журнал ошибок'),
                  Tab(icon: Icon(Icons.info_outline), text: 'О программе'),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: <Widget>[
                        _buildSettingsTab(),
                        _buildDiagnosticsTab(),
                        _buildRecoveryTab(),
                        _buildLogsTab(),
                        _buildAboutTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: Color(0xFF202023),
        border: Border(
          bottom: BorderSide(color: Color(0xFF3C3C42)),
        ),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.verified_outlined, color: Color(0xFFE5A93C)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Стабильность и выпуск Filmsoz',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            FilmsozAppInfo.displayVersion,
            style: const TextStyle(color: Color(0xFFAAAAAF)),
          ),
          const SizedBox(width: 10),
          IconButton(
            tooltip: 'Закрыть',
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: <Widget>[
        _sectionTitle('Автосохранение и восстановление'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Expanded(child: Text('Интервал автосохранения')),
                    DropdownButton<int>(
                      value: const <int>[10, 30, 60, 120, 300]
                              .contains(_settings.autosaveSeconds)
                          ? _settings.autosaveSeconds
                          : 30,
                      items: const <DropdownMenuItem<int>>[
                        DropdownMenuItem(value: 10, child: Text('10 сек.')),
                        DropdownMenuItem(value: 30, child: Text('30 сек.')),
                        DropdownMenuItem(value: 60, child: Text('1 мин.')),
                        DropdownMenuItem(value: 120, child: Text('2 мин.')),
                        DropdownMenuItem(value: 300, child: Text('5 мин.')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _settings = _settings.copyWith(
                              autosaveSeconds: value,
                            );
                          });
                        }
                      },
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title:
                      const Text('Восстанавливать автосохранение после сбоя'),
                  value: _settings.recoveryEnabled,
                  onChanged: (value) {
                    setState(() {
                      _settings = _settings.copyWith(recoveryEnabled: value);
                    });
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Показывать подсказки редактора'),
                  value: _settings.showEditorHints,
                  onChanged: (value) {
                    setState(() {
                      _settings = _settings.copyWith(showEditorHints: value);
                    });
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Компактная верхняя панель'),
                  value: _settings.compactToolbar,
                  onChanged: (value) {
                    setState(() {
                      _settings = _settings.copyWith(compactToolbar: value);
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _sectionTitle('Папки по умолчанию'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: <Widget>[
                _directoryField(
                  label: 'Проекты',
                  controller: _projectsDirectoryController,
                  onChoose: () => _chooseDirectory(
                    _projectsDirectoryController,
                  ),
                ),
                const SizedBox(height: 12),
                _directoryField(
                  label: 'Полные резервные копии',
                  controller: _backupsDirectoryController,
                  onChoose: () => _chooseDirectory(
                    _backupsDirectoryController,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            const Spacer(),
            FilledButton.icon(
              onPressed: _busy ? null : _saveSettings,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Сохранить настройки'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _directoryField({
    required String label,
    required TextEditingController controller,
    required VoidCallback onChoose,
  }) {
    return Row(
      children: <Widget>[
        SizedBox(width: 190, child: Text(label)),
        Expanded(
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Системная папка Filmsoz',
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: onChoose,
          icon: const Icon(Icons.folder_open_outlined),
          label: const Text('Выбрать'),
        ),
      ],
    );
  }

  Future<void> _chooseDirectory(TextEditingController controller) async {
    try {
      final result = await getDirectoryPath(
        initialDirectory:
            controller.text.trim().isEmpty ? null : controller.text.trim(),
        confirmButtonText: 'Выбрать папку',
        canCreateDirectories: true,
      );

      if (result != null && mounted) {
        setState(() => controller.text = result);
      }
    } catch (error, stackTrace) {
      await _logService.record('directory_picker', error, stackTrace);
      _showMessage('Не удалось открыть выбор папки: $error');
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _busy = true);

    try {
      final settings = _settings.copyWith(
        projectsDirectory: _projectsDirectoryController.text,
        backupsDirectory: _backupsDirectoryController.text,
      );
      await _settingsService.save(settings);
      await _logService.prune(maxFiles: settings.maxErrorLogFiles);
      await widget.controller.reloadApplicationSettings();

      if (mounted) {
        setState(() => _settings = settings);
      }

      _showMessage('Настройки сохранены и применены.');
    } catch (error, stackTrace) {
      await _logService.record('settings', error, stackTrace);
      _showMessage('Не удалось сохранить настройки: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Widget _buildDiagnosticsTab() {
    final report = _diagnosticReport ??
        _diagnosticsService.inspect(widget.controller.document);

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _summaryCard(
                  'Сцены',
                  '${report.sceneCount}',
                  Icons.movie_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _summaryCard(
                  'Блоки',
                  '${report.blockCount}',
                  Icons.segment,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _summaryCard(
                  'Размер',
                  _formatBytes(report.approximateBytes),
                  Icons.storage_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _summaryCard(
                  'Связи',
                  report.orphanRecordCount == 0
                      ? 'Исправны'
                      : '${report.orphanRecordCount} лишних',
                  Icons.account_tree_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: _busy ? null : _refreshDiagnostics,
                icon: const Icon(Icons.refresh),
                label: const Text('Проверить снова'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _busy ? null : _optimizeProject,
                icon: const Icon(Icons.auto_fix_high_outlined),
                label: const Text('Оптимизировать и исправить'),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _busy ? null : _createFullBackup,
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Полная резервная копия'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Card(
              child: ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: report.issues.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final issue = report.issues[index];
                  return ListTile(
                    leading: Icon(
                      issue.isError
                          ? Icons.error_outline
                          : issue.code == 'healthy'
                              ? Icons.check_circle_outline
                              : Icons.info_outline,
                      color: issue.isError
                          ? Colors.redAccent
                          : issue.code == 'healthy'
                              ? Colors.greenAccent
                              : const Color(0xFFE5A93C),
                    ),
                    title: Text(issue.message),
                    subtitle: Text(issue.code),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _refreshDiagnostics() {
    setState(() {
      _diagnosticReport = _diagnosticsService.inspect(
        widget.controller.document,
      );
    });
  }

  Future<void> _optimizeProject() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Оптимизировать проект?'),
            content: const Text(
              'Filmsoz удалит устаревшие связи, повреждённые встроенные '
              'изображения и старые служебные записи. Операцию можно отменить '
              'через Ctrl+Z.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Оптимизировать'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) {
      return;
    }

    setState(() => _busy = true);

    try {
      final result = _diagnosticsService.optimize(
        widget.controller.document,
        maxCheckpoints: _settings.maxProjectCheckpoints,
      );
      widget.controller.replaceWithVersionedDocument(
        result.document,
        summary: 'Оптимизирован и проверен проект',
        preserveCurrentCheckpoints: false,
      );

      if (mounted) {
        setState(() {
          _diagnosticReport = _diagnosticsService.inspect(
            widget.controller.document,
          );
        });
      }

      _showMessage(
        'Оптимизация завершена: удалено ${result.removedRecords}, '
        'освобождено ${_formatBytes(result.savedBytes < 0 ? 0 : result.savedBytes)}.',
      );
    } catch (error, stackTrace) {
      await _logService.record('project_optimization', error, stackTrace);
      _showMessage('Ошибка оптимизации: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _createFullBackup() async {
    setState(() => _busy = true);

    try {
      final filePath = await _backupService.chooseSavePath(
        projectName: widget.controller.projectName,
        settings: _settings,
      );

      if (filePath == null || !mounted) {
        return;
      }

      final savedPath = await _backupService.write(
        filePath: filePath,
        document: widget.controller.document,
        projectName: widget.controller.projectName,
        projectPath: widget.controller.projectPath,
        settings: _settings,
      );
      _showMessage('Полная резервная копия создана: $savedPath');
    } catch (error, stackTrace) {
      await _logService.record('full_backup', error, stackTrace);
      _showMessage('Не удалось создать резервную копию: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Widget _buildRecoveryTab() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: <Widget>[
        Card(
          child: ListTile(
            leading: Icon(
              _sessionState.previousSessionWasUnclean
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_outline,
              color: _sessionState.previousSessionWasUnclean
                  ? Colors.orangeAccent
                  : Colors.greenAccent,
            ),
            title: Text(
              _sessionState.previousSessionWasUnclean
                  ? 'Предыдущий сеанс завершился некорректно'
                  : 'Предыдущий сеанс завершился штатно',
            ),
            subtitle: Text(
              _sessionState.previousStartedAt == null
                  ? 'Данные о времени отсутствуют.'
                  : 'Запуск: ${_sessionState.previousStartedAt!.toLocal()}',
            ),
          ),
        ),
        const SizedBox(height: 16),
        _sectionTitle('Восстановление повреждённого проекта'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Открывает старый или частично повреждённый .filmsoz, '
                    'мигрирует структуру и удаляет недействительные связи.',
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: _busy ? null : _recoverProjectFile,
                  icon: const Icon(Icons.healing_outlined),
                  label: const Text('Выбрать .filmsoz'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _sectionTitle('Восстановление полной копии'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Восстанавливает документ и служебные данные из файла '
                    '.filmsozbackup. Перед заменой Filmsoz создаст '
                    'автоматическую копию текущего проекта.',
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _restoreFullBackup,
                  icon: const Icon(Icons.settings_backup_restore),
                  label: const Text('Открыть копию'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _recoverProjectFile() async {
    setState(() => _busy = true);

    try {
      final file = await openFile(
        acceptedTypeGroups: const <XTypeGroup>[_filmsozTypeGroup],
        initialDirectory: _settings.projectsDirectory.trim().isEmpty
            ? null
            : _settings.projectsDirectory.trim(),
        confirmButtonText: 'Восстановить',
      );

      if (file == null || !mounted) {
        return;
      }

      await widget.controller.createAutomaticBackupNow();
      final result = await _recoveryService.recoverFile(file.path);
      widget.controller.replaceWithImportedDocument(
        result.document,
        sourceName: 'Восстановленный проект',
      );
      _refreshDiagnostics();
      _showMessage(
        'Проект восстановлен. Исправлений: ${result.messages.length}. '
        'Сохрани его под новым именем.',
      );
    } catch (error, stackTrace) {
      await _logService.record('project_recovery', error, stackTrace);
      _showMessage('Не удалось восстановить проект: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _restoreFullBackup() async {
    setState(() => _busy = true);

    try {
      final filePath = await _backupService.chooseOpenPath(settings: _settings);

      if (filePath == null || !mounted) {
        return;
      }

      await widget.controller.createAutomaticBackupNow();
      final backup = await _backupService.read(filePath);
      widget.controller.replaceWithImportedDocument(
        backup.document,
        sourceName: '${backup.projectName} — восстановлено',
      );
      _refreshDiagnostics();
      _showMessage('Полная резервная копия восстановлена.');
    } catch (error, stackTrace) {
      await _logService.record('backup_restore', error, stackTrace);
      _showMessage('Не удалось восстановить копию: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Widget _buildLogsTab() {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('Записей: ${_logEntries.length}'),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _busy ? null : _reloadLogs,
                icon: const Icon(Icons.refresh),
                label: const Text('Обновить'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _busy || _logEntries.isEmpty ? null : _clearLogs,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Очистить'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              child: _logEntries.isEmpty
                  ? const Center(
                      child: Text('Ошибок приложения пока не записано.'),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: _logEntries.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final entry = _logEntries[index];
                        return ExpansionTile(
                          leading: const Icon(Icons.bug_report_outlined),
                          title: Text(entry.message),
                          subtitle: Text(
                            '${entry.category} • ${entry.timestamp.toLocal()}',
                          ),
                          children: <Widget>[
                            if (entry.stackTrace.trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: SelectableText(
                                  entry.stackTrace,
                                  style: const TextStyle(
                                    fontFamily: 'Courier New',
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _reloadLogs() async {
    try {
      final logs = await _logService.readRecent(maxEntries: 100);

      if (mounted) {
        setState(() => _logEntries = logs);
      }
    } catch (error, stackTrace) {
      await _logService.record('log_reload', error, stackTrace);
      _showMessage('Не удалось прочитать журнал ошибок: $error');
    }
  }

  Future<void> _clearLogs() async {
    try {
      await _logService.clear();

      if (mounted) {
        setState(() => _logEntries = const <FilmsozErrorLogEntry>[]);
      }
    } catch (error, stackTrace) {
      await _logService.record('log_clear', error, stackTrace);
      _showMessage('Не удалось очистить журнал ошибок: $error');
    }
  }

  Widget _buildAboutTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        const Icon(
          Icons.movie_filter_outlined,
          size: 72,
          color: Color(0xFFE5A93C),
        ),
        const SizedBox(height: 12),
        const Text(
          FilmsozAppInfo.name,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          FilmsozAppInfo.displayVersion,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFAAAAAF)),
        ),
        const SizedBox(height: 24),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Text(
              'Filmsoz Studio — настольная среда для разработки сценария, '
              'подготовки съёмок, раскадровки, контроля материала, '
              'постпродакшна и командной работы. Формат проекта V3 '
              'поддерживает автоматическую миграцию старых файлов.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            Chip(label: Text('Windows Release')),
            Chip(label: Text('Fountain')),
            Chip(label: Text('PDF')),
            Chip(label: Text('Раскадровка')),
            Chip(label: Text('Производство')),
            Chip(label: Text('Постпродакшн')),
            Chip(label: Text('Резервные копии')),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          FilmsozAppInfo.copyright,
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF8E8E93)),
        ),
      ],
    );
  }

  Widget _sectionTitle(String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        value,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _summaryCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            Icon(icon, color: const Color(0xFFE5A93C)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(color: Color(0xFFAAAAAF)),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes Б';
    }

    final kilobytes = bytes / 1024;

    if (kilobytes < 1024) {
      return '${kilobytes.toStringAsFixed(1)} КБ';
    }

    return '${(kilobytes / 1024).toStringAsFixed(1)} МБ';
  }
}
