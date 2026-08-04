import 'dart:io';
import 'dart:typed_data';

import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/document/scene_section.dart';
import 'package:filmsoz_studio/features/screenplay/pdf/screenplay_pdf_options.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ScreenplayPdfFonts {
  const ScreenplayPdfFonts({
    required this.regular,
    required this.bold,
    required this.italic,
    required this.boldItalic,
  });

  final pw.Font regular;
  final pw.Font bold;
  final pw.Font italic;
  final pw.Font boldItalic;

  factory ScreenplayPdfFonts.type1ForTests() {
    return ScreenplayPdfFonts(
      regular: pw.Font.courier(),
      bold: pw.Font.courierBold(),
      italic: pw.Font.courierOblique(),
      boldItalic: pw.Font.courierBoldOblique(),
    );
  }
}

typedef ScreenplayPdfFontLoader = Future<ScreenplayPdfFonts> Function();

class ScreenplayPdfService {
  ScreenplayPdfService({ScreenplayPdfFontLoader? fontLoader})
      : _fontLoader = fontLoader ?? ScreenplayPdfSystemFontLoader.load;

  static const double _millimeter = PdfPageFormat.mm;

  final ScreenplayPdfFontLoader _fontLoader;

  List<SceneSection> selectedScenes(
    FilmDocument document,
    ScreenplayPdfOptions options,
  ) {
    return options.resolveScenes(document);
  }

  Future<Uint8List> buildPdf(
    FilmDocument document, {
    required ScreenplayPdfOptions options,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
  }) async {
    final scenes = selectedScenes(document, options);

    if (scenes.isEmpty) {
      throw StateError('Для экспорта должна быть выбрана хотя бы одна сцена.');
    }

    final fonts = await _fontLoader();
    final theme = pw.ThemeData.withFont(
      base: fonts.regular,
      bold: fonts.bold,
      italic: fonts.italic,
      boldItalic: fonts.boldItalic,
      fontFallback: <pw.Font>[fonts.regular],
    );

    final pdf = pw.Document(
      title: _documentTitle(options),
      author: options.author.trim(),
      creator: 'Filmsoz Studio',
      producer: 'Filmsoz Studio',
      subject: 'Screenplay',
      theme: theme,
    );

    if (options.includeTitlePage) {
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.fromLTRB(
            28 * _millimeter,
            24 * _millimeter,
            22 * _millimeter,
            22 * _millimeter,
          ),
          build: (_) => _buildTitlePage(options),
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        maxPages: 500,
        margin: const pw.EdgeInsets.fromLTRB(
          25 * _millimeter,
          18 * _millimeter,
          20 * _millimeter,
          18 * _millimeter,
        ),
        footer: options.showPageNumbers
            ? (context) => _buildPageFooter(context, options)
            : null,
        build: (_) => _buildScreenplay(scenes, options),
      ),
    );

