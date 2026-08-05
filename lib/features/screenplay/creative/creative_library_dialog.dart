import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:filmsoz_studio/features/screenplay/creative/creative_library_service.dart';
import 'package:filmsoz_studio/features/screenplay/creative/creative_material.dart';
import 'package:filmsoz_studio/features/screenplay/document/scene_section.dart';
import 'package:filmsoz_studio/features/screenplay/editor/controller/screenplay_editor_controller.dart';

class CreativeMaterialInsertRequest {
  const CreativeMaterialInsertRequest({
    required this.materialId,
    required this.text,
  });

  final String materialId;
  final String text;
}

enum _CreativeLibraryView { cards, list }

class CreativeLibraryDialog extends StatefulWidget {
  const CreativeLibraryDialog({
    super.key,
    required this.controller,
    this.initialSceneId,
  });

  final ScreenplayEditorController controller;
  final String? initialSceneId;

  @override
  State<CreativeLibraryDialog> createState() => _CreativeLibraryDialogState();
}

class _CreativeLibraryDialogState extends State<CreativeLibraryDialog> {
  final CreativeLibraryService _service = const CreativeLibraryService();
  final TextEditingController _searchController = TextEditingController();

  String _query = '';
  String? _selectedMaterialId;
  CreativeMaterialType? _typeFilter;
  String? _folderFilter;
  String? _tagFilter;
  String? _sceneFilter;
  String? _characterFilter;
  bool _onlyUnused = false;
  _CreativeLibraryView _view = _CreativeLibraryView.cards;

