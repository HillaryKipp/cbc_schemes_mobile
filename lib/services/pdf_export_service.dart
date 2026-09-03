import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/scheme.dart';

class PdfExportService {
  /// Generate printable 10-column landscape PDF bytes
  static Future<Uint8List> generateSchemePdf(Scheme scheme) async {
    final pdf = pw.Document();

    final fontRegular = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();

    final theme = pw.ThemeData.withFont(
      base: fontRegular,
      bold: fontBold,
    );

    // Filter and sort rows
    final rows = List.from(scheme.rows)..sort((a, b) => a.position.compareTo(b.position));

    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        header: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  (scheme.schoolName?.trim().isNotEmpty == true)
                      ? scheme.schoolName!.toUpperCase()
                      : 'KENYA COMPETENCY BASED CURRICULUM (CBC)',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'SCHEMES OF WORK - ${scheme.termName.toUpperCase()}, ${scheme.year}',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900),
                ),
                pw.SizedBox(height: 6),
                // Metadata Bar
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                    color: PdfColors.grey100,
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('GRADE: ${scheme.gradeName ?? "Grade"}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      pw.Text('LEARNING AREA: ${scheme.subjectName ?? "Subject"}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      pw.Text('TEACHER: ${scheme.teacherName ?? "________________"}', style: pw.TextStyle(fontSize: 8)),
                      pw.Text('TSC NO: ${scheme.tscNumber ?? "________"}', style: pw.TextStyle(fontSize: 8)),
                      pw.Text('COURSE BOOK: ${scheme.referenceBookTitle ?? "Approved CBC Books"}', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 6),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 8),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Generated with CBC Schemes of Work App', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                pw.Text('H.O.D Sign: __________________   Date: ____________', style: const pw.TextStyle(fontSize: 8)),
                pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(26), // Wk
                1: const pw.FixedColumnWidth(26), // Lsn
                2: const pw.FlexColumnWidth(1.2), // Strand
                3: const pw.FlexColumnWidth(1.3), // Sub-strand
                4: const pw.FlexColumnWidth(2.6), // Specific Learning Outcomes
                5: const pw.FlexColumnWidth(2.0), // Key Inquiry Questions
                6: const pw.FlexColumnWidth(2.4), // Learning Experiences
                7: const pw.FlexColumnWidth(2.0), // Learning Resources
                8: const pw.FlexColumnWidth(1.8), // Assessment Methods
                9: const pw.FlexColumnWidth(1.4), // Reflections
              },
              children: [
                // Table Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.teal800),
                  children: [
                    _buildHeaderCell('WK'),
                    _buildHeaderCell('LSN'),
                    _buildHeaderCell('STRAND'),
                    _buildHeaderCell('SUB-STRAND'),
                    _buildHeaderCell('SPECIFIC LEARNING OUTCOMES'),
                    _buildHeaderCell('KEY INQUIRY QUESTIONS'),
                    _buildHeaderCell('LEARNING EXPERIENCES'),
                    _buildHeaderCell('LEARNING RESOURCES'),
                    _buildHeaderCell('ASSESSMENT METHODS'),
                    _buildHeaderCell('REFLECTIONS'),
                  ],
                ),
                // Data Rows
                ...rows.map((row) {
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: (row.lessonNumber % 2 == 0) ? PdfColors.grey50 : PdfColors.white,
                    ),
                    children: [
                      _buildCell('${row.weekNumber}', align: pw.TextAlign.center, bold: true),
                      _buildCell('${row.lessonNumber}', align: pw.TextAlign.center, bold: true),
                      _buildCell(row.strandName, bold: true),
                      _buildCell(row.subStrandName),
                      _buildCell(_formatBullets(row.learningOutcomes)),
                      _buildCell(_formatBullets(row.keyInquiryQuestions)),
                      _buildCell(_formatBullets(row.learningExperiences)),
                      _buildCell(_formatBullets(row.learningResources)),
                      _buildCell(_formatBullets(row.assessmentMethods)),
                      _buildCell(row.reflections),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeaderCell(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 5),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 7.5,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _buildCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    bool bold = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(
        text.isEmpty ? '-' : text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 7,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static String _formatBullets(List<String> list) {
    if (list.isEmpty) return '-';
    if (list.length == 1) return list.first;
    return list.map((item) => '• $item').join('\n');
  }

  /// Print or open Native PDF Preview
  static Future<void> printScheme(Scheme scheme) async {
    final pdfBytes = await generateSchemePdf(scheme);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: '${scheme.subjectName ?? "Scheme"}_${scheme.termName}_${scheme.year}.pdf',
    );
  }

  /// Share PDF file
  static Future<void> shareSchemePdf(Scheme scheme) async {
    final pdfBytes = await generateSchemePdf(scheme);
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: '${scheme.subjectName ?? "Scheme"}_${scheme.termName}_${scheme.year}.pdf',
    );
  }
}
