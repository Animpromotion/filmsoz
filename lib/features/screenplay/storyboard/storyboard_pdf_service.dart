import 'dart:typed_data';

import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/pdf/screenplay_pdf_service.dart';
import 'package:filmsoz_studio/features/screenplay/storyboard/storyboard_service.dart';
import 'package:filmsoz_studio/features/screenplay/storyboard/storyboard_shot.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class StoryboardPdfService {
  StoryboardPdfService({ScreenplayPdfFontLoader? fontLoader})
      : _fontLoader = fontLoader ?? ScreenplayPdfSystemFontLoader.load;

  final ScreenplayPdfFontLoader _fontLoader;
  final StoryboardService _storyboardService = const StoryboardService();

  Future<Uint8List> buildPdf(
    FilmDocument document, {
    required String projectName,
  }) async {
    final shots = _storyboardService.numberedShots(document);

    if (shots.isEmpty) {
      throw StateError('В раскадровке пока нет кадров.');
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
    final pdf = pw.Document(
      title: '$title — монтажный сценарий',
      author: 'Filmsoz Studio',
      creator: 'Filmsoz Studio',
      producer: 'Filmsoz Studio',
      subject: 'Storyboard and shot list',
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
                'Монтажный сценарий • ${shots.length} кадров • '
                '${_storyboardService.formatDuration(_storyboardService.totalDurationSeconds(document))}',
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
        build: (context) {
          return <pw.Widget>[
            pw.SizedBox(height: 10),
            ...shots.map(_buildShotCard),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildShotCard(NumberedStoryboardShot entry) {
    final shot = entry.shot;
    final imageBytes = shot.imageBytes;

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey500, width: 0.7),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.SizedBox(
            width: 190,
            height: 108,
            child: imageBytes == null
                ? pw.Container(
                    color: PdfColors.grey200,
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      'КАДР ${entry.number}',
                      style: const pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                  )
                : pw.Image(
                    pw.MemoryImage(imageBytes),
                    fit: pw.BoxFit.cover,
                  ),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: <pw.Widget>[
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      color: PdfColors.grey900,
                      child: pw.Text(
                        entry.number,
                        style: const pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      child: pw.Text(
                        '${entry.scene.number}. ${entry.scene.title}',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Text(
                      _storyboardService.formatDuration(shot.durationSeconds),
                      style: const pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (shot.title.trim().isNotEmpty) ...<pw.Widget>[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    shot.title.trim(),
                    style: const pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
                pw.SizedBox(height: 5),
                pw.Text(
                  '${shot.shotSize.label} • ${shot.cameraAngle.label} • '
                  '${shot.cameraMovement.label} • '
                  '${shot.lens.trim().isEmpty ? 'Объектив не указан' : shot.lens.trim()} • '
                  '${_formatNumber(shot.fps)} FPS',
                  style: const pw.TextStyle(fontSize: 8.5),
                ),
                if (shot.equipment.isNotEmpty) ...<pw.Widget>[
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Оборудование: ${shot.equipment.join(', ')}',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
                pw.SizedBox(height: 5),
                _descriptionLine('Изображение', shot.visualDescription),
                _descriptionLine('Действие', shot.actionDescription),
                _descriptionLine('Диалог', shot.dialogue),
                _descriptionLine('Звук', shot.sound),
                _descriptionLine('Примечания', shot.notes),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _descriptionLine(String label, String value) {
    if (value.trim().isEmpty) {
      return pw.SizedBox(height: 0);
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(
            '$label: ',
            style: const pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value.trim(),
              style: const pw.TextStyle(fontSize: 8.5),
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return '${value.toInt()}';
    }

    return value.toStringAsFixed(2);
  }
}
