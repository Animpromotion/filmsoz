import 'package:flutter/material.dart';

class EditorToolbar extends StatelessWidget {
  const EditorToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
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
