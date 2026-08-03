import 'dart:async';

import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/document/scene_section.dart';
import 'package:filmsoz_studio/features/screenplay/pdf/screenplay_pdf_file_service.dart';
import 'package:filmsoz_studio/features/screenplay/pdf/screenplay_pdf_options.dart';
import 'package:filmsoz_studio/features/screenplay/pdf/screenplay_pdf_service.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class ScreenplayPdfExportDialog extends StatefulWidget {
  const ScreenplayPdfExportDialog({
    super.key,
    required this.document,
    required this.projectName,
    this.pdfService,
    this.fileService = const ScreenplayPdfFileService(),
  });

  final FilmDocument document;
  final String projectName;
  final ScreenplayPdfService? pdfService;
  final ScreenplayPdfFileService fileService;

  @override
  State<ScreenplayPdfExportDialog> createState() =>
      _ScreenplayPdfExportDialogState();
}

class _ScreenplayPdfExportDialogState extends State<ScreenplayPdfExportDialog> {
  late final ScreenplayPdfService _pdfService;
  late final TextEditingController _titleController;
  late final TextEditingController _authorController;
  late final TextEditingController _contactController;
  late final TextEditingController _draftController;
  late final Set<String> _selectedSceneIds;

  ScreenplayPdfScope _scope = ScreenplayPdfScope.entireDocument;
  bool _includeTitlePage = true;
  bool _showPageNumbers = true;
  bool _showSceneNumbers = true;
  bool _isSaving = false;
  bool _isPrinting = false;
  double _fontSize = 12;
  double _lineSpacing = 1;
  int _previewRevision = 0;

  List<SceneSection> get _scenes => widget.document.sceneSections;

  bool get _hasExportableScenes {
    return _scope == ScreenplayPdfScope.entireDocument ||
        _selectedSceneIds.isNotEmpty;
  }

  ScreenplayPdfOptions get _options {
    return ScreenplayPdfOptions(
      title: _titleController.text,
      author: _authorController.text,
      contact: _contactController.text,
      draftLabel: _draftController.text,
      includeTitlePage: _includeTitlePage,
      showPageNumbers: _showPageNumbers,
      showSceneNumbers: _showSceneNumbers,
      scope: _scope,
      selectedSceneIds: Set<String>.unmodifiable(_selectedSceneIds),
      fontSize: _fontSize,
      lineSpacing: _lineSpacing,
    );
  }

  @override
  void initState() {
    super.initState();
    _pdfService = widget.pdfService ?? ScreenplayPdfService();
    _titleController = TextEditingController(text: widget.projectName);
    _authorController = TextEditingController();
    _contactController = TextEditingController();
    _draftController = TextEditingController(text: 'Рабочая версия');
    _selectedSceneIds = _scenes.map((scene) => scene.id).toSet();

    for (final controller in <TextEditingController>[
      _titleController,
      _authorController,
      _contactController,
      _draftController,
    ]) {
      controller.addListener(_refreshPreview);
    }
  }

  void _refreshPreview() {
    if (!mounted) {
      return;
    }

    setState(() {
      _previewRevision++;
    });
  }

