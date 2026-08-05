import 'dart:typed_data';

import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/pdf/screenplay_pdf_service.dart';
import 'package:filmsoz_studio/features/screenplay/shooting_control/shooting_control.dart';
import 'package:filmsoz_studio/features/screenplay/shooting_control/shooting_control_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ShootingControlPdfService {
  ShootingControlPdfService({ScreenplayPdfFontLoader? fontLoader})
      : _fontLoader = fontLoader ?? ScreenplayPdfSystemFontLoader.load;

  final ScreenplayPdfFontLoader _fontLoader;
  final ShootingControlService _service = const ShootingControlService();

  Future<Uint8List> buildPdf(
    FilmDocument document, {
    required String projectName,
  }) async {
    final takes = _service.numberedTakes(document);

    if (takes.isEmpty) {
      throw StateError('В журнале пока нет дублей.');
    }

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
      title: '$title — монтажная ведомость',
      author: 'Filmsoz Studio',
      creator: 'Filmsoz Studio',
      producer: 'Filmsoz Studio',
      subject: 'Shooting control and editing log',
      theme: theme,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
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
                'Дубли: ${summary.takeCount} • Выбрано: ${summary.selectedCount} • '
                'Материал: ${_service.formatDuration(summary.totalRecordedSeconds)}',
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
          _buildSummary(summary),
          pw.SizedBox(height: 12),
          ...takes.map((entry) => _buildTakeCard(document, entry)),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildSummary(ShootingControlSummary summary) {
    return pw.Row(
      children: <pw.Widget>[
        _summaryCell('Кадров', '${summary.shotCount}'),
        pw.SizedBox(width: 8),
        _summaryCell('Дублей', '${summary.takeCount}'),
        pw.SizedBox(width: 8),
        _summaryCell('Снято', '${summary.recordedCount}'),
        pw.SizedBox(width: 8),
        _summaryCell('Брак', '${summary.rejectedCount}'),
        pw.SizedBox(width: 8),
        _summaryCell('Выбрано', '${summary.selectedCount}'),
        pw.SizedBox(width: 8),
        _summaryCell(
          'Без выбора',
          '${summary.shotsWithoutSelectedTake}',
        ),
      ],
    );
  }

  pw.Widget _summaryCell(String label, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey500, width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
            pw.SizedBox(height: 2),
            pw.Text(
              value,
              style: const pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildTakeCard(
    FilmDocument document,
    NumberedShotTake entry,
  ) {
    final take = entry.take;
    final day = take.shootingDayId == null
        ? null
        : document.shootingDayById(take.shootingDayId!);
    final statusColor = switch (take.status) {
      ShotTakeStatus.planned => PdfColors.grey600,
      ShotTakeStatus.recorded => PdfColors.blue700,
      ShotTakeStatus.rejected => PdfColors.red700,
      ShotTakeStatus.selected => PdfColors.green700,
    };

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey500, width: 0.6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Row(
            children: <pw.Widget>[
              pw.Container(
                color: statusColor,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 3,
                ),
                child: pw.Text(
                  entry.takeLabel,
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Text(
                  '${entry.scene.title} • ${entry.shot.title.trim().isEmpty ? 'Кадр без названия' : entry.shot.title.trim()}',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Text(
                '${take.status.label} • ${_service.formatDuration(take.durationSeconds)}',
                style: const pw.TextStyle(fontSize: 8.5),
              ),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'День: ${day?.title ?? 'не назначен'} • Таймкод: ${_orDash(take.timecode)} • '
            'Карта: ${_orDash(take.mediaCard)} • Камера: ${_orDash(take.camera)} • '
            'Файл: ${_orDash(take.fileName)} • Оценка: ${take.rating}/5',
            style: const pw.TextStyle(fontSize: 8),
          ),
          if (take.rejectionReason.trim().isNotEmpty)
            _line('Причина брака', take.rejectionReason),
          _line('Режиссёр', take.directorNotes),
          _line('Оператор', take.cameraNotes),
          _line('Звук', take.soundNotes),
          if (take.hasContinuityData) ...<pw.Widget>[
            pw.SizedBox(height: 4),
            pw.Text(
              'Непрерывность',
              style: const pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            _line('Костюм', take.costumeContinuity),
            _line('Грим', take.makeupContinuity),
            _line('Реквизит', take.propsContinuity),
            _line('Положение актёров', take.actorPositions),
            if (take.continuityPhotos.isNotEmpty)
              pw.Text(
                'Фотографии: ${take.continuityPhotos.length}',
                style: const pw.TextStyle(fontSize: 8),
              ),
          ],
        ],
      ),
    );
  }

  pw.Widget _line(String label, String value) {
    if (value.trim().isEmpty) {
      return pw.SizedBox(height: 0);
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(
            '$label: ',
            style: const pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value.trim(),
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
        ],
      ),
    );
  }

  String _orDash(String value) {
    return value.trim().isEmpty ? '—' : value.trim();
  }
}