    return pdf.save();
  }

  String _documentTitle(ScreenplayPdfOptions options) {
    final title = options.title.trim();
    return title.isEmpty ? 'Без названия' : title;
  }

  pw.Widget _buildTitlePage(ScreenplayPdfOptions options) {
    final title = _documentTitle(options).toUpperCase();
    final author = options.author.trim();
    final contact = options.contact.trim();
    final draftLabel = options.draftLabel.trim();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: <pw.Widget>[
        pw.Spacer(flex: 4),
        pw.Text(
          title,
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            lineSpacing: 1,
          ),
        ),
        if (draftLabel.isNotEmpty) ...<pw.Widget>[
          pw.SizedBox(height: 10),
          pw.Text(
            draftLabel,
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 11),
          ),
        ],
        pw.Spacer(flex: 5),
        if (author.isNotEmpty)
          pw.Text(
            'Автор: $author',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 12),
          ),
        pw.Spacer(flex: 2),
        if (contact.isNotEmpty)
          pw.Align(
            alignment: pw.Alignment.bottomLeft,
            child: pw.Text(
              contact,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
      ],
    );
  }

  pw.Widget _buildPageFooter(
    pw.Context context,
    ScreenplayPdfOptions options,
  ) {
    final title = _documentTitle(options);

    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 4 * _millimeter),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          pw.Text(
            title,
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey700,
            ),
          ),
          pw.Text(
            '${context.pageNumber}',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey800,
            ),
          ),
        ],
      ),
    );
  }

  List<pw.Widget> _buildScreenplay(
    List<SceneSection> scenes,
    ScreenplayPdfOptions options,
  ) {
    final widgets = <pw.Widget>[];

    for (var sceneIndex = 0; sceneIndex < scenes.length; sceneIndex++) {
      final scene = scenes[sceneIndex];

      if (sceneIndex > 0) {
        widgets.add(pw.NewPage(freeSpace: 42 * _millimeter));
      }

      for (final block in scene.blocks) {
        widgets.addAll(_buildBlock(block, scene, options));
      }
    }

    return widgets;
  }

  List<pw.Widget> _buildBlock(
    FilmBlock block,
    SceneSection scene,
    ScreenplayPdfOptions options,
  ) {
    final text = block.text.trim();

    if (text.isEmpty) {
      return <pw.Widget>[
        pw.SizedBox(height: options.fontSize + options.lineSpacing),
      ];
    }

    final baseStyle = pw.TextStyle(
      fontSize: options.fontSize,
      lineSpacing: options.lineSpacing,
    );

    switch (block.type) {
      case BlockType.sceneHeading:
        return <pw.Widget>[
          _buildSceneHeading(scene, options, baseStyle),
        ];
      case BlockType.action:
        return <pw.Widget>[
          pw.Paragraph(
            text: text,
            textAlign: pw.TextAlign.left,
            style: baseStyle,
            margin: const pw.EdgeInsets.only(bottom: 3.5 * _millimeter),
          ),
        ];
      case BlockType.character:
        return <pw.Widget>[
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(
              63 * _millimeter,
              2.5 * _millimeter,
              20 * _millimeter,
              1 * _millimeter,
            ),
            child: pw.Text(
              text.toUpperCase(),
              style: baseStyle.copyWith(fontWeight: pw.FontWeight.bold),
            ),
          ),
        ];
      case BlockType.dialogue:
        return <pw.Widget>[
          pw.Paragraph(
            text: text,
            textAlign: pw.TextAlign.left,
            style: baseStyle,
            margin: const pw.EdgeInsets.fromLTRB(
              34 * _millimeter,
              0,
              33 * _millimeter,
              3.5 * _millimeter,
            ),
          ),
        ];
      case BlockType.parenthetical:
        return <pw.Widget>[
          pw.Paragraph(
            text: text,
            textAlign: pw.TextAlign.left,
            style: baseStyle.copyWith(fontStyle: pw.FontStyle.italic),
            margin: const pw.EdgeInsets.fromLTRB(
              48 * _millimeter,
              0,
              42 * _millimeter,
              1 * _millimeter,
            ),
          ),
        ];
      case BlockType.transition:
        return <pw.Widget>[
          pw.Padding(
            padding: const pw.EdgeInsets.only(
              top: 2 * _millimeter,
              bottom: 4 * _millimeter,
            ),
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                text.toUpperCase(),
                style: baseStyle.copyWith(fontWeight: pw.FontWeight.bold),
              ),
            ),
          ),
        ];
    }
  }

  pw.Widget _buildSceneHeading(
    SceneSection scene,
    ScreenplayPdfOptions options,
    pw.TextStyle baseStyle,
  ) {
    final heading = scene.title.toUpperCase();
    final headingStyle = baseStyle.copyWith(fontWeight: pw.FontWeight.bold);

    if (!options.showSceneNumbers) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(
          top: 4 * _millimeter,
          bottom: 3.5 * _millimeter,
        ),
        child: pw.Text(heading, style: headingStyle),
      );
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.only(
        top: 4 * _millimeter,
        bottom: 3.5 * _millimeter,
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.SizedBox(
            width: 14 * _millimeter,
            child: pw.Text(
              '${scene.number}.',
              style: headingStyle,
            ),
          ),
          pw.Expanded(
            child: pw.Text(heading, style: headingStyle),
          ),
          pw.SizedBox(
            width: 14 * _millimeter,
            child: pw.Text(
              '${scene.number}.',
              textAlign: pw.TextAlign.right,
              style: headingStyle,
            ),
          ),
        ],
      ),
    );
  }
}

