import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/scheme.dart';

class DocxExportService {
  // Exact 10-column widths in dxa (Total: 14,900 dxa)
  // [Wk: 550, Lsn: 550, Strand: 1300, Sub-strand: 1600, Outcomes: 3000, Questions: 1700, Experiences: 2800, Resources: 1600, Assessments: 1100, Reflections: 1100]
  static const List<int> columnWidths = [
    550,
    550,
    1300,
    1600,
    3000,
    1700,
    2800,
    1600,
    1100,
    1100,
  ];

  /// Generate a .docx file for the scheme of work matching web docx specification
  static Future<File> generateDocx(Scheme scheme) async {
    final archive = Archive();

    // 1. [Content_Types].xml
    const contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>''';
    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypesXml.length, utf8.encode(contentTypesXml)));

    // 2. _rels/.rels
    const relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';
    archive.addFile(ArchiveFile('_rels/.rels', relsXml.length, utf8.encode(relsXml)));

    // 3. word/_rels/document.xml.rels
    const docRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rIdStyles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''';
    archive.addFile(ArchiveFile('word/_rels/document.xml.rels', docRelsXml.length, utf8.encode(docRelsXml)));

    // 4. word/styles.xml (Default Font: Arial, 10pt / 20 half-points)
    const stylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault>
      <w:rPr>
        <w:rFonts w:ascii="Arial" w:hAnsi="Arial" w:cs="Arial"/>
        <w:sz w:val="20"/>
        <w:szCs w:val="20"/>
      </w:rPr>
    </w:rPrDefault>
  </w:docDefaults>
</w:styles>''';
    archive.addFile(ArchiveFile('word/styles.xml', stylesXml.length, utf8.encode(stylesXml)));

    // 5. word/document.xml
    final docXmlBuffer = StringBuffer();
    docXmlBuffer.write('''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
''');

    // --- COVER PAGE ---
    // Spacer
    docXmlBuffer.write(_buildSpacer(4));

    // Title: SCHEMES OF WORK (Bold, 28pt / size 56)
    docXmlBuffer.write('''
    <w:p>
      <w:pPr><w:jc w:val="center"/><w:spacing w:after="160"/></w:pPr>
      <w:r>
        <w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial"/><w:b/><w:sz w:val="56"/><w:szCs w:val="56"/><w:color w:val="141414"/></w:rPr>
        <w:t>SCHEMES OF WORK</w:t>
      </w:r>
    </w:p>
''');

    // Subject Name: Uppercase (Bold, 20pt / size 40)
    final subjectTitle = (scheme.subjectName ?? 'CURRICULUM LEARNING AREA').toUpperCase();
    docXmlBuffer.write('''
    <w:p>
      <w:pPr><w:jc w:val="center"/><w:spacing w:after="120"/></w:pPr>
      <w:r>
        <w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial"/><w:b/><w:sz w:val="40"/><w:szCs w:val="40"/><w:color w:val="141414"/></w:rPr>
        <w:t>${_escapeXml(subjectTitle)}</w:t>
      </w:r>
    </w:p>
''');

    // Grade & Term: "[Grade] — [Year] — [Term]" (16pt / size 32)
    final gradeAndTerm = '${scheme.gradeName ?? "Grade"} — ${scheme.year} — ${scheme.termName}';
    docXmlBuffer.write('''
    <w:p>
      <w:pPr><w:jc w:val="center"/><w:spacing w:after="400"/></w:pPr>
      <w:r>
        <w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial"/><w:sz w:val="32"/><w:szCs w:val="32"/><w:color w:val="4A5568"/></w:rPr>
        <w:t>${_escapeXml(gradeAndTerm)}</w:t>
      </w:r>
    </w:p>
''');

    // Details Block (Centered, 13pt / size 26):
    final schoolStr = scheme.schoolName?.trim().isNotEmpty == true ? scheme.schoolName! : '____________________________________';
    final teacherStr = scheme.teacherName?.trim().isNotEmpty == true ? scheme.teacherName! : '____________________________________';
    final tscStr = scheme.tscNumber?.trim().isNotEmpty == true ? scheme.tscNumber! : '____________________';
    final hodStr = scheme.hodName?.trim().isNotEmpty == true ? scheme.hodName! : '____________________________________';

    docXmlBuffer.write(_buildCoverDetailLine('School:', schoolStr));
    docXmlBuffer.write(_buildCoverDetailLine('Teacher:', teacherStr));
    docXmlBuffer.write(_buildCoverDetailLine('TSC Number:', tscStr));
    if (scheme.referenceBookTitle != null && scheme.referenceBookTitle!.trim().isNotEmpty) {
      docXmlBuffer.write(_buildCoverDetailLine('Reference book:', scheme.referenceBookTitle!));
    }

    docXmlBuffer.write(_buildSpacer(1));
    docXmlBuffer.write(_buildCoverDetailLine('H.O.D:', hodStr));
    docXmlBuffer.write(_buildCoverDetailLine('Signature: ____________________', 'Date: ____________'));

    // Page Break
    docXmlBuffer.write('''
    <w:p>
      <w:r>
        <w:br w:type="page"/>
      </w:r>
    </w:p>
''');

    // --- TABLE PAGE(S) ---
    // Header Line: "[Subject] — [Grade] — [Term] [Year]" (Bold, 13pt / size 26)
    final tableHeaderLine = '${scheme.subjectName ?? "Subject"} — ${scheme.gradeName ?? "Grade"} — ${scheme.termName} ${scheme.year}';
    docXmlBuffer.write('''
    <w:p>
      <w:pPr><w:spacing w:after="140"/></w:pPr>
      <w:r>
        <w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial"/><w:b/><w:sz w:val="26"/><w:szCs w:val="26"/><w:color w:val="141414"/></w:rPr>
        <w:t>${_escapeXml(tableHeaderLine)}</w:t>
      </w:r>
    </w:p>
''');

    // 10-Column Table
    docXmlBuffer.write('''
    <w:tbl>
      <w:tblPr>
        <w:tblW w:w="14900" w:type="dxa"/>
        <w:tblBorders>
          <w:top w:val="single" w:sz="4" w:space="0" w:color="BEBEBE"/>
          <w:left w:val="single" w:sz="4" w:space="0" w:color="BEBEBE"/>
          <w:bottom w:val="single" w:sz="4" w:space="0" w:color="BEBEBE"/>
          <w:right w:val="single" w:sz="4" w:space="0" w:color="BEBEBE"/>
          <w:insideH w:val="single" w:sz="4" w:space="0" w:color="D1D5DB"/>
          <w:insideV w:val="single" w:sz="4" w:space="0" w:color="D1D5DB"/>
        </w:tblBorders>
      </w:tblPr>
      <w:tblGrid>
''');
    for (final width in columnWidths) {
      docXmlBuffer.write('        <w:gridCol w:w="$width"/>\n');
    }
    docXmlBuffer.write('''      </w:tblGrid>
      <!-- Header Row with #E6F1EA fill color and dark #141414 text -->
      <w:tr>
        <w:trPr><w:tblHeader/></w:trPr>
        ${_buildDocxHeaderCell("Wk", columnWidths[0])}
        ${_buildDocxHeaderCell("Lsn", columnWidths[1])}
        ${_buildDocxHeaderCell("Strand", columnWidths[2])}
        ${_buildDocxHeaderCell("Sub-strand", columnWidths[3])}
        ${_buildDocxHeaderCell("Specific Learning Outcomes", columnWidths[4])}
        ${_buildDocxHeaderCell("Key Inquiry Question(s)", columnWidths[5])}
        ${_buildDocxHeaderCell("Learning Experiences", columnWidths[6])}
        ${_buildDocxHeaderCell("Learning Resources", columnWidths[7])}
        ${_buildDocxHeaderCell("Assessment Methods", columnWidths[8])}
        ${_buildDocxHeaderCell("Reflection", columnWidths[9])}
      </w:tr>
''');

    // Data Rows
    final sortedRows = List.from(scheme.rows)..sort((a, b) => a.position.compareTo(b.position));
    for (final row in sortedRows) {
      if (row.isMilestone) {
        docXmlBuffer.write('''
      <w:tr>
        <w:tc>
          <w:tcPr>
            <w:gridSpan w:val="10"/>
            <w:tcW w:w="14900" w:type="dxa"/>
            <w:shd w:val="clear" w:color="auto" w:fill="F3F4F6"/>
            <w:tcMar>
              <w:top w:w="100" w:type="dxa"/>
              <w:bottom w:w="100" w:type="dxa"/>
              <w:left w:w="100" w:type="dxa"/>
              <w:right w:w="100" w:type="dxa"/>
            </w:tcMar>
          </w:tcPr>
          <w:p>
            <w:pPr><w:jc w:val="center"/><w:spacing w:after="0" w:line="240" w:lineRule="auto"/></w:pPr>
            <w:r>
              <w:rPr>
                <w:rFonts w:ascii="Arial" w:hAnsi="Arial"/>
                <w:b/>
                <w:sz w:val="16"/>
                <w:szCs w:val="16"/>
                <w:color w:val="374151"/>
              </w:rPr>
              <w:t>${_escapeXml(row.milestoneBannerText)}</w:t>
            </w:r>
          </w:p>
        </w:tc>
      </w:tr>
''');
        continue;
      }

      docXmlBuffer.write('''
      <w:tr>
        ${_buildDocxCell("${row.weekNumber}", columnWidths[0], align: "center", bold: true)}
        ${_buildDocxCell("${row.lessonNumber}", columnWidths[1], align: "center", bold: true)}
        ${_buildDocxCell(row.strandName, columnWidths[2], bold: true)}
        ${_buildDocxCell(row.subStrandName, columnWidths[3])}
        ${_buildDocxOutcomesCell(row.learningOutcomes, columnWidths[4])}
        ${_buildDocxListCell(row.keyInquiryQuestions, columnWidths[5])}
        ${_buildDocxListCell(row.learningExperiences, columnWidths[6])}
        ${_buildDocxListCell(row.learningResources, columnWidths[7])}
        ${_buildDocxListCell(row.assessmentMethods, columnWidths[8])}
        ${_buildDocxCell(row.reflections, columnWidths[9])}
      </w:tr>
''');
    }

    // Section properties (Landscape A4: 16838 x 11906 dxa, Margins: 720 dxa = 0.5 in)
    docXmlBuffer.write('''
    </w:tbl>
    <w:sectPr>
      <w:pgSz w:w="16838" w:h="11906" w:orient="landscape"/>
      <w:pgMar w:top="720" w:right="720" w:bottom="720" w:left="720" w:header="720" w:footer="720" w:gutter="0"/>
    </w:sectPr>
  </w:body>
</w:document>''');

    archive.addFile(ArchiveFile('word/document.xml', docXmlBuffer.length, utf8.encode(docXmlBuffer.toString())));

    // Compress to .docx zip
    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive);

    final tempDir = await getTemporaryDirectory();
    final fileName = '${scheme.subjectName ?? "Scheme"}_${scheme.termName}_${scheme.year}.docx'
        .replaceAll(RegExp(r'[^\w\.-]'), '_');
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(Uint8List.fromList(zipBytes!));
    return file;
  }

  static String _buildSpacer(int count) {
    final buffer = StringBuffer();
    for (int i = 0; i < count; i++) {
      buffer.write('<w:p><w:pPr><w:spacing w:after="160"/></w:pPr></w:p>\n');
    }
    return buffer.toString();
  }

  static String _buildCoverDetailLine(String label, String value) {
    return '''
    <w:p>
      <w:pPr><w:jc w:val="center"/><w:spacing w:after="100"/></w:pPr>
      <w:r>
        <w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial"/><w:b/><w:sz w:val="26"/><w:szCs w:val="26"/><w:color w:val="141414"/></w:rPr>
        <w:t>${_escapeXml(label)} </w:t>
      </w:r>
      <w:r>
        <w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial"/><w:sz w:val="26"/><w:szCs w:val="26"/><w:color w:val="141414"/></w:rPr>
        <w:t>${_escapeXml(value)}</w:t>
      </w:r>
    </w:p>
''';
  }

  static String _buildDocxHeaderCell(String text, int widthDxa) {
    return '''
    <w:tc>
      <w:tcPr>
        <w:tcW w:w="$widthDxa" w:type="dxa"/>
        <w:shd w:val="clear" w:color="auto" w:fill="E6F1EA"/>
        <w:tcMar>
          <w:top w:w="80" w:type="dxa"/>
          <w:bottom w:w="80" w:type="dxa"/>
          <w:left w:w="80" w:type="dxa"/>
          <w:right w:w="80" w:type="dxa"/>
        </w:tcMar>
      </w:tcPr>
      <w:p>
        <w:pPr><w:jc w:val="center"/><w:spacing w:after="0" w:line="240" w:lineRule="auto"/></w:pPr>
        <w:r>
          <w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial"/><w:b/><w:color w:val="141414"/><w:sz w:val="15"/><w:szCs w:val="15"/></w:rPr>
          <w:t>${_escapeXml(text)}</w:t>
        </w:r>
      </w:p>
    </w:tc>''';
  }

  static String _buildDocxCell(
    String text,
    int widthDxa, {
    String align = "left",
    bool bold = false,
  }) {
    return '''
    <w:tc>
      <w:tcPr>
        <w:tcW w:w="$widthDxa" w:type="dxa"/>
        <w:tcMar>
          <w:top w:w="60" w:type="dxa"/>
          <w:bottom w:w="60" w:type="dxa"/>
          <w:left w:w="70" w:type="dxa"/>
          <w:right w:w="70" w:type="dxa"/>
        </w:tcMar>
      </w:tcPr>
      <w:p>
        <w:pPr><w:jc w:val="$align"/><w:spacing w:after="0" w:line="220" w:lineRule="auto"/></w:pPr>
        <w:r>
          <w:rPr>
            <w:rFonts w:ascii="Arial" w:hAnsi="Arial"/>
            ${bold ? '<w:b/>' : ''}
            <w:sz w:val="14"/>
            <w:szCs w:val="14"/>
            <w:color w:val="141414"/>
          </w:rPr>
          <w:t>${_escapeXml(text)}</w:t>
        </w:r>
      </w:p>
    </w:tc>''';
  }

  /// Specific Learning Outcomes: Italicizes the lead-in line
  static String _buildDocxOutcomesCell(List<String> outcomes, int widthDxa) {
    final buffer = StringBuffer();
    for (final item in outcomes) {
      final isLeadIn = item.toLowerCase().contains("by the end of");
      buffer.write('''
      <w:p>
        <w:pPr><w:spacing w:after="30" w:line="220" w:lineRule="auto"/></w:pPr>
        <w:r>
          <w:rPr>
            <w:rFonts w:ascii="Arial" w:hAnsi="Arial"/>
            ${isLeadIn ? '<w:i/>' : ''}
            <w:sz w:val="14"/>
            <w:szCs w:val="14"/>
            <w:color w:val="141414"/>
          </w:rPr>
          <w:t>${_escapeXml(item)}</w:t>
        </w:r>
      </w:p>''');
    }
    if (outcomes.isEmpty) {
      buffer.write('<w:p><w:r><w:rPr><w:sz w:val="14"/></w:rPr><w:t>-</w:t></w:r></w:p>');
    }
    return '''
    <w:tc>
      <w:tcPr>
        <w:tcW w:w="$widthDxa" w:type="dxa"/>
        <w:tcMar>
          <w:top w:w="60" w:type="dxa"/>
          <w:bottom w:w="60" w:type="dxa"/>
          <w:left w:w="70" w:type="dxa"/>
          <w:right w:w="70" w:type="dxa"/>
        </w:tcMar>
      </w:tcPr>
      $buffer
    </w:tc>''';
  }

  static String _buildDocxListCell(List<String> items, int widthDxa) {
    final buffer = StringBuffer();
    for (final item in items) {
      buffer.write('''
      <w:p>
        <w:pPr><w:spacing w:after="30" w:line="220" w:lineRule="auto"/></w:pPr>
        <w:r>
          <w:rPr>
            <w:rFonts w:ascii="Arial" w:hAnsi="Arial"/>
            <w:sz w:val="14"/>
            <w:szCs w:val="14"/>
            <w:color w:val="141414"/>
          </w:rPr>
          <w:t>${_escapeXml(item)}</w:t>
        </w:r>
      </w:p>''');
    }
    if (items.isEmpty) {
      buffer.write('<w:p><w:r><w:rPr><w:sz w:val="14"/></w:rPr><w:t>-</w:t></w:r></w:p>');
    }
    return '''
    <w:tc>
      <w:tcPr>
        <w:tcW w:w="$widthDxa" w:type="dxa"/>
        <w:tcMar>
          <w:top w:w="60" w:type="dxa"/>
          <w:bottom w:w="60" w:type="dxa"/>
          <w:left w:w="70" w:type="dxa"/>
          <w:right w:w="70" w:type="dxa"/>
        </w:tcMar>
      </w:tcPr>
      $buffer
    </w:tc>''';
  }

  static String _escapeXml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  /// Share generated Word file
  static Future<void> shareDocx(Scheme scheme) async {
    final file = await generateDocx(scheme);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'CBC Scheme of Work: ${scheme.subjectName ?? "Subject"} - ${scheme.termName} ${scheme.year}',
    );
  }
}
