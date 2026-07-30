import 'package:flutter/material.dart';
import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';

class ScreenplayProductivityToolbar extends StatelessWidget {
  const ScreenplayProductivityToolbar({
    super.key,
    required this.onInsertBlock,
    required this.onDuplicateBlocks,
    required this.onFindReplace,
    required this.onGoToScene,
    required this.onShowCharacters,
    required this.onEditSceneNote,
    required this.hasActiveScene,
    required this.hasFocusedBlock,
  });

  final ValueChanged<BlockType> onInsertBlock;
  final VoidCallback onDuplicateBlocks;
  final VoidCallback onFindReplace;
  final VoidCallback onGoToScene;
  final VoidCallback onShowCharacters;
  final VoidCallback onEditSceneNote;
  final bool hasActiveScene;
  final bool hasFocusedBlock;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      color: const Color(0xFF2A2A2D),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Text(
              'БЫСТРО:',
              style: TextStyle(
                color: Color(0xFF8D8D99),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(width: 8),
            _InsertButton(
              icon: Icons.movie_filter_outlined,
              label: 'Сцена',
              onPressed: () => onInsertBlock(BlockType.sceneHeading),
            ),
            _InsertButton(
              icon: Icons.subject,
              label: 'Действие',
              onPressed: () => onInsertBlock(BlockType.action),
            ),
            _InsertButton(
              icon: Icons.person_outline,
              label: 'Персонаж',
              onPressed: () => onInsertBlock(BlockType.character),
            ),
            _InsertButton(
              icon: Icons.chat_bubble_outline,
              label: 'Диалог',
              onPressed: () => onInsertBlock(BlockType.dialogue),
            ),
            _InsertButton(
              icon: Icons.format_quote,
              label: 'Ремарка',
              onPressed: () => onInsertBlock(BlockType.parenthetical),
            ),
            _InsertButton(
              icon: Icons.east,
              label: 'Переход',
              onPressed: () => onInsertBlock(BlockType.transition),
            ),
            const VerticalDivider(
              width: 18,
              indent: 8,
              endIndent: 8,
              color: Color(0xFF444448),
            ),
            _ActionButton(
              tooltip: 'Дублировать блоки (Ctrl+D)',
              icon: Icons.copy_all_outlined,
              onPressed: hasFocusedBlock ? onDuplicateBlocks : null,
            ),
            _ActionButton(
              tooltip: 'Поиск и замена (Ctrl+F)',
              icon: Icons.find_replace,
              onPressed: onFindReplace,
            ),
            _ActionButton(
              tooltip: 'Перейти к сцене (Ctrl+G)',
              icon: Icons.pin_drop_outlined,
              onPressed: onGoToScene,
            ),
            _ActionButton(
              tooltip: 'Персонажи и статистика',
              icon: Icons.groups_2_outlined,
              onPressed: onShowCharacters,
            ),
            _ActionButton(
              tooltip: 'Заметка к активной сцене',
              icon: Icons.sticky_note_2_outlined,
              onPressed: hasActiveScene ? onEditSceneNote : null,
            ),
            const SizedBox(width: 12),
            const Text(
              'Ctrl+Space — принять подсказку',
              style: TextStyle(
                color: Color(0xFF77777D),
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsertButton extends StatelessWidget {
  const _InsertButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 3),
      child: TextButton.icon(
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          foregroundColor: const Color(0xFFD7D7DA),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 15),
        label: Text(label, style: const TextStyle(fontSize: 11)),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
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
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
    );
  }
}
