import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/config/theme.dart';
import '../../../state/auth_provider.dart';

class AuthModal extends StatelessWidget {
  final String title;
  final String message;

  const AuthModal({
    super.key,
    this.title = 'Save your schemes permanently',
    this.message = 'Sign in with Google to sync your schemes across devices, keep an organized teaching record, and re-download anytime for free.',
  });

  static void show(BuildContext context, {String? title, String? message}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AuthModal(
        title: title ?? 'Save your schemes permanently',
        message: message ?? 'Sign in with Google to sync your schemes across devices, keep an organized teaching record, and re-download anytime for free.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryEmerald.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.school_rounded,
              color: AppTheme.primaryEmerald,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 10),

          // Description
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              color: AppTheme.textMuted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),

          // Features List
          _buildFeatureRow(Icons.cloud_done_outlined, 'Automatic cloud backup to Supabase'),
          const SizedBox(height: 8),
          _buildFeatureRow(Icons.devices_outlined, 'Access & edit on mobile, tablet, or web'),
          const SizedBox(height: 8),
          _buildFeatureRow(Icons.history_edu_outlined, 'Organized term-by-term scheme history'),
          const SizedBox(height: 24),

          // Google Sign-In Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: authProvider.isLoading
                  ? null
                  : () async {
                      final success = await context.read<AuthProvider>().signInWithGoogle();
                      if (context.mounted && success) {
                        Navigator.pop(context);
                      }
                    },
              icon: authProvider.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.g_mobiledata_rounded, size: 28, color: Colors.red),
              label: Text(
                authProvider.isLoading ? 'Connecting...' : 'Continue with Google',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Continue as guest
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Continue as Guest (No account needed)',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryEmerald),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: AppTheme.textDark, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
