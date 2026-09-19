import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/app_config.dart';

class WhatsAppSupportButton extends StatelessWidget {
  final String? customInitialText;
  final bool mini;
  final Object? heroTag;

  const WhatsAppSupportButton({
    super.key,
    this.customInitialText,
    this.mini = false,
    this.heroTag,
  });

  static Future<void> openWhatsApp(BuildContext context, [String? initialText]) async {
    final message = Uri.encodeComponent(
      initialText ?? 'Hello CBC Schemes Support! I have an inquiry / feedback.',
    );
    final uri = Uri.parse('https://wa.me/${AppConfig.whatsappSupportNumber}?text=$message');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open WhatsApp. Please message ${AppConfig.supportPhone} directly.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showSupportBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Color(0xFF25D366), shape: BoxShape.circle),
                    child: const Icon(Icons.chat, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CBC Schemes Support', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Online · Direct assistance via ${AppConfig.supportPhone}', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('How can we help you today?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.menu_book, color: Color(0xFF0B6D3B)),
                title: const Text('Request a missing grade or scheme', style: TextStyle(fontSize: 14)),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () {
                  Navigator.pop(ctx);
                  openWhatsApp(context, 'Hello, I would like to request schemes of work for a grade/subject that is not listed.');
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.payment, color: Color(0xFF0B6D3B)),
                title: const Text('Payment or download inquiry', style: TextStyle(fontSize: 14)),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () {
                  Navigator.pop(ctx);
                  openWhatsApp(context, 'Hi! I have an inquiry about downloading schemes and M-Pesa payment.');
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.feedback_outlined, color: Color(0xFF0B6D3B)),
                title: const Text('Share general feedback or suggestion', style: TextStyle(fontSize: 14)),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () {
                  Navigator.pop(ctx);
                  openWhatsApp(context, 'Hello, I have feedback regarding the CBC Schemes of Work app.');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: heroTag,
      mini: mini,
      backgroundColor: const Color(0xFF25D366),
      foregroundColor: Colors.white,
      elevation: 4,
      onPressed: () {
        if (customInitialText != null) {
          openWhatsApp(context, customInitialText);
        } else {
          _showSupportBottomSheet(context);
        }
      },
      child: const Icon(Icons.chat),
    );
  }
}
