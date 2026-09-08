import 'package:flutter/material.dart';
import '../../core/config/theme.dart';

class ClaimAccountBanner extends StatelessWidget {
  final VoidCallback onClaimPressed;
  final String title;
  final String message;

  const ClaimAccountBanner({
    super.key,
    required this.onClaimPressed,
    this.title = 'Save your schemes permanently',
    this.message = 'You are currently in Guest Mode. Sign in or create an account with your email and password to sync and access your schemes from any device.',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB), // Amber warm light
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.accentGold.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_upload_outlined,
                  color: AppTheme.accentGold,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF78350F),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: onClaimPressed,
              icon: const Icon(Icons.login_rounded, size: 16),
              label: const Text('Save to my account'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentGold,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
