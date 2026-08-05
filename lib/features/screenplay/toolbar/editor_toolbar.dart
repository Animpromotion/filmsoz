import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

class EditorToolbar extends StatelessWidget {
  const EditorToolbar({
    super.key,
    required this.projectName,
    required this.isDirty,
    required this.recentProjects,
    required this.onNewProject,
    required this.onOpenProject,
    required this.onOpenRecentProject,
    required this.onSave,
    required this.onSaveAs,
    required this.onImportFountain,
    required this.onExportFountain,
    required this.onExportPdf,
    required this.onExportProductionReport,
    required this.onOpenSceneBoard,
    required this.onOpenProductionPlanning,
    required this.onOpenProductionManagement,
    required this.onOpenStoryboard,
    required this.onOpenShootingControl,
    required this.onOpenPostProduction,
    required this.onOpenVersioning,
    required this.onUndo,
    required this.onRedo,
    required this.isSaving,
    required this.canUndo,
    required this.canRedo,
  });

  final String projectName;
  final bool isDirty;
  final List<String> recentProjects;

  final VoidCallback onNewProject;
  final VoidCallback onOpenProject;
  final ValueChanged<String> onOpenRecentProject;
  final VoidCallback onSave;
  final VoidCallback onSaveAs;
  final VoidCallback onImportFountain;
  final VoidCallback onExportFountain;
  final VoidCallback onExportPdf;
  final VoidCallback onExportProductionReport;
  final VoidCallback onOpenSceneBoard;
  final VoidCallback onOpenProductionPlanning;
  final VoidCallback onOpenProductionManagement;
  final VoidCallback onOpenStoryboard;
  final VoidCallback onOpenShootingControl;
  final VoidCallback onOpenPostProduction;
  final VoidCallback onOpenVersioning;
  final VoidCallback onUndo;
  final VoidCallback onRedo;

