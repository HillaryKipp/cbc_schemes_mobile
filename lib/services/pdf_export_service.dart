import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/scheme.dart';
import '../models/scheme_row.dart';

class PdfExportService {
  // Soft green header fill matching web #E6F1EA
  static const PdfColor headerFillColor = PdfColor.fromInt(0xFFE6F1EA);
  static const PdfColor textDark = PdfColor.fromInt(0xFF141414);
  static const PdfColor borderColor = PdfColor.fromInt(0xFFBEBEBE);
  static const PdfColor innerBorderColor = PdfColor.fromInt(0xFFD1D5DB);

  /// Generate printable 10-column landscape PDF bytes matching web jspdf-autotable specification
  static Future<Uint8List> generateSchemePdf(Scheme scheme) async {
    final pdf = pw.Document();

    final fontRegular = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();
    final fontItalic = await PdfGoogleFonts.openSansItalic();

    final theme = pw.ThemeData.withFont(
      base: fontRegular,
      bold: fontBold,
      italic: fontItalic,
    );

    final sortedRows = List.from(scheme.rows)..sort((a, b) => a.position.compareTo(b.position));

    // -------------------------------------------------------------
    // 1. COVER PAGE (Centered vertically, Landscape A4)
    // -------------------------------------------------------------
    pdf.addPage(
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(36), // 0.5 in
        build: (pw.Context context) {
          final schoolStr = scheme.schoolName?.trim().isNotEmpty == true ? scheme.schoolName! : '____________________________________';
          final teacherStr = scheme.teacherName?.trim().isNotEmpty == true ? scheme.teacherName! : '____________________________________';
          final tscStr = scheme.tscNumber?.trim().isNotEmpty == true ? scheme.tscNumber! : '____________________';
          final hodStr = scheme.hodName?.trim().isNotEmpty == true ? scheme.hodName! : '____________________________________';

          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'SCHEMES OF WORK',
                  style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: textDark),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  (scheme.subjectName ?? 'LEARNING AREA').toUpperCase(),
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: textDark),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  '${scheme.gradeName ?? "Grade"} — ${scheme.year} — ${scheme.termName}',
                  style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 36),