  @override
  void initState() {
    super.initState();
    _sceneFilter = widget.initialSceneId;
    _selectedMaterialId =
        widget.controller.document.creativeMaterials.firstOrNull?.id;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final document = widget.controller.document;
    final materials = _service.filter(
      document.creativeMaterials,
      CreativeLibraryFilter(
        query: _query,
        type: _typeFilter,
        folder: _folderFilter,
        tag: _tagFilter,
        sceneId: _sceneFilter,
        characterName: _characterFilter,
        onlyUnused: _onlyUnused,
      ),
    );
    CreativeMaterial? selected;

    if (_selectedMaterialId != null) {
      selected = materials
          .where((material) => material.id == _selectedMaterialId)
          .firstOrNull;
    }

    selected ??= materials.firstOrNull;
    _selectedMaterialId = selected?.id;

    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.all(22),
      child: SizedBox(
        width: 1280,
        height: 790,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 240,
                    child: _buildFilters(
                      folders: _service.folders(document.creativeMaterials),
                      tags: _service.tags(document.creativeMaterials),
                      scenes: document.sceneSections,
                      characters: _service.characterNames(document),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        _buildSearchAndView(materials.length),
                        const Divider(height: 1),
                        Expanded(
                          child: _buildMaterials(materials),
                        ),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  SizedBox(
                    width: 390,
                    child: _buildDetails(selected),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: const Color(0xFF25252A),
      child: Row(
        children: [
          const Icon(Icons.collections_bookmark_outlined),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Творческая база',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Идеи, цитаты, ссылки, исследования и референсы проекта',
                  style: TextStyle(fontSize: 11, color: Color(0xFFAAAAAA)),
                ),
              ],
            ),
          ),
          PopupMenuButton<CreativeMaterialType>(
            tooltip: 'Создать материал',
            onSelected: (type) => _editMaterial(type: type),
            itemBuilder: (context) {
              return CreativeMaterialType.values.map((type) {
                return PopupMenuItem<CreativeMaterialType>(
                  value: type,
                  child: Row(
                    children: [
                      Icon(_typeIcon(type), size: 18),
                      const SizedBox(width: 10),
                      Text(type.label),
                    ],
                  ),
                );
              }).toList(growable: false);
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.add, size: 18),
                  SizedBox(width: 6),
                  Text('Новый материал'),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Закрыть',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndView(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Поиск по названию, тексту, источнику и тегам...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Очистить поиск',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close, size: 18),
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text('$count'),
          const SizedBox(width: 10),
          SegmentedButton<_CreativeLibraryView>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: _CreativeLibraryView.cards,
                icon: Icon(Icons.grid_view, size: 18),
              ),
              ButtonSegment(
                value: _CreativeLibraryView.list,
                icon: Icon(Icons.view_list, size: 18),
              ),
            ],
            selected: <_CreativeLibraryView>{_view},
            onSelectionChanged: (selection) {
              setState(() => _view = selection.first);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilters({
    required List<String> folders,
    required List<String> tags,
    required List<SceneSection> scenes,
    required List<String> characters,
  }) {
    return Material(
      color: const Color(0xFF1F1F23),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Text(
            'ТИП МАТЕРИАЛА',
            style: TextStyle(fontSize: 11, color: Color(0xFF999999)),
          ),
          const SizedBox(height: 6),
          _filterTile(
            label: 'Все материалы',
            icon: Icons.all_inbox_outlined,
            selected: _typeFilter == null,
            onTap: () => setState(() => _typeFilter = null),
          ),
          for (final type in CreativeMaterialType.values)
            _filterTile(
              label: type.label,
              icon: _typeIcon(type),
              selected: _typeFilter == type,
              onTap: () => setState(() => _typeFilter = type),
            ),
          const Divider(height: 24),
          _dropdownFilter(
            label: 'Папка',
            value: _folderFilter,
            values: folders,
            onChanged: (value) => setState(() => _folderFilter = value),
          ),
          const SizedBox(height: 10),
          _dropdownFilter(
            label: 'Тег',
            value: _tagFilter,
            values: tags,
            onChanged: (value) => setState(() => _tagFilter = value),
          ),
          const SizedBox(height: 10),
          _dropdownFilter(
            label: 'Сцена',
            value: _sceneFilter,
            values: scenes.map((scene) => scene.id).toList(growable: false),
            labels: <String, String>{
              for (final scene in scenes)
                scene.id: '${scene.number}. ${scene.title}',
            },
            onChanged: (value) => setState(() => _sceneFilter = value),
          ),
          const SizedBox(height: 10),
          _dropdownFilter(
            label: 'Персонаж',
            value: _characterFilter,
            values: characters,
            onChanged: (value) => setState(() => _characterFilter = value),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Только неиспользованные',
                style: TextStyle(fontSize: 12)),
            value: _onlyUnused,
            onChanged: (value) => setState(() => _onlyUnused = value),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _clearFilters,
            icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
            label: const Text('Сбросить фильтры'),
          ),
        ],
      ),
    );
  }

  Widget _filterTile({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      selected: selected,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Icon(icon, size: 18),
      title: Text(label, style: const TextStyle(fontSize: 12)),
      onTap: onTap,
    );
  }

  Widget _dropdownFilter({
    required String label,
    required String? value,
    required List<String> values,
    required ValueChanged<String?> onChanged,
    Map<String, String> labels = const <String, String>{},
  }) {
    final availableValues = <String>{
      ...values,
      if (value != null && value.isNotEmpty) value,
    }.toList(growable: false);

    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value ?? '',
          isExpanded: true,
          isDense: true,
          items: <DropdownMenuItem<String>>[
            const DropdownMenuItem<String>(
              value: '',
              child: Text('Все'),
            ),
            ...availableValues.map(
              (item) => DropdownMenuItem<String>(
                value: item,
                child: Text(
                  labels[item] ?? item,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          onChanged: (nextValue) {
            onChanged(
              nextValue == null || nextValue.isEmpty ? null : nextValue,
            );
          },
        ),
      ),
    );
  }

  Widget _buildMaterials(List<CreativeMaterial> materials) {
    if (materials.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lightbulb_outline,
                size: 54, color: Color(0xFF777777)),
            const SizedBox(height: 12),
            const Text('Материалы не найдены'),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _editMaterial(type: CreativeMaterialType.idea),
              icon: const Icon(Icons.add),
              label: const Text('Создать первую идею'),
            ),
          ],
        ),
      );
    }

    if (_view == _CreativeLibraryView.list) {
      return ListView.separated(
        padding: const EdgeInsets.all(10),
        itemCount: materials.length,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          final material = materials[index];
          return Material(
            color: _selectedMaterialId == material.id
                ? const Color(0xFF34343B)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: ListTile(
              selected: _selectedMaterialId == material.id,
              leading: CircleAvatar(
                backgroundColor: Color(material.colorValue),
                foregroundColor: Colors.black,
                child: Icon(_typeIcon(material.type), size: 18),
              ),
              title: Text(
                material.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                _materialSubtitle(material),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: material.usedBlockIds.isEmpty
                  ? const Tooltip(
                      message: 'Ещё не использовано в сценарии',
                      child: Icon(Icons.circle_outlined, size: 15),
                    )
                  : Tooltip(
                      message: 'Использовано в сценарии',
                      child: Text('${material.usedBlockIds.length}×'),
                    ),
              onTap: () => setState(() => _selectedMaterialId = material.id),
            ),
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 760 ? 3 : 2;
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisExtent: 190,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: materials.length,
          itemBuilder: (context, index) {
            return _materialCard(materials[index]);
          },
        );
      },
    );
  }

  Widget _materialCard(CreativeMaterial material) {
    final selected = _selectedMaterialId == material.id;
    return Material(
      color: selected ? const Color(0xFF34343B) : const Color(0xFF29292E),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _selectedMaterialId = material.id),
        onDoubleTap: () => _editMaterial(material: material),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  selected ? const Color(0xFFE5A93C) : const Color(0xFF404047),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Color(material.colorValue),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(_typeIcon(material.type),
                        size: 17, color: Colors.black),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      material.type.label,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFFAAAAAA)),
                    ),
                  ),
                  if (material.usedBlockIds.isNotEmpty)
                    const Icon(Icons.check_circle,
                        size: 16, color: Color(0xFF76B97E)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                material.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 7),
              Expanded(
                child: Text(
                  material.body.trim().isEmpty
                      ? _materialSubtitle(material)
                      : material.body.trim(),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, height: 1.35, color: Color(0xFFC6C6C6)),
                ),
              ),
              if (material.tags.isNotEmpty)
                Text(
                  material.tags.take(3).map((tag) => '#$tag').join('  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 10, color: Color(0xFFE5A93C)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetails(CreativeMaterial? material) {
    if (material == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Text(
            'Выберите материал, чтобы увидеть его содержание.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final sceneTitles = material.linkedSceneIds
        .map((sceneId) {
          final scene = widget.controller.document.sceneById(sceneId);
          return scene == null ? null : '${scene.number}. ${scene.title}';
        })
        .whereType<String>()
        .toList(growable: false);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Color(material.colorValue),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(_typeIcon(material.type), color: Colors.black),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          material.title,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${material.type.label} • ${material.folder}',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFFAAAAAA)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (material.hasImage) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _safeImage(material),
                ),
              ],
              if (material.body.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                SelectableText(
                  material.body,
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
              ],
              if (material.source.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                _detailSection('Источник', material.source),
              ],
              if (material.url.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                _detailSection(
                  'Ссылка',
                  material.url,
                  trailing: IconButton(
                    tooltip: 'Копировать ссылку',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: material.url));
                      _showMessage('Ссылка скопирована');
                    },
                    icon: const Icon(Icons.copy, size: 17),
                  ),
                ),
              ],
              if (material.tags.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Теги',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: material.tags
                      .map((tag) => Chip(label: Text('#$tag')))
                      .toList(growable: false),
                ),
              ],
              if (sceneTitles.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Связанные сцены',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                for (final title in sceneTitles)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $title'),
                  ),
              ],
              if (material.linkedCharacterNames.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Персонажи',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(material.linkedCharacterNames.join(', ')),
              ],
              const SizedBox(height: 16),
              Text(
                material.usedBlockIds.isEmpty
                    ? 'Пока не использовано в сценарии'
                    : 'Использовано в ${material.usedBlockIds.length} блоках',
                style: TextStyle(
                  fontSize: 11,
                  color: material.usedBlockIds.isEmpty
                      ? const Color(0xFF999999)
                      : const Color(0xFF76B97E),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _insertMaterial(material),
                  icon: const Icon(Icons.subdirectory_arrow_right),
                  label: const Text('Вставить в сценарий'),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _editMaterial(material: material),
                      icon: const Icon(Icons.edit_outlined, size: 17),
                      label: const Text('Изменить'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: 'Дублировать',
                    onPressed: () => _duplicate(material),
                    icon: const Icon(Icons.copy_all_outlined, size: 18),
                  ),
                  const SizedBox(width: 6),
                  IconButton.outlined(
                    tooltip: 'Удалить',
                    onPressed: () => _delete(material),
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: Color(0xFFCC6666)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _safeImage(CreativeMaterial material) {
    try {
      final bytes = base64Decode(material.imageBase64!);
      return Image.memory(
        Uint8List.fromList(bytes),
        height: 210,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _brokenImage(),
      );
    } catch (_) {
      return _brokenImage();
    }
  }

  Widget _brokenImage() {
    return const SizedBox(
      height: 130,
      child: Center(child: Icon(Icons.broken_image_outlined, size: 42)),
    );
  }

  Widget _detailSection(String label, String value, {Widget? trailing}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
                child: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w700))),
            if (trailing != null) trailing,
          ],
        ),
        const SizedBox(height: 4),
        SelectableText(value,
            style: const TextStyle(fontSize: 12, height: 1.4)),
      ],
    );
  }

  Future<void> _editMaterial({
    CreativeMaterial? material,
    CreativeMaterialType type = CreativeMaterialType.idea,
  }) async {
    final result = await showDialog<CreativeMaterial>(
      context: context,
      builder: (context) {
        return _CreativeMaterialEditorDialog(
          material: material,
          initialType: material?.type ?? type,
          existingFolders: _service.folders(
            widget.controller.document.creativeMaterials,
          ),
          scenes: widget.controller.document.sceneSections,
          characters: _service.characterNames(widget.controller.document),
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    final saved = widget.controller.upsertCreativeMaterial(result);
    setState(() => _selectedMaterialId = saved.id);
  }

  void _duplicate(CreativeMaterial material) {
    final duplicate = widget.controller.duplicateCreativeMaterial(material.id);

    if (duplicate == null) {
      return;
    }

    setState(() => _selectedMaterialId = duplicate.id);
    _showMessage('Материал дублирован');
  }

  Future<void> _delete(CreativeMaterial material) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Удалить материал?'),
          content: Text('«${material.title}» будет удалён из творческой базы.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    widget.controller.deleteCreativeMaterial(material.id);
    setState(() {
      _selectedMaterialId =
          widget.controller.document.creativeMaterials.firstOrNull?.id;
    });
  }

  void _insertMaterial(CreativeMaterial material) {
    final text = _service.insertionText(material);

    if (text.trim().isEmpty) {
      _showMessage('У материала нет текста для вставки');
      return;
    }

    Navigator.of(context).pop(
      CreativeMaterialInsertRequest(
        materialId: material.id,
        text: text,
      ),
    );
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _typeFilter = null;
      _folderFilter = null;
      _tagFilter = null;
      _sceneFilter = null;
      _characterFilter = null;
      _onlyUnused = false;
    });
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  String _materialSubtitle(CreativeMaterial material) {
    return <String>[
      material.folder,
      if (material.source.trim().isNotEmpty) material.source.trim(),
      if (material.url.trim().isNotEmpty) material.url.trim(),
    ].join(' • ');
  }
}

class _CreativeMaterialEditorDialog extends StatefulWidget {
  const _CreativeMaterialEditorDialog({
    required this.material,
    required this.initialType,
    required this.existingFolders,
    required this.scenes,
    required this.characters,
  });

  final CreativeMaterial? material;
  final CreativeMaterialType initialType;
  final List<String> existingFolders;
  final List<SceneSection> scenes;
  final List<String> characters;

  @override
  State<_CreativeMaterialEditorDialog> createState() =>
      _CreativeMaterialEditorDialogState();
}

class _CreativeMaterialEditorDialogState
    extends State<_CreativeMaterialEditorDialog> {
  static const int _maximumImageBytes = 8 * 1024 * 1024;
  static const List<int> _colors = <int>[
    0xFFE5A93C,
    0xFF5A9BD5,
    0xFF76B97E,
    0xFFC67BCF,
    0xFFE07A5F,
    0xFF8F9AA6,
  ];

  late CreativeMaterialType _type;
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final TextEditingController _sourceController;
  late final TextEditingController _urlController;
  late final TextEditingController _folderController;
  late final TextEditingController _tagsController;
  late Set<String> _sceneIds;
  late Set<String> _characters;
  late int _colorValue;
  String? _imageName;
  String? _imageBase64;
  String? _imageError;

  @override
  void initState() {
    super.initState();
    final material = widget.material;
    _type = material?.type ?? widget.initialType;
    _titleController = TextEditingController(text: material?.title ?? '');
    _bodyController = TextEditingController(text: material?.body ?? '');
    _sourceController = TextEditingController(text: material?.source ?? '');
    _urlController = TextEditingController(text: material?.url ?? '');
    _folderController =
        TextEditingController(text: material?.folder ?? 'Без папки');
    _tagsController =
        TextEditingController(text: material?.tags.join(', ') ?? '');
    _sceneIds = material?.linkedSceneIds.toSet() ?? <String>{};
    _characters = material?.linkedCharacterNames.toSet() ?? <String>{};
    _colorValue = material?.colorValue ?? _colors.first;
    _imageName = material?.imageName;
    _imageBase64 = material?.imageBase64;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _sourceController.dispose();
    _urlController.dispose();
    _folderController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          widget.material == null ? 'Новый материал' : 'Изменить материал'),
      content: SizedBox(
        width: 780,
        height: 650,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: ListView(
                children: [
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Тип материала',
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<CreativeMaterialType>(
                        value: _type,
                        isExpanded: true,
                        isDense: true,
                        items: CreativeMaterialType.values
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(type.label),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _type = value);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _titleController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Название',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bodyController,
                    minLines: 7,
                    maxLines: 14,
                    decoration: InputDecoration(
                      labelText: _type == CreativeMaterialType.quote
                          ? 'Текст цитаты'
                          : 'Содержание / заметка',
                      alignLabelWithHint: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _sourceController,
                    decoration: const InputDecoration(
                      labelText: 'Источник / автор',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'Ссылка',
                      hintText: 'https://...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _folderController,
                    decoration: const InputDecoration(
                      labelText: 'Папка',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (widget.existingFolders.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: widget.existingFolders.take(6).map((folder) {
                        return ActionChip(
                          label: Text(folder),
                          onPressed: () {
                            _folderController.text = folder;
                          },
                        );
                      }).toList(growable: false),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _tagsController,
                    decoration: const InputDecoration(
                      labelText: 'Теги через запятую',
                      hintText: 'конфликт, финал, детство',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              flex: 2,
              child: ListView(
                children: [
                  const Text('Цветовая метка',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _colors.map((value) {
                      final selected = _colorValue == value;
                      return InkWell(
                        onTap: () => setState(() => _colorValue = value),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Color(value),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  selected ? Colors.white : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                      );
                    }).toList(growable: false),
                  ),
                  const Divider(height: 28),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Изображение',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      TextButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.image_outlined, size: 18),
                        label: const Text('Выбрать'),
                      ),
                    ],
                  ),
                  if (_imageBase64 != null) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        base64Decode(_imageBase64!),
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _imageName ?? 'Изображение',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Удалить изображение',
                          onPressed: () {
                            setState(() {
                              _imageName = null;
                              _imageBase64 = null;
                              _imageError = null;
                            });
                          },
                          icon: const Icon(Icons.delete_outline, size: 18),
                        ),
                      ],
                    ),
                  ],
                  if (_imageError != null)
                    Text(
                      _imageError!,
                      style: const TextStyle(
                          color: Color(0xFFCC6666), fontSize: 11),
                    ),
                  const Divider(height: 28),
                  const Text('Связать со сценами',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (widget.scenes.isEmpty)
                    const Text('В сценарии пока нет сцен.',
                        style: TextStyle(fontSize: 11))
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: widget.scenes.map((scene) {
                        return FilterChip(
                          label: Text('${scene.number}'),
                          tooltip: scene.title,
                          selected: _sceneIds.contains(scene.id),
                          onSelected: (selected) {
                            setState(() {
                              selected
                                  ? _sceneIds.add(scene.id)
                                  : _sceneIds.remove(scene.id);
                            });
                          },
                        );
                      }).toList(growable: false),
                    ),
                  const Divider(height: 28),
                  const Text('Связать с персонажами',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (widget.characters.isEmpty)
                    const Text('Персонажи ещё не найдены.',
                        style: TextStyle(fontSize: 11))
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: widget.characters.map((name) {
                        return FilterChip(
                          label: Text(name),
                          selected: _characters.contains(name),
                          onSelected: (selected) {
                            setState(() {
                              selected
                                  ? _characters.add(name)
                                  : _characters.remove(name);
                            });
                          },
                        );
                      }).toList(growable: false),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Сохранить'),
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    const group = XTypeGroup(
      label: 'Изображения',
      extensions: <String>['png', 'jpg', 'jpeg', 'webp'],
    );
    final file = await openFile(acceptedTypeGroups: const <XTypeGroup>[group]);

    if (file == null || !mounted) {
      return;
    }

    final bytes = await file.readAsBytes();

    if (!mounted) {
      return;
    }

    if (bytes.length > _maximumImageBytes) {
      setState(() {
        _imageError =
            'Файл больше 8 МБ. Выберите изображение меньшего размера.';
      });
      return;
    }

    setState(() {
      _imageName = file.name;
      _imageBase64 = base64Encode(bytes);
      _imageError = null;
      if (_type != CreativeMaterialType.image) {
        _type = CreativeMaterialType.image;
      }
    });
  }

  void _save() {
    final title = _titleController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название материала')),
      );
      return;
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final original = widget.material;
    final tags = _tagsController.text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);

    Navigator.of(context).pop(
      CreativeMaterial(
        id: original?.id ?? 'material_${DateTime.now().microsecondsSinceEpoch}',
        type: _type,
        title: title,
        body: _bodyController.text,
        source: _sourceController.text,
        url: _urlController.text,
        folder: _folderController.text.trim().isEmpty
            ? 'Без папки'
            : _folderController.text.trim(),
        tags: tags,
        colorValue: _colorValue,
        linkedSceneIds: _sceneIds.toList(growable: false),
        linkedCharacterNames: _characters.toList(growable: false),
        usedBlockIds: original?.usedBlockIds ?? const <String>[],
        imageName: _imageName,
        imageBase64: _imageBase64,
        createdAt: original?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }
}

IconData _typeIcon(CreativeMaterialType type) {
  return switch (type) {
    CreativeMaterialType.idea => Icons.lightbulb_outline,
    CreativeMaterialType.quote => Icons.format_quote,
    CreativeMaterialType.link => Icons.link,
    CreativeMaterialType.image => Icons.image_outlined,
    CreativeMaterialType.research => Icons.science_outlined,
    CreativeMaterialType.character => Icons.person_outline,
    CreativeMaterialType.location => Icons.location_on_outlined,
    CreativeMaterialType.unusedScene => Icons.content_cut,
  };
}
