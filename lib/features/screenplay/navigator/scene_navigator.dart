import 'package:flutter/material.dart';
import 'package:filmsoz_studio/features/screenplay/document/scene_section.dart';

class SceneNavigator extends StatefulWidget {
  const SceneNavigator({
    super.key,
    required this.scenes,
    required this.selectedSceneId,
    required this.collapsedSceneIds,
    required this.onSceneSelected,
    required this.onToggleSceneCollapsed,
    required this.onMoveScene,
    required this.onDuplicateScene,
    required this.onDeleteScene,
    required this.onSceneDropped,
  });

  final List<SceneSection> scenes;
  final String? selectedSceneId;
  final Set<String> collapsedSceneIds;
  final ValueChanged<SceneSection> onSceneSelected;
  final ValueChanged<String> onToggleSceneCollapsed;
  final void Function(String sceneId, int offset) onMoveScene;
  final ValueChanged<String> onDuplicateScene;
  final ValueChanged<String> onDeleteScene;
  final void Function(
    String sceneId,
    String targetSceneId,
    bool placeAfter,
  ) onSceneDropped;

  @override
  State<SceneNavigator> createState() => _SceneNavigatorState();
}

class _SceneNavigatorState extends State<SceneNavigator> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _dragHoverSceneId;
  bool _dragInsertAfter = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredScenes = widget.scenes
        .where((scene) => scene.matchesQuery(_query))
        .toList(growable: false);

    return SizedBox(
      width: 310,
      child: Material(
        color: const Color(0xFF252526),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _NavigatorHeader(
              sceneCount: widget.scenes.length,
              filteredCount: filteredScenes.length,
              searchController: _searchController,
              onQueryChanged: (value) {
                setState(() {
                  _query = value;
                });
              },
              onClearSearch: () {
                _searchController.clear();
                setState(() {
                  _query = '';
                });
              },
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFF343434)),
            Expanded(
              child: filteredScenes.isEmpty
                  ? _EmptySceneList(hasQuery: _query.trim().isNotEmpty)
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: filteredScenes.length,
                      itemBuilder: (context, index) {
                        final scene = filteredScenes[index];
                        final originalIndex = widget.scenes.indexWhere(
                          (candidate) => candidate.id == scene.id,
                        );
                        final isSelected = scene.id == widget.selectedSceneId;
                        final isCollapsed =
                            widget.collapsedSceneIds.contains(scene.id);
                        final isDropTarget = _dragHoverSceneId == scene.id;

                        return _SceneDropTarget(
                          scene: scene,
                          isDropTarget: isDropTarget,
                          insertAfter: _dragInsertAfter,
                          onHover: (insertAfter) {
                            if (_dragHoverSceneId != scene.id ||
                                _dragInsertAfter != insertAfter) {
                              setState(() {
                                _dragHoverSceneId = scene.id;
                                _dragInsertAfter = insertAfter;
                              });
                            }
                          },
                          onLeave: () {
                            if (_dragHoverSceneId == scene.id) {
                              setState(() {
                                _dragHoverSceneId = null;
                                _dragInsertAfter = false;
                              });
                            }
                          },
                          onAccept: (draggedSceneId) {
                            final placeAfter = _dragInsertAfter;

                            setState(() {
                              _dragHoverSceneId = null;
                              _dragInsertAfter = false;
                            });

                            widget.onSceneDropped(
                              draggedSceneId,
                              scene.id,
                              placeAfter,
                            );
                          },
                          child: _SceneItem(
                            scene: scene,
                            isSelected: isSelected,
                            isCollapsed: isCollapsed,
                            canMoveUp: originalIndex > 0,
                            canMoveDown: originalIndex >= 0 &&
                                originalIndex < widget.scenes.length - 1,
                            onTap: () => widget.onSceneSelected(scene),
                            onToggleCollapsed: () {
                              widget.onToggleSceneCollapsed(scene.id);
                            },
                            onMoveUp: () => widget.onMoveScene(scene.id, -1),
                            onMoveDown: () => widget.onMoveScene(scene.id, 1),
                            onDuplicate: () {
                              widget.onDuplicateScene(scene.id);
                            },
                            onDelete: () {
                              widget.onDeleteScene(scene.id);
                            },
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

class _NavigatorHeader extends StatelessWidget {
  const _NavigatorHeader({
    required this.sceneCount,
    required this.filteredCount,
    required this.searchController,
    required this.onQueryChanged,
    required this.onClearSearch,
  });

  final int sceneCount;
  final int filteredCount;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
                constraints: const BoxConstraints(minWidth: 28),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF343436),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  filteredCount == sceneCount
                      ? '$sceneCount'
                      : '$filteredCount/$sceneCount',
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
          const SizedBox(height: 9),
          SizedBox(
            height: 34,
            child: TextField(
              controller: searchController,
              onChanged: onQueryChanged,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Номер, локация или текст...',
                hintStyle: const TextStyle(
                  color: Color(0xFF77777D),
                  fontSize: 11,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 17,
                  color: Color(0xFF8D8D99),
                ),
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Очистить поиск',
                        onPressed: onClearSearch,
                        icon: const Icon(Icons.close, size: 16),
                      ),
                isDense: true,
                filled: true,
                fillColor: const Color(0xFF1E1E20),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF3B3B3E)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF3B3B3E)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFFE5A93C)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SceneDropTarget extends StatefulWidget {
  const _SceneDropTarget({
    required this.scene,
    required this.isDropTarget,
    required this.insertAfter,
    required this.onHover,
    required this.onLeave,
    required this.onAccept,
    required this.child,
  });

  final SceneSection scene;
  final bool isDropTarget;
  final bool insertAfter;
  final ValueChanged<bool> onHover;
  final VoidCallback onLeave;
  final ValueChanged<String> onAccept;
  final Widget child;

  @override
  State<_SceneDropTarget> createState() => _SceneDropTargetState();
}

class _SceneDropTargetState extends State<_SceneDropTarget> {
  final GlobalKey _targetKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != widget.scene.id,
      onMove: (details) {
        final targetContext = _targetKey.currentContext;
        final renderObject = targetContext?.findRenderObject();

        if (renderObject is RenderBox) {
          final localPosition = renderObject.globalToLocal(details.offset);
          widget.onHover(
            localPosition.dy > renderObject.size.height / 2,
          );
        }
      },
      onLeave: (_) => widget.onLeave(),
      onAcceptWithDetails: (details) => widget.onAccept(details.data),
      builder: (context, candidateData, rejectedData) {
        final showLine = widget.isDropTarget && candidateData.isNotEmpty;

        return AnimatedContainer(
          key: _targetKey,
          duration: const Duration(milliseconds: 90),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: showLine && !widget.insertAfter
                    ? const Color(0xFFE5A93C)
                    : Colors.transparent,
                width: 3,
              ),
              bottom: BorderSide(
                color: showLine && widget.insertAfter
                    ? const Color(0xFFE5A93C)
                    : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}

class _SceneItem extends StatelessWidget {
  const _SceneItem({
    required this.scene,
    required this.isSelected,
    required this.isCollapsed,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onTap,
    required this.onToggleCollapsed,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDuplicate,
    required this.onDelete,
  });

  final SceneSection scene;
  final bool isSelected;
  final bool isCollapsed;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onTap;
  final VoidCallback onToggleCollapsed;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Material(
        color: isSelected ? const Color(0xFF37373D) : Colors.transparent,
        borderRadius: BorderRadius.circular(5),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: const Color(0xFF323234),
          splashColor: const Color(0xFF44444A),
          child: Container(
            constraints: const BoxConstraints(minHeight: 66),
            padding: const EdgeInsets.fromLTRB(7, 7, 4, 7),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color:
                      isSelected ? const Color(0xFFE5A93C) : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Draggable<String>(
                  data: scene.id,
                  axis: Axis.vertical,
                  dragAnchorStrategy: pointerDragAnchorStrategy,
                  feedback: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: 230,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2B2B2E),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: const Color(0xFFE5A93C)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x55000000),
                            blurRadius: 12,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Text(
                        'СЦЕНА ${scene.number}: ${scene.title}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  childWhenDragging: const Opacity(
                    opacity: 0.3,
                    child: Icon(Icons.drag_indicator, size: 18),
                  ),
                  child: const MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.drag_indicator,
                        size: 18,
                        color: Color(0xFF77777D),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 34,
                  child: Text(
                    '${scene.number}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFFF2C76E)
                          : const Color(0xFF737373),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scene.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Courier New',
                          fontSize: 12,
                          height: 1.25,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFFCCCCCC),
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${scene.blockCount} блоков • '
                        '${scene.wordCount} слов • '
                        '${scene.characterCount} симв.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF85858B),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: isCollapsed ? 'Развернуть сцену' : 'Свернуть сцену',
                  constraints: const BoxConstraints.tightFor(
                    width: 30,
                    height: 30,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: onToggleCollapsed,
                  icon: Icon(
                    isCollapsed
                        ? Icons.unfold_more_rounded
                        : Icons.unfold_less_rounded,
                    size: 17,
                    color: const Color(0xFFB8B8BD),
                  ),
                ),
                PopupMenuButton<_SceneMenuAction>(
                  tooltip: 'Действия со сценой',
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  onSelected: (action) {
                    switch (action) {
                      case _SceneMenuAction.moveUp:
                        onMoveUp();
                        break;
                      case _SceneMenuAction.moveDown:
                        onMoveDown();
                        break;
                      case _SceneMenuAction.duplicate:
                        onDuplicate();
                        break;
                      case _SceneMenuAction.delete:
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: _SceneMenuAction.moveUp,
                      enabled: canMoveUp,
                      child: const _SceneMenuLabel(
                        icon: Icons.arrow_upward,
                        text: 'Переместить выше',
                      ),
                    ),
                    PopupMenuItem(
                      value: _SceneMenuAction.moveDown,
                      enabled: canMoveDown,
                      child: const _SceneMenuLabel(
                        icon: Icons.arrow_downward,
                        text: 'Переместить ниже',
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: _SceneMenuAction.duplicate,
                      child: _SceneMenuLabel(
                        icon: Icons.copy_all_outlined,
                        text: 'Дублировать сцену',
                      ),
                    ),
                    const PopupMenuItem(
                      value: _SceneMenuAction.delete,
                      child: _SceneMenuLabel(
                        icon: Icons.delete_outline,
                        text: 'Удалить сцену',
                        destructive: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SceneMenuLabel extends StatelessWidget {
  const _SceneMenuLabel({
    required this.icon,
    required this.text,
    this.destructive = false,
  });

  final IconData icon;
  final String text;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? const Color(0xFFFF8A8A) : null;

    return Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 10),
        Text(text, style: TextStyle(color: color)),
      ],
    );
  }
}

class _EmptySceneList extends StatelessWidget {
  const _EmptySceneList({required this.hasQuery});

  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          hasQuery
              ? 'Сцены по этому запросу не найдены.'
              : 'В сценарии пока нет заголовков сцен.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF777777),
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

enum _SceneMenuAction { moveUp, moveDown, duplicate, delete }