                // Centered Details Box
                pw.Container(
                  width: 380,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: borderColor, width: 0.5),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      _buildCoverField('School:', schoolStr),
                      pw.SizedBox(height: 8),
                      _buildCoverField('Teacher:', teacherStr),
                      pw.SizedBox(height: 8),
                      _buildCoverField('TSC Number:', tscStr),
                      if (scheme.referenceBookTitle != null && scheme.referenceBookTitle!.trim().isNotEmpty) ...[
                        pw.SizedBox(height: 8),
                        _buildCoverField('Reference book:', scheme.referenceBookTitle!),
                      ],
                      pw.SizedBox(height: 14),
                      _buildCoverField('H.O.D:', hodStr),
                      pw.SizedBox(height: 8),
                      _buildCoverField('Signature: ____________________', 'Date: ____________'),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    // -------------------------------------------------------------
    // 2. SCHEME TABLE MULTI-PAGE (Landscape A4, 10 columns)
    // -------------------------------------------------------------
    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(26, 24, 26, 24),
        header: (pw.Context context) {
          final tableHeader = '${scheme.subjectName ?? "Subject"} — ${scheme.gradeName ?? "Grade"} — ${scheme.termName} ${scheme.year}';
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  tableHeader,
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: textDark),
                ),
                pw.Text(
                  'CBC Schemes of Work',
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 6),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('CBC Competency Based Curriculum', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600)),
                pw.Text('Page ${context.pageNumber}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            pw.Table(
              border: pw.TableBorder.all(color: borderColor, width: 0.5),
              columnWidths: const {
                0: pw.FixedColumnWidth(26), // Week (cellWidth: 26)
                1: pw.FixedColumnWidth(26), // Lesson (cellWidth: 26)
                2: pw.FlexColumnWidth(1.1), // Strand
                3: pw.FlexColumnWidth(1.2), // Sub-strand
                4: pw.FixedColumnWidth(155), // Outcomes (cellWidth: 155)
                5: pw.FlexColumnWidth(1.5), // Questions
                6: pw.FixedColumnWidth(140), // Experiences (cellWidth: 140)
                7: pw.FlexColumnWidth(1.3), // Resources
                8: pw.FlexColumnWidth(1.1), // Assessments
                9: pw.FlexColumnWidth(1.0), // Reflection
              },
              children: [
                // Header Row (#E6F1EA Soft Green fill, textColor [20, 20, 20], fontSize: 7)
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: headerFillColor),
                  children: [
                    _buildHeaderCell('Wk', align: pw.TextAlign.center),
                    _buildHeaderCell('Lsn', align: pw.TextAlign.center),
                    _buildHeaderCell('Strand'),
                    _buildHeaderCell('Sub-strand'),
                    _buildHeaderCell('Specific Learning Outcomes'),
                    _buildHeaderCell('Key Inquiry Question(s)'),
                    _buildHeaderCell('Learning Experiences'),
                    _buildHeaderCell('Learning Resources'),
                    _buildHeaderCell('Assessment Methods'),
                    _buildHeaderCell('Reflection'),
                  ],
                ),
                // Table Data Rows
                ...sortedRows.map((row) {
                  if (row.isMilestone) {
                    return pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF3F4F6)),
                      children: [
                        _buildDataCell('${row.weekNumber}', align: pw.TextAlign.center, bold: true),
                        _buildDataCell('—', align: pw.TextAlign.center, bold: true),
                        _buildDataCell(row.milestoneBannerText, bold: true),
                        _buildDataCell(row.reflections.isNotEmpty ? row.reflections : (row.milestoneType == MilestoneType.halfTerm ? 'MID-TERM BREAK' : 'ASSESSMENT')),
                        _buildDataCell('—', align: pw.TextAlign.center),
                        _buildDataCell('—', align: pw.TextAlign.center),
                        _buildDataCell('—', align: pw.TextAlign.center),
                        _buildDataCell('—', align: pw.TextAlign.center),
                        _buildDataCell('—', align: pw.TextAlign.center),
                        _buildDataCell(row.reflections),
                      ],
                    );
                  }

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: (row.position % 2 == 1) ? const PdfColor.fromInt(0xFFFAFAFA) : PdfColors.white,
                    ),
                    children: [
                      _buildDataCell('${row.weekNumber}', align: pw.TextAlign.center, bold: true),
                      _buildDataCell('${row.lessonNumber}', align: pw.TextAlign.center, bold: true),
                      _buildDataCell(row.strandName, bold: true),
                      _buildDataCell(row.subStrandName),
                      _buildOutcomesCell(row.learningOutcomes),
                      _buildListCell(row.keyInquiryQuestions),
                      _buildListCell(row.learningExperiences),
                      _buildListCell(row.learningResources),
                      _buildListCell(row.assessmentMethods),
                      _buildDataCell(row.reflections),
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

  static pw.Widget _buildCoverField(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        pw.Text(
          '$label ',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: textDark),
        ),
        pw.Text(
          value,
          style: const pw.TextStyle(fontSize: 10, color: textDark),
        ),
      ],
    );
  }

  static pw.Widget _buildHeaderCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 2.5, vertical: 3.5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          color: textDark,
          fontSize: 7,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _buildDataCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    bool bold = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 2.5, vertical: 2.5),
      child: pw.Text(
        text.trim().isEmpty ? '-' : text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 6.5,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: textDark,
        ),
      ),
    );
  }

  static pw.Widget _buildOutcomesCell(List<String> outcomes) {
    if (outcomes.isEmpty) return _buildDataCell('-');

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 2.5, vertical: 2.5),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: outcomes.map((item) {
          final isLeadIn = item.toLowerCase().contains('by the end of');
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 1.5),
            child: pw.Text(
              item,
              style: pw.TextStyle(
                fontSize: 6.5,
                fontStyle: isLeadIn ? pw.FontStyle.italic : pw.FontStyle.normal,
                color: textDark,
                lineSpacing: 1.1,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  static pw.Widget _buildListCell(List<String> items) {
    if (items.isEmpty) return _buildDataCell('-');

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 2.5, vertical: 2.5),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: items.map((item) {
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 1.5),
            child: pw.Text(
              item,
              style: const pw.TextStyle(fontSize: 6.5, color: textDark, lineSpacing: 1.1),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Print or open Native PDF Preview (AirPrint / Mopria)
  static Future<void> printScheme(Scheme scheme) async {
    final pdfBytes = await generateSchemePdf(scheme);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: '${scheme.subjectName ?? "Scheme"}_${scheme.termName}_${scheme.year}.pdf',
    );
  }

  /// Native Share PDF file (WhatsApp, Gmail, Telegram)
  static Future<void> shareSchemePdf(Scheme scheme) async {
    final pdfBytes = await generateSchemePdf(scheme);
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: '${scheme.subjectName ?? "Scheme"}_${scheme.termName}_${scheme.year}.pdf',
    );
  }
}
