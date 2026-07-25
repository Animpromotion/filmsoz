import 'package:flutter/material.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';

class SceneNavigator extends StatelessWidget {
  const SceneNavigator({
    super.key,
    required this.scenes,
    this.onSceneSelected,
  });

  final List<FilmBlock> scenes;
  final ValueChanged<FilmBlock>? onSceneSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Material(
        color: const Color(0xFF252526),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'СЦЕНЫ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF808080),
                  letterSpacing: 1.1,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: scenes.length,
                itemBuilder: (context, index) {
                  final scene = scenes[index];

                  return Material(
                    color: Colors.transparent,
                    child: ListTile(
                      dense: true,
                      hoverColor: const Color(0xFF323234),
                      splashColor: const Color(0xFF3A3A3C),
                      title: Text(
                        scene.text.isEmpty ? 'БЕЗ НАЗВАНИЯ' : scene.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Courier New',
                          fontSize: 12,
                          color: Color(0xFFCCCCCC),
                        ),
                      ),
                      onTap: () => onSceneSelected?.call(scene),
                    ),
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