class ScreenplayPdfSystemFontLoader {
  ScreenplayPdfSystemFontLoader._();

  static Future<ScreenplayPdfFonts>? _cachedFonts;

  static Future<ScreenplayPdfFonts> load() {
    return _cachedFonts ??= _loadFonts();
  }

  static Future<ScreenplayPdfFonts> _loadFonts() async {
    final candidates = _fontCandidates();
    final regular = await _loadFirst(candidates.regular);

    if (regular != null) {
      return ScreenplayPdfFonts(
        regular: regular,
        bold: await _loadFirst(candidates.bold) ?? regular,
        italic: await _loadFirst(candidates.italic) ?? regular,
        boldItalic: await _loadFirst(candidates.boldItalic) ?? regular,
      );
    }

    return ScreenplayPdfFonts(
      regular: await PdfGoogleFonts.robotoMonoRegular(),
      bold: await PdfGoogleFonts.robotoMonoBold(),
      italic: await PdfGoogleFonts.robotoMonoItalic(),
      boldItalic: await PdfGoogleFonts.robotoMonoBoldItalic(),
    );
  }

  static Future<pw.Font?> _loadFirst(List<String> paths) async {
    for (final fontPath in paths) {
      final file = File(fontPath);

      if (!await file.exists()) {
        continue;
      }

      final bytes = await file.readAsBytes();
      final data = bytes.buffer.asByteData(
        bytes.offsetInBytes,
        bytes.lengthInBytes,
      );
      return pw.Font.ttf(data);
    }

    return null;
  }

  static _SystemFontCandidates _fontCandidates() {
    if (Platform.isWindows) {
      final windowsDirectory = Platform.environment['WINDIR'] ?? r'C:\Windows';
      final fonts = '$windowsDirectory\\Fonts';

      return _SystemFontCandidates(
        regular: <String>['$fonts\\cour.ttf', '$fonts\\arial.ttf'],
        bold: <String>['$fonts\\courbd.ttf', '$fonts\\arialbd.ttf'],
        italic: <String>['$fonts\\couri.ttf', '$fonts\\ariali.ttf'],
        boldItalic: <String>['$fonts\\courbi.ttf', '$fonts\\arialbi.ttf'],
      );
    }

    if (Platform.isMacOS) {
      return const _SystemFontCandidates(
        regular: <String>[
          '/System/Library/Fonts/Supplemental/Courier New.ttf',
          '/System/Library/Fonts/Supplemental/Arial.ttf',
        ],
        bold: <String>[
          '/System/Library/Fonts/Supplemental/Courier New Bold.ttf',
          '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
        ],
        italic: <String>[
          '/System/Library/Fonts/Supplemental/Courier New Italic.ttf',
          '/System/Library/Fonts/Supplemental/Arial Italic.ttf',
        ],
        boldItalic: <String>[
          '/System/Library/Fonts/Supplemental/Courier New Bold Italic.ttf',
          '/System/Library/Fonts/Supplemental/Arial Bold Italic.ttf',
        ],
      );
    }

    return const _SystemFontCandidates(
      regular: <String>[
        '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf',
        '/usr/share/fonts/truetype/liberation2/LiberationMono-Regular.ttf',
      ],
      bold: <String>[
        '/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf',
        '/usr/share/fonts/truetype/liberation2/LiberationMono-Bold.ttf',
      ],
      italic: <String>[
        '/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Oblique.ttf',
        '/usr/share/fonts/truetype/liberation2/LiberationMono-Italic.ttf',
      ],
      boldItalic: <String>[
        '/usr/share/fonts/truetype/dejavu/DejaVuSansMono-BoldOblique.ttf',
        '/usr/share/fonts/truetype/liberation2/LiberationMono-BoldItalic.ttf',
      ],
    );
  }
}

class _SystemFontCandidates {
  const _SystemFontCandidates({
    required this.regular,
    required this.bold,
    required this.italic,
    required this.boldItalic,
  });

  final List<String> regular;
  final List<String> bold;
  final List<String> italic;
  final List<String> boldItalic;
}
