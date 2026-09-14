import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/scheme.dart';
import 'docx_export_service.dart';
import 'pdf_export_service.dart';

class SchemeShareService {
  /// Build share summary text for the scheme
  static String buildSchemeSummary(Scheme scheme) {
    final grade = scheme.gradeName ?? 'CBC Grade';
    final subject = scheme.subjectName ?? 'Subject';
    final term = scheme.termName;
    final year = scheme.year;
    final lessons = scheme.rows.length;
    final weeks = (lessons / 5).ceil();

    return '📚 *CBC Scheme of Work*\n'
        '• *Grade:* $grade\n'
        '• *Subject:* $subject\n'
        '• *Term & Year:* $term $year\n'
        '• *Coverage:* $weeks Weeks ($lessons Lessons)\n'
        '• *Format:* KICD 10-Column Standard Compliant\n\n'
        'Generated via CBC Schemes of Work App.';
  }

  /// Share scheme PDF directly via Native Share Sheet (Social Media, Telegram, Drive, Bluetooth, etc.)
  static Future<void> shareViaSocialMedia(BuildContext context, Scheme scheme, {String format = 'pdf'}) async {
    try {
      if (format == 'docx') {
        final docxFile = await DocxExportService.generateDocx(scheme);
        await Share.shareXFiles(
          [XFile(docxFile.path)],
          text: buildSchemeSummary(scheme),
          subject: 'CBC Scheme of Work - ${scheme.gradeName} ${scheme.subjectName} (${scheme.termName})',
        );
      } else {
        final pdfBytes = await PdfExportService.generateSchemePdf(scheme);
        final tempDir = Directory.systemTemp;
        final fileName = '${scheme.gradeName ?? "Grade"}_${scheme.subjectName ?? "Scheme"}_${scheme.termName}_${scheme.year}.pdf'
            .replaceAll(RegExp(r'[^\w\.-]'), '_');
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(pdfBytes);

        await Share.shareXFiles(
          [XFile(file.path)],
          text: buildSchemeSummary(scheme),
          subject: 'CBC Scheme of Work - ${scheme.gradeName} ${scheme.subjectName} (${scheme.termName})',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing scheme: $e')),
        );
      }
    }
  }

  /// Share directly to WhatsApp with prefilled message and attachment
  static Future<void> shareViaWhatsApp(BuildContext context, Scheme scheme) async {
    try {
      final summary = buildSchemeSummary(scheme);
      
      // Generate the PDF file to share
      final pdfBytes = await PdfExportService.generateSchemePdf(scheme);
      final tempDir = Directory.systemTemp;
      final fileName = '${scheme.gradeName ?? "Grade"}_${scheme.subjectName ?? "Scheme"}_${scheme.termName}_${scheme.year}.pdf'
          .replaceAll(RegExp(r'[^\w\.-]'), '_');
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: summary,
        subject: 'CBC Scheme of Work: ${scheme.gradeName} ${scheme.subjectName}',
      );
    } catch (e) {
      // Fallback to WhatsApp URL intent
      try {
        final encoded = Uri.encodeComponent(buildSchemeSummary(scheme));
        final waUrl = Uri.parse('whatsapp://send?text=$encoded');
        if (await canLaunchUrl(waUrl)) {
          await launchUrl(waUrl, mode: LaunchMode.externalApplication);
        } else {
          final webWaUrl = Uri.parse('https://api.whatsapp.com/send?text=$encoded');
          await launchUrl(webWaUrl, mode: LaunchMode.externalApplication);
        }
      } catch (err) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open WhatsApp: $err')),
          );
        }
      }
    }
  }

  /// Share scheme via Email client with attachment
  static Future<void> shareViaEmail(BuildContext context, Scheme scheme) async {
    try {
      final subject = 'CBC Scheme of Work: ${scheme.gradeName ?? "Grade"} ${scheme.subjectName ?? "Subject"} - ${scheme.termName} ${scheme.year}';
      final body = buildSchemeSummary(scheme);

      final pdfBytes = await PdfExportService.generateSchemePdf(scheme);
      final tempDir = Directory.systemTemp;
      final fileName = '${scheme.gradeName ?? "Grade"}_${scheme.subjectName ?? "Scheme"}_${scheme.termName}_${scheme.year}.pdf'
          .replaceAll(RegExp(r'[^\w\.-]'), '_');
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: subject,
        text: body,
      );
    } catch (e) {
      try {
        final emailUri = Uri(
          scheme: 'mailto',
          queryParameters: {
            'subject': 'CBC Scheme of Work - ${scheme.gradeName} ${scheme.subjectName}',
            'body': buildSchemeSummary(scheme),
          },
        );
        if (await canLaunchUrl(emailUri)) {
          await launchUrl(emailUri);
        }
      } catch (err) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error preparing email: $err')),
          );
        }
      }
    }
  }

  /// Show standard share options modal bottom sheet
  static void showShareBottomSheet(BuildContext context, {required Scheme scheme, bool isPaid = false}) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.share_rounded, color: Color(0xFF16A34A), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Share ${scheme.gradeName ?? "CBC"} Scheme',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        Text(
                          '${scheme.subjectName ?? "Subject"} • ${scheme.termName} ${scheme.year}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.chat_bubble_outline, color: Color(0xFF25D366)),
                ),
                title: const Text('Share to WhatsApp', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Send formatted scheme & document directly', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  shareViaWhatsApp(context, scheme);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.email_outlined, color: Colors.blue),
                ),
                title: const Text('Send via Email', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Email PDF document with overview', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  shareViaEmail(context, scheme);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.share_outlined, color: Colors.purple),
                ),
                title: const Text('Other Apps & Devices', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Drive, Telegram, AirDrop, Bluetooth, etc.', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  shareViaSocialMedia(context, scheme, format: 'pdf');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