  Future<void> _savePdf() async {
    if (!_hasExportableScenes || _isSaving) {
      return;
    }

    final selectedPath = await widget.fileService.chooseSaveFile(
      suggestedName: _titleController.text.trim().isEmpty
          ? widget.projectName
          : _titleController.text,
    );

    if (selectedPath == null || !mounted) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final bytes = await _pdfService.buildPdf(
        widget.document,
        options: _options,
        pageFormat: PdfPageFormat.a4,
      );
      final savedPath = await widget.fileService.writePdf(selectedPath, bytes);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF сохранён: $savedPath')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ошибка экспорта PDF'),
          content: SelectableText('$error'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Закрыть'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _printPdf() async {
    if (!_hasExportableScenes || _isPrinting) {
      return;
    }

    setState(() {
      _isPrinting = true;
    });

    try {
      await Printing.layoutPdf(
        name: '${_safeTitle()}.pdf',
        format: PdfPageFormat.a4,
        dynamicLayout: false,
        usePrinterSettings: true,
        windowsModernDialog: true,
        onLayout: (format) => _pdfService.buildPdf(
          widget.document,
          options: _options,
          pageFormat: format,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть печать: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPrinting = false;
        });
      }
    }
  }

  String _safeTitle() {
    final title = _titleController.text.trim();
    return title.isEmpty ? 'Без названия' : title;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 1320,
        height: 820,
        child: Column(
          children: <Widget>[
            _buildHeader(),
            const Divider(height: 1),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 900) {
                    return Column(
                      children: <Widget>[
                        SizedBox(
                          height: 320,
                          child: _buildSettingsPanel(),
                        ),
                        const Divider(height: 1),
                        Expanded(child: _buildPreview()),
                      ],
                    );
                  }

                  return Row(
                    children: <Widget>[
                      SizedBox(
                        width: 365,
                        child: _buildSettingsPanel(),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: _buildPreview()),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 58,
      color: const Color(0xFF2B2B2E),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: <Widget>[
          const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFFE5A93C)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'PDF, предварительный просмотр и печать',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _hasExportableScenes && !_isPrinting
                ? () => unawaited(_printPdf())
                : null,
            icon: _isPrinting
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print_outlined, size: 18),
            label: const Text('Печать'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _hasExportableScenes && !_isSaving
                ? () => unawaited(_savePdf())
                : null,
            icon: _isSaving
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_alt, size: 18),
            label: const Text('Сохранить PDF'),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Закрыть',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsPanel() {
    return Material(
      color: const Color(0xFFF7F7F8),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const _SectionTitle('Титульная страница'),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Название сценария',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _authorController,
            decoration: const InputDecoration(
              labelText: 'Автор',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _draftController,
            decoration: const InputDecoration(
              labelText: 'Версия / дата',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _contactController,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Контакты',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Добавлять титульную страницу'),
            value: _includeTitlePage,
            onChanged: (value) {
              setState(() {
                _includeTitlePage = value;
                _previewRevision++;
              });
            },
          ),
          const Divider(height: 28),
          const _SectionTitle('Содержание'),
          SegmentedButton<ScreenplayPdfScope>(
            segments: const <ButtonSegment<ScreenplayPdfScope>>[
              ButtonSegment<ScreenplayPdfScope>(
                value: ScreenplayPdfScope.entireDocument,
                label: Text('Весь сценарий'),
                icon: Icon(Icons.description_outlined),
              ),
              ButtonSegment<ScreenplayPdfScope>(
                value: ScreenplayPdfScope.selectedScenes,
                label: Text('Сцены'),
                icon: Icon(Icons.checklist),
              ),
            ],
            selected: <ScreenplayPdfScope>{_scope},
            onSelectionChanged: (selection) {
              setState(() {
                _scope = selection.first;
                _previewRevision++;
              });
            },
          ),
          if (_scope == ScreenplayPdfScope.selectedScenes) ...<Widget>[
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedSceneIds
                        ..clear()
                        ..addAll(_scenes.map((scene) => scene.id));
                      _previewRevision++;
                    });
                  },
                  child: const Text('Выбрать все'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedSceneIds.clear();
                      _previewRevision++;
                    });
                  },
                  child: const Text('Снять выбор'),
                ),
              ],
            ),
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFD7D7DB)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _scenes.length,
                itemBuilder: (context, index) {
                  final scene = _scenes[index];
                  final selected = _selectedSceneIds.contains(scene.id);

                  return CheckboxListTile(
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: selected,
                    title: Text(
                      '${scene.number}. ${scene.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    subtitle: Text(
                      '${scene.wordCount} слов',
                      style: const TextStyle(fontSize: 10),
                    ),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedSceneIds.add(scene.id);
                        } else {
                          _selectedSceneIds.remove(scene.id);
                        }
                        _previewRevision++;
                      });
                    },
                  );
                },
              ),
            ),
            if (_selectedSceneIds.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Выбери хотя бы одну сцену.',
                  style: TextStyle(color: Colors.red, fontSize: 11),
                ),
              ),
          ],
          const Divider(height: 28),
          const _SectionTitle('Оформление A4'),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Номера страниц'),
            value: _showPageNumbers,
            onChanged: (value) {
              setState(() {
                _showPageNumbers = value;
                _previewRevision++;
              });
            },
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Номера сцен с двух сторон'),
            value: _showSceneNumbers,
            onChanged: (value) {
              setState(() {
                _showSceneNumbers = value;
                _previewRevision++;
              });
            },
          ),
          Text('Размер шрифта: ${_fontSize.toStringAsFixed(0)} pt'),
          Slider(
            value: _fontSize,
            min: 10,
            max: 14,
            divisions: 4,
            label: '${_fontSize.toStringAsFixed(0)} pt',
            onChanged: (value) {
              setState(() {
                _fontSize = value;
                _previewRevision++;
              });
            },
          ),
          Text(
            'Дополнительный межстрочный интервал: '
            '${_lineSpacing.toStringAsFixed(0)} pt',
          ),
          Slider(
            value: _lineSpacing,
            min: 0,
            max: 4,
            divisions: 4,
            label: '${_lineSpacing.toStringAsFixed(0)} pt',
            onChanged: (value) {
              setState(() {
                _lineSpacing = value;
                _previewRevision++;
              });
            },
          ),
          const SizedBox(height: 8),
          const Text(
            'Шрифт загружается из системных Courier New / Arial. '
            'Это сохраняет русскую и таджикскую кириллицу в PDF.',
            style: TextStyle(color: Color(0xFF6C6C72), fontSize: 10.5),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (!_hasExportableScenes) {
      return const Center(
        child: Text('Выбери хотя бы одну сцену для предпросмотра.'),
      );
    }

    return ColoredBox(
      color: const Color(0xFF202022),
      child: PdfPreview(
        key: ValueKey<int>(_previewRevision),
        build: (format) => _pdfService.buildPdf(
          widget.document,
          options: _options,
          pageFormat: PdfPageFormat.a4,
        ),
        initialPageFormat: PdfPageFormat.a4,
        pageFormats: const <String, PdfPageFormat>{'A4': PdfPageFormat.a4},
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        allowPrinting: false,
        allowSharing: false,
        useActions: false,
        dynamicLayout: false,
        maxPageWidth: 760,
        pdfFileName: '${_safeTitle()}.pdf',
        shouldRepaint: true,
        loadingWidget: const Center(child: CircularProgressIndicator()),
        onError: (context, error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SelectableText(
              'Не удалось построить предпросмотр:\n$error',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _titleController,
      _authorController,
      _contactController,
      _draftController,
    ]) {
      controller
        ..removeListener(_refreshPreview)
        ..dispose();
    }

    super.dispose();
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF7A5A20),
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}
