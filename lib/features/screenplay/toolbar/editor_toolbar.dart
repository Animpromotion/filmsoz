import 'package:flutter/material.dart';

class EditorToolbar extends StatelessWidget {
  const EditorToolbar({
    super.key,
    required this.onSave,
    required this.onUndo,
    required this.onRedo,
    required this.isSaving,
    required this.canUndo,
    required this.canRedo,
  });

  final VoidCallback onSave;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final bool isSaving;
  final bool canUndo;
  final bool canRedo;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      color: const Color(0xFF3C3C3C),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          _buildMenuButton('Файл'),
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
          const Spacer(),
          TextButton.icon(
            onPressed: isSaving ? null : onSave,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
