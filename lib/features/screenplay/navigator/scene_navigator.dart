import 'package:flutter/material.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';

class SceneNavigator extends StatelessWidget {
  const SceneNavigator({
    super.key,
    required this.scenes,
    required this.selectedSceneId,
    required this.onSceneSelected,
  });

  final List<FilmBlock> scenes;
  final String? selectedSceneId;
  final ValueChanged<FilmBlock> onSceneSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Material(
        color: const Color(0xFF252526),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _NavigatorHeader(sceneCount: scenes.length),
            const Divider(height: 1, thickness: 1, color: Color(0xFF343434)),
            Expanded(
              child: scenes.isEmpty
                  ? const _EmptySceneList()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: scenes.length,
                      itemBuilder: (context, index) {
                        final scene = scenes[index];

                        final isSelected = scene.id == selectedSceneId;

                        return _SceneItem(
                          number: index + 1,
                          scene: scene,
                          isSelected: isSelected,
                          onTap: () {
                            onSceneSelected(scene);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigatorHeader extends StatelessWidget {
  const _NavigatorHeader({required this.sceneCount});

  final int sceneCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'СЦЕНЫ',
                style: TextStyle(
                  color: Color(0xFF9A9A9A),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.15,
                ),
              ),
            ),
            Container(
              constraints: const BoxConstraints(minWidth: 24),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF343436),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$sceneCount',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFBEBEBE),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SceneItem extends StatelessWidget {
  const _SceneItem({
    required this.number,
    required this.scene,
    required this.isSelected,
    required this.onTap,
  });

  final int number;
  final FilmBlock scene;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final trimmedTitle = scene.text.trim();

    final title = trimmedTitle.isEmpty ? 'БЕЗ НАЗВАНИЯ' : trimmedTitle;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Material(
        color: isSelected ? const Color(0xFF37373D) : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: const Color(0xFF323234),
          splashColor: const Color(0xFF44444A),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color:
                      isSelected ? const Color(0xFF4DA3FF) : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    '$number',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFF7DBBFF)
                          : const Color(0xFF737373),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Courier New',
                      fontSize: 12,
                      height: 1.3,
                      color:
                          isSelected ? Colors.white : const Color(0xFFCCCCCC),
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptySceneList extends StatelessWidget {
  const _EmptySceneList();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'В сценарии пока нет заголовков сцен.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF777777), fontSize: 12, height: 1.4),
        ),
      ),
    );
  }
}
