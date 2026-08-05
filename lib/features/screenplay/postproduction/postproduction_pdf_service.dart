import 'dart:typed_data';

import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/pdf/screenplay_pdf_service.dart';
import 'package:filmsoz_studio/features/screenplay/postproduction/postproduction.dart';
import 'package:filmsoz_studio/features/screenplay/postproduction/postproduction_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PostProductionPdfService {
  PostProductionPdfService({ScreenplayPdfFontLoader? fontLoader})
      : _fontLoader = fontLoader ?? ScreenplayPdfSystemFontLoader.load;

  final ScreenplayPdfFontLoader _fontLoader;
  final PostProductionService _service = const PostProductionService();

  Future<Uint8List> buildReadinessPdf(
    FilmDocument document, {
    required String projectName,
  }) async {
    final fonts = await _fontLoader();
    final theme = pw.ThemeData.withFont(
      base: fonts.regular,
      bold: fonts.bold,
      italic: fonts.italic,
      boldItalic: fonts.boldItalic,
      fontFallback: <pw.Font>[fonts.regular],
    );
    final title = projectName.trim().isEmpty ? 'Без названия' : projectName;
    final summary = _service.summarize(document);
    final pdf = pw.Document(
      title: '$title — готовность постпродакшна',
      author: 'Filmsoz Studio',
      creator: 'Filmsoz Studio',
      producer: 'Filmsoz Studio',
      subject: 'Post-production readiness report',
      theme: theme,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        maxPages: 500,
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.grey500, width: 0.5),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: <pw.Widget>[
              pw.Text(
                title,
                style: const pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Готовность: ${summary.overallProgress.toStringAsFixed(0)}%',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Страница ${context.pageNumber}',
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey700,
            ),
          ),
        ),
        build: (context) => <pw.Widget>[
          pw.SizedBox(height: 10),
          pw.Text(
            'ОТЧЁТ О ГОТОВНОСТИ ПОСТПРОДАКШНА',
            style: const pw.TextStyle(
              fontSize: 17,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),
          _buildSummary(summary),
          pw.SizedBox(height: 18),
          _sectionTitle('Сцены'),
          ...document.sceneSections.map((scene) {
            final data = document.scenePostProductionFor(scene.id);
            return _sceneCard(scene.number, scene.title, data);
          }),
          pw.SizedBox(height: 12),
          _sectionTitle('Задачи'),
          if (document.postProductionTasks.isEmpty)
            _emptyText('Задачи пока не созданы.'),
          ...document.postProductionTasks.map(
            (task) => _taskCard(document, task),
          ),
          pw.SizedBox(height: 12),
          _sectionTitle('Версии монтажа'),
          if (document.editVersions.isEmpty)
            _emptyText('Версии монтажа пока не добавлены.'),
          ...document.editVersions.map(
            (version) => _versionCard(document, version),
          ),
          pw.SizedBox(height: 12),
          _sectionTitle('Отсутствующий материал и пересъёмки'),
          if (document.missingMaterials.isEmpty)
            _emptyText('Открытых позиций нет.'),
          ...document.missingMaterials.map(
            (item) => _missingMaterialCard(document, item),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildSummary(PostProductionSummary summary) {
    return pw.Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <pw.Widget>[
        _summaryCell('Общая готовность',
            '${summary.overallProgress.toStringAsFixed(0)}%'),
        _summaryCell('Готовые сцены',
            '${summary.readySceneCount}/${summary.sceneCount}'),
        _summaryCell('Средний прогресс сцен',
            '${summary.averageSceneProgress.toStringAsFixed(0)}%'),
        _summaryCell('Выполненные задачи',
            '${summary.completedTaskCount}/${summary.taskCount}'),
        _summaryCell('Просрочено', '${summary.overdueTaskCount}'),
        _summaryCell(
            'Не хватает материала', '${summary.openMissingMaterialCount}'),
      ],
    );
  }

  pw.Widget _summaryCell(String label, String value) {
    return pw.Container(
      width: 160,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey500, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
          pw.SizedBox(height: 3),
          pw.Text(
            value,
            style: const pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _sectionTitle(String value) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 7),
      padding: const pw.EdgeInsets.only(bottom: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey600, width: 0.7),
        ),
      ),
      child: pw.Text(
        value,
        style: const pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _sceneCard(
    int sceneNumber,
    String title,
    ScenePostProductionData data,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      padding: const pw.EdgeInsets.all(7),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Row(
            children: <pw.Widget>[
              pw.Expanded(
                child: pw.Text(
                  '$sceneNumber. $title',
                  style: const pw.TextStyle(
                    fontSize: 9.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Text(
                '${data.status.label} • ${data.progress}%',
                style: const pw.TextStyle(fontSize: 8.5),
              ),
            ],
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            'Режиссёр: ${data.directorApproval.label} • Продюсер: ${data.producerApproval.label} • '
            'Выбранных дублей: ${data.selectedTakeIds.length}',
            style: const pw.TextStyle(fontSize: 7.8),
          ),
          if (data.editorNotes.trim().isNotEmpty)
            _noteLine('Монтажёр', data.editorNotes),
          if (data.directorNotes.trim().isNotEmpty)
            _noteLine('Режиссёр', data.directorNotes),
        ],
      ),
    );
  }

  pw.Widget _taskCard(FilmDocument document, PostProductionTask task) {
    final scene =
        task.sceneId == null ? null : document.sceneById(task.sceneId!);
    final version = task.versionId == null
        ? null
        : document.editVersionById(task.versionId!);

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      padding: const pw.EdgeInsets.all(7),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Row(
            children: <pw.Widget>[
              pw.Expanded(
                child: pw.Text(
                  task.title,
                  style: const pw.TextStyle(
                    fontSize: 9.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Text(
                '${task.status.label} • ${task.progress}%',
                style: const pw.TextStyle(fontSize: 8.5),
              ),
            ],
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            '${task.department.label} • ${task.priority.label} • '
            'Ответственный: ${_orDash(task.assignee)} • Срок: ${_orDash(task.dueDate)}',
            style: const pw.TextStyle(fontSize: 7.8),
          ),
          if (scene != null || version != null)
            pw.Text(
              'Сцена: ${scene == null ? '—' : '${scene.number}. ${scene.title}'} • '
              'Версия: ${version?.title ?? '—'}',
              style: const pw.TextStyle(fontSize: 7.8),
            ),
          if (task.notes.trim().isNotEmpty) _noteLine('Примечания', task.notes),
        ],
      ),
    );
  }

  pw.Widget _versionCard(FilmDocument document, EditVersion version) {
    final sequence = version.sequenceId == null
        ? null
        : document.postProductionSequenceById(version.sequenceId!);

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      padding: const pw.EdgeInsets.all(7),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Row(
            children: <pw.Widget>[
              pw.Expanded(
                child: pw.Text(
                  'v${version.versionNumber} — ${version.title}',
                  style: const pw.TextStyle(
                    fontSize: 9.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              if (version.isCurrent)
                pw.Text(
                  'ТЕКУЩАЯ',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green700,
                  ),
                ),
            ],
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            'Эпизод: ${sequence?.title ?? '—'} • Программа: ${_orDash(version.application)} • '
            'Дата: ${_orDash(version.createdAt)} • Длительность: ${_service.formatDuration(version.durationSeconds)}',
            style: const pw.TextStyle(fontSize: 7.8),
          ),
          if (version.filePath.trim().isNotEmpty)
            _noteLine('Файл', version.filePath),
          if (version.notes.trim().isNotEmpty)
            _noteLine('Примечания', version.notes),
        ],
      ),
    );
  }

  pw.Widget _missingMaterialCard(
    FilmDocument document,
    MissingMaterialItem item,
  ) {
    final scene =
        item.sceneId == null ? null : document.sceneById(item.sceneId!);

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      padding: const pw.EdgeInsets.all(7),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Row(
            children: <pw.Widget>[
              pw.Expanded(
                child: pw.Text(
                  item.title,
                  style: const pw.TextStyle(
                    fontSize: 9.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Text(
                '${item.type.label} • ${item.status.label}',
                style: const pw.TextStyle(fontSize: 8.5),
              ),
            ],
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            'Сцена: ${scene == null ? '—' : '${scene.number}. ${scene.title}'} • '
            'Дата: ${_orDash(item.scheduledDate)} • Ответственный: ${_orDash(item.assignee)}',
            style: const pw.TextStyle(fontSize: 7.8),
          ),
          if (item.description.trim().isNotEmpty)
            _noteLine('Описание', item.description),
        ],
      ),
    );
  }

  pw.Widget _noteLine(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 2),
      child: pw.Text(
        '$label: ${value.trim()}',
        style: const pw.TextStyle(fontSize: 7.8),
      ),
    );
  }

  pw.Widget _emptyText(String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
        value,
        style: const pw.TextStyle(
          fontSize: 8.5,
          color: PdfColors.grey700,
        ),
      ),
    );
  }

  String _orDash(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? '—' : normalized;
  }
}