  final bool isSaving;
  final bool canUndo;
  final bool canRedo;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      color: const Color(0xFF3C3C3C),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              primary: false,
              child: Row(
                children: [
                  _buildFileMenu(context),
                  _buildMenuButton('Правка'),
                  _buildMenuButton(
                    'Структура',
                    onPressed: onOpenSceneBoard,
                    tooltip: 'Структура фильма (Ctrl+Shift+B)',
                  ),
                  _buildMenuButton(
                    'Съёмки',
                    onPressed: onOpenProductionPlanning,
                    tooltip: 'Производственное планирование (Ctrl+Shift+P)',
                  ),
                  _buildMenuButton(
                    'Команда',
                    onPressed: onOpenProductionManagement,
                    tooltip: 'Команда, актёры и бюджет (Ctrl+Shift+T)',
                  ),
                  _buildMenuButton(
                    'Раскадровка',
                    onPressed: onOpenStoryboard,
                    tooltip: 'Монтажный сценарий и раскадровка (Ctrl+Shift+K)',
                  ),
                  _buildMenuButton(
                    'Материал',
                    onPressed: onOpenShootingControl,
                    tooltip: 'Контроль съёмок и монтажный учёт (Ctrl+Shift+L)',
                  ),
                  _buildMenuButton(
                    'Пост',
                    onPressed: onOpenPostProduction,
                    tooltip: 'Постпродакшн и контроль монтажа (Ctrl+Shift+U)',
                  ),
                  _buildMenuButton(
                    'Версии',
                    onPressed: onOpenVersioning,
                    tooltip: 'Версии и командная работа (Ctrl+Shift+H)',
                  ),
                  _buildMenuButton('Формат'),
                  _buildMenuButton('AI'),
                  _buildExportMenu(),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          const VerticalDivider(
            width: 1,
            thickness: 1,
            indent: 7,
            endIndent: 7,
            color: Color(0xFF555555),
          ),
          const SizedBox(width: 6),
          _buildHistoryButton(
            icon: Icons.undo,
            tooltip: 'Отменить (Ctrl+Z)',
            onPressed: canUndo ? onUndo : null,
          ),
          _buildHistoryButton(
            icon: Icons.redo,
            tooltip: 'Вернуть (Ctrl+Y / Ctrl+Shift+Z)',
            onPressed: canRedo ? onRedo : null,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: _buildProjectStatus(),
          ),
          const SizedBox(width: 8),
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildProjectStatus() {
    return Center(
      child: Tooltip(
        message: isDirty
            ? 'Есть изменения, не сохранённые в файле проекта'
            : 'Проект сохранён',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                projectName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFE0E0E0),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isDirty) ...[
              const SizedBox(width: 6),
              const Text(
                '●',
                style: TextStyle(
                  color: Color(0xFFE5A93C),
                  fontSize: 9,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return TextButton.icon(
      onPressed: isSaving ? null : onSave,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 4,
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: const Color(0xFFE0E0E0),
        disabledForegroundColor: const Color(0xFF888888),
      ),
      icon: isSaving
          ? const SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
              ),
            )
          : const Icon(
              Icons.save_outlined,
              size: 16,
            ),
      label: Text(
        isSaving ? 'Сохранение...' : 'Сохранить',
        style: const TextStyle(
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildFileMenu(BuildContext context) {
    return PopupMenuButton<_FileMenuSelection>(
      tooltip: 'Файл',
      color: const Color(0xFF303033),
      onSelected: (selection) {
        switch (selection.action) {
          case _FileMenuAction.newProject:
            onNewProject();
            break;

          case _FileMenuAction.openProject:
            onOpenProject();
            break;

          case _FileMenuAction.importFountain:
            onImportFountain();
            break;

          case _FileMenuAction.saveProject:
            onSave();
            break;

          case _FileMenuAction.saveAsProject:
            onSaveAs();
            break;

          case _FileMenuAction.openRecentProject:
            final recentPath = selection.recentPath;

            if (recentPath != null) {
              onOpenRecentProject(recentPath);
            }
            break;
        }
      },
      itemBuilder: (context) {
        final entries = <PopupMenuEntry<_FileMenuSelection>>[
          const PopupMenuItem<_FileMenuSelection>(
            value: _FileMenuSelection(
              _FileMenuAction.newProject,
            ),
            child: _MenuRow(
              icon: Icons.note_add_outlined,
              label: 'Новый сценарий',
              shortcut: 'Ctrl+N',
            ),
          ),
          const PopupMenuItem<_FileMenuSelection>(
            value: _FileMenuSelection(
              _FileMenuAction.openProject,
            ),
            child: _MenuRow(
              icon: Icons.folder_open_outlined,
              label: 'Открыть...',
              shortcut: 'Ctrl+O',
            ),
          ),
          const PopupMenuItem<_FileMenuSelection>(
            value: _FileMenuSelection(
              _FileMenuAction.importFountain,
            ),
            child: _MenuRow(
              icon: Icons.file_download_outlined,
              label: 'Импорт Fountain...',
              shortcut: 'Ctrl+Alt+O',
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem<_FileMenuSelection>(
            value: _FileMenuSelection(
              _FileMenuAction.saveProject,
            ),
            child: _MenuRow(
              icon: Icons.save_outlined,
              label: 'Сохранить',
              shortcut: 'Ctrl+S',
            ),
          ),
          const PopupMenuItem<_FileMenuSelection>(
            value: _FileMenuSelection(
              _FileMenuAction.saveAsProject,
            ),
            child: _MenuRow(
              icon: Icons.save_as_outlined,
              label: 'Сохранить как...',
              shortcut: 'Ctrl+Shift+S',
            ),
          ),
        ];

        if (recentProjects.isNotEmpty) {
          entries.add(
            const PopupMenuDivider(),
          );

          entries.add(
            const PopupMenuItem<_FileMenuSelection>(
              enabled: false,
              height: 30,
              child: Text(
                'НЕДАВНИЕ ПРОЕКТЫ',
                style: TextStyle(
                  color: Color(0xFF8F8F8F),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              ),
            ),
          );

          for (final recentPath in recentProjects.take(5)) {
            entries.add(
              PopupMenuItem<_FileMenuSelection>(
                value: _FileMenuSelection.recent(
                  recentPath,
                ),
                child: Tooltip(
                  message: recentPath,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.history,
                        size: 16,
                        color: Color(0xFFBDBDBD),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          path.basenameWithoutExtension(
                            recentPath,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFDDDDDD),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        }

        return entries;
      },
      child: const Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 9,
        ),
        child: Text(
          'Файл',
          style: TextStyle(
            color: Color(0xFFCCCCCC),
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildExportMenu() {
    return PopupMenuButton<_ExportMenuAction>(
      tooltip: 'Экспорт',
      color: const Color(0xFF303033),
      onSelected: (action) {
        switch (action) {
          case _ExportMenuAction.pdf:
            onExportPdf();
            break;
          case _ExportMenuAction.productionReport:
            onExportProductionReport();
            break;
          case _ExportMenuAction.storyboard:
            onOpenStoryboard();
            break;
          case _ExportMenuAction.postProduction:
            onOpenPostProduction();
            break;
          case _ExportMenuAction.fountain:
            onExportFountain();
            break;
        }
      },
      itemBuilder: (context) {
        return const <PopupMenuEntry<_ExportMenuAction>>[
          PopupMenuItem<_ExportMenuAction>(
            value: _ExportMenuAction.pdf,
            child: _MenuRow(
              icon: Icons.picture_as_pdf_outlined,
              label: 'PDF и печать...',
              shortcut: 'Ctrl+P',
            ),
          ),
          PopupMenuDivider(),
          PopupMenuItem<_ExportMenuAction>(
            value: _ExportMenuAction.productionReport,
            child: _MenuRow(
              icon: Icons.table_view_outlined,
              label: 'Производственный отчёт...',
              shortcut: 'Ctrl+Alt+R',
            ),
          ),
          PopupMenuDivider(),
          PopupMenuItem<_ExportMenuAction>(
            value: _ExportMenuAction.storyboard,
            child: _MenuRow(
              icon: Icons.movie_creation_outlined,
              label: 'Монтажный сценарий и раскадровка...',
              shortcut: 'Ctrl+Shift+K',
            ),
          ),
          PopupMenuDivider(),
          PopupMenuItem<_ExportMenuAction>(
            value: _ExportMenuAction.postProduction,
            child: _MenuRow(
              icon: Icons.edit_note_outlined,
              label: 'Постпродакшн и контроль монтажа...',
              shortcut: 'Ctrl+Shift+U',
            ),
          ),
          PopupMenuDivider(),
          PopupMenuItem<_ExportMenuAction>(
            value: _ExportMenuAction.fountain,
            child: _MenuRow(
              icon: Icons.file_upload_outlined,
              label: 'Экспорт в Fountain...',
              shortcut: 'Ctrl+Alt+E',
            ),
          ),
        ];
      },
      child: const Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 9,
        ),
        child: Text(
          'Экспорт',
          style: TextStyle(
            color: Color(0xFFCCCCCC),
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(
        icon,
        size: 17,
      ),
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(
        minWidth: 30,
        minHeight: 30,
      ),
      splashRadius: 16,
      color: const Color(0xFFDDDDDD),
      disabledColor: const Color(0xFF707070),
    );
  }

  Widget _buildMenuButton(
    String label, {
    VoidCallback? onPressed,
    String? tooltip,
  }) {
    final button = TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 4,
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed ?? () {},
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFCCCCCC),
          fontSize: 13,
        ),
      ),
    );

    if (tooltip == null) {
      return button;
    }

    return Tooltip(message: tooltip, child: button);
  }
}

enum _FileMenuAction {
  newProject,
  openProject,
  importFountain,
  saveProject,
  saveAsProject,
  openRecentProject,
}

enum _ExportMenuAction {
  pdf,
  productionReport,
  storyboard,
  postProduction,
  fountain,
}

class _FileMenuSelection {
  const _FileMenuSelection(this.action) : recentPath = null;

  const _FileMenuSelection.recent(String path)
      : action = _FileMenuAction.openRecentProject,
        recentPath = path;

  final _FileMenuAction action;
  final String? recentPath;
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.shortcut,
  });

  final IconData icon;
  final String label;
  final String shortcut;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: const Color(0xFFD0D0D0),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFE0E0E0),
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 18),
        Text(
          shortcut,
          style: const TextStyle(
            color: Color(0xFF8D8D8D),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
