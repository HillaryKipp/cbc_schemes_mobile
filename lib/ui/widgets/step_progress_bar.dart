import 'package:flutter/material.dart';
import '../../core/config/theme.dart';

class StepProgressBar extends StatelessWidget {
  final int currentStep; // 1, 2, or 3

  const StepProgressBar({
    super.key,
    required this.currentStep,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStep(1, 'School Details'),
          _buildDivider(isPassed: currentStep > 1),
          _buildStep(2, 'Calendar'),
          _buildDivider(isPassed: currentStep > 2),
          _buildStep(3, 'Generate'),
        ],
      ),
    );
  }

  Widget _buildStep(int stepIndex, String title) {
    final isCompleted = currentStep > stepIndex;
    final isActive = currentStep == stepIndex;

    Color circleBg;
    Color textColor;
    Widget centerWidget;

    if (isCompleted) {
      circleBg = AppTheme.primaryGreen;
      textColor = AppTheme.primaryGreen;
      centerWidget = const Icon(Icons.check, color: Colors.white, size: 16);
    } else if (isActive) {
      circleBg = AppTheme.primaryGreen;
      textColor = AppTheme.primaryGreen;
      centerWidget = Text(
        '$stepIndex',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
      );
    } else {
      circleBg = const Color(0xFFE5E7EB);
      textColor = AppTheme.textMuted;
      centerWidget = Text(
        '$stepIndex',
        style: const TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.bold, fontSize: 13),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: circleBg,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: centerWidget,
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: (isActive || isCompleted) ? FontWeight.w700 : FontWeight.w500,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider({required bool isPassed}) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 20, left: 6, right: 6),
        color: isPassed ? AppTheme.primaryGreen : const Color(0xFFE5E7EB),
      ),
    );
  }
}
