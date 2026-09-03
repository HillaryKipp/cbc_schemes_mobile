import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/scheme.dart';

class DocxExportService {
  /// Generate a .docx file for the scheme of work
  static Future<File> generateDocx(Scheme scheme) async {
    final archive = Archive();

    // 1. [Content_Types].xml
    const contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';
    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypesXml.length, utf8.encode(contentTypesXml)));

    // 2. _rels/.rels
    const relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';
    archive.addFile(ArchiveFile('_rels/.rels', relsXml.length, utf8.encode(relsXml)));

    // 3. word/document.xml (Landscape A4 Table with 10 columns)
    final docXmlBuffer = StringBuffer();
    docXmlBuffer.write('''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p>
      <w:pPr><w:jc w:val="center"/></w:pPr>
      <w:r><w:rPr><w:b/><w:sz w:val="28"/></w:rPr><w:t>${_escapeXml(scheme.schoolName ?? "KENYA COMPETENCY BASED CURRICULUM (CBC)")}</w:t></w:r>
    </w:p>
    <w:p>
      <w:pPr><w:jc w:val="center"/></w:pPr>
      <w:r><w:rPr><w:b/><w:color w:val="0F766E"/><w:sz w:val="24"/></w:rPr><w:t>SCHEMES OF WORK - ${_escapeXml(scheme.termName.toUpperCase())}, ${scheme.year}</w:t></w:r>
    </w:p>
    <w:p>
      <w:r><w:rPr><w:b/></w:rPr><w:t>GRADE: ${_escapeXml(scheme.gradeName ?? "Grade")}   |   LEARNING AREA: ${_escapeXml(scheme.subjectName ?? "Subject")}   |   TEACHER: ${_escapeXml(scheme.teacherName ?? "________________")}   |   TSC NO: ${_escapeXml(scheme.tscNumber ?? "________")}</w:t></w:r>
    </w:p>
    <w:p>
      <w:r><w:rPr><w:i/></w:rPr><w:t>COURSE BOOK: ${_escapeXml(scheme.referenceBookTitle ?? "Approved CBC Books")}   |   H.O.D: ${_escapeXml(scheme.hodName ?? "________________")}</w:t></w:r>
    </w:p>
    <w:tbl>
      <w:tblPr>
        <w:tblW w:w="0" w:type="auto"/>
        <w:tblBorders>
          <w:top w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
          <w:left w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
          <w:bottom w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
          <w:right w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
          <w:insideH w:val="single" w:sz="4" w:space="0" w:color="E2E8F0"/>
          <w:insideV w:val="single" w:sz="4" w:space="0" w:color="E2E8F0"/>
        </w:tblBorders>
      </w:tblPr>
      <!-- Header Row -->
      <w:tr>
        <w:trPr><w:tblHeader/></w:trPr>
        ${_buildDocxHeaderCell("Wk", "0F766E")}
        ${_buildDocxHeaderCell("Lsn", "0F766E")}
        ${_buildDocxHeaderCell("Strand", "0F766E")}
        ${_buildDocxHeaderCell("Sub-Strand", "0F766E")}
        ${_buildDocxHeaderCell("Specific Learning Outcomes", "0F766E")}
        ${_buildDocxHeaderCell("Key Inquiry Questions", "0F766E")}
        ${_buildDocxHeaderCell("Learning Experiences", "0F766E")}
        ${_buildDocxHeaderCell("Learning Resources", "0F766E")}
        ${_buildDocxHeaderCell("Assessment Methods", "0F766E")}
        ${_buildDocxHeaderCell("Reflections", "0F766E")}
      </w:tr>
''');

    final sortedRows = List.from(scheme.rows)..sort((a, b) => a.position.compareTo(b.position));
    for (final row in sortedRows) {
      docXmlBuffer.write('''
      <w:tr>
        ${_buildDocxCell("${row.weekNumber}", bold: true)}
        ${_buildDocxCell("${row.lessonNumber}", bold: true)}
        ${_buildDocxCell(row.strandName, bold: true)}
        ${_buildDocxCell(row.subStrandName)}
        ${_buildDocxCell(row.learningOutcomes.join("\n• "))}
        ${_buildDocxCell(row.keyInquiryQuestions.join("\n• "))}
        ${_buildDocxCell(row.learningExperiences.join("\n• "))}
        ${_buildDocxCell(row.learningResources.join("\n• "))}
        ${_buildDocxCell(row.assessmentMethods.join("\n• "))}
        ${_buildDocxCell(row.reflections)}
      </w:tr>
''');
    }

    // Section properties (Landscape A4)
    docXmlBuffer.write('''
    </w:tbl>
    <w:sectPr>
      <w:pgSz w:w="16838" w:h="11906" w:orient="landscape"/>
      <w:pgMar w:top="720" w:right="720" w:bottom="720" w:left="720" w:header="720" w:footer="720" w:gutter="0"/>
    </w:sectPr>
  </w:body>
</w:document>''');

    archive.addFile(ArchiveFile('word/document.xml', docXmlBuffer.length, utf8.encode(docXmlBuffer.toString())));

    // Compress to .docx zip bytes
    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive);

    final tempDir = await getTemporaryDirectory();
    final fileName = '${scheme.subjectName ?? "Scheme"}_${scheme.termName}_${scheme.year}.docx'.replaceAll(RegExp(r'[^\w\.-]'), '_');
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(Uint8List.fromList(zipBytes!));
    return file;
  }

  static String _buildDocxHeaderCell(String text, String colorHex) {
    return '''
    <w:tc>
      <w:tcPr>
        <w:shd w:val="clear" w:color="auto" w:fill="$colorHex"/>
      </w:tcPr>
      <w:p>
        <w:r>
          <w:rPr><w:b/><w:color w:val="FFFFFF"/><w:sz w:val="18"/></w:rPr>
          <w:t>${_escapeXml(text)}</w:t>
        </w:r>
      </w:p>
    </w:tc>''';
  }

  static String _buildDocxCell(String text, {bool bold = false}) {
    final lines = text.split('\n');
    final paragraphs = lines.map((l) => '''
      <w:p>
        <w:r>
          <w:rPr>${bold ? '<w:b/>' : ''}<w:sz w:val="16"/></w:rPr>
          <w:t>${_escapeXml(l)}</w:t>
        </w:r>
      </w:p>''').join('');

    return '''
    <w:tc>
      $paragraphs
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
