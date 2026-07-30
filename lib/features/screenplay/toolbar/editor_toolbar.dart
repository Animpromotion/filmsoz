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
          _buildFileMenu(context),
          _buildMenuButton('Правка'),
          _buildMenuButton('Вид'),
          _buildMenuButton('Формат'),
          _buildMenuButton('AI'),
          _buildMenuButton('Экспорт'),
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
          const SizedBox(width: 12),
          Expanded(
            child: Center(
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
            ),
          ),
          const SizedBox(width: 12),
          TextButton.icon(
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
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  )
                : const Icon(Icons.save_outlined, size: 16),
            label: Text(
              isSaving ? 'Сохранение...' : 'Сохранить',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
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
            value: _FileMenuSelection(_FileMenuAction.newProject),
            child: _MenuRow(
              icon: Icons.note_add_outlined,
              label: 'Новый сценарий',
              shortcut: 'Ctrl+N',
            ),
          ),
          const PopupMenuItem<_FileMenuSelection>(
            value: _FileMenuSelection(_FileMenuAction.openProject),
            child: _MenuRow(
              icon: Icons.folder_open_outlined,
              label: 'Открыть...',
              shortcut: 'Ctrl+O',
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem<_FileMenuSelection>(
            value: _FileMenuSelection(_FileMenuAction.saveProject),
            child: _MenuRow(
              icon: Icons.save_outlined,
              label: 'Сохранить',
              shortcut: 'Ctrl+S',
            ),
          ),
          const PopupMenuItem<_FileMenuSelection>(
            value: _FileMenuSelection(_FileMenuAction.saveAsProject),
            child: _MenuRow(
              icon: Icons.save_as_outlined,
              label: 'Сохранить как...',
              shortcut: 'Ctrl+Shift+S',
            ),
          ),
        ];

        if (recentProjects.isNotEmpty) {
          entries.add(const PopupMenuDivider());
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
                value: _FileMenuSelection.recent(recentPath),
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
                          path.basenameWithoutExtension(recentPath),
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

  Widget _buildHistoryButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 17),
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

  Widget _buildMenuButton(String label) {
    return TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 4,
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: () {},
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFCCCCCC),
          fontSize: 13,
        ),
      ),
    );
  }
}

enum _FileMenuAction {
  newProject,
  openProject,
  saveProject,
  saveAsProject,
  openRecentProject,
}

class _FileMenuSelection {
  const _FileMenuSelection(this.action, {this.recentPath});

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
