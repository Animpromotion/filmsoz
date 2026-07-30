import 'package:flutter/material.dart';

class EditorToolbar extends StatelessWidget {
  const EditorToolbar({
    super.key,
    required this.onSave,
    required this.isSaving,
  });

  final VoidCallback onSave;
  final bool isSaving;

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
