import 'package:flutter/material.dart';
import '../../core/config/theme.dart';

class StatBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final Color? textColor;
  final bool isPill;

  const StatBadge({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.textColor,
    this.isPill = true,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? AppTheme.primaryGreenLight;
    final fg = textColor ?? AppTheme.primaryGreen;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(isPill ? 20 : 6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
