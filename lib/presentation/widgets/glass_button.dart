import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class GlassButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? width;
  final double? height;
  final Gradient? gradient;
  /// When set (0.0–1.0), the button renders as a progress bar instead of a spinner.
  final double? progress;

  const GlassButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.width,
    this.height,
    this.gradient,
    this.progress,
  });

  String _progressLabel(double p) {
    if (p < 0.4) return 'Analysing preferences...';
    if (p < 0.7) return 'Crafting your meal plan...';
    if (p < 0.9) return 'Almost there...';
    return 'Finishing up...';
  }

  @override
  Widget build(BuildContext context) {
    final isProgress = progress != null;
    // On primary/solid backgrounds white always works; on light gradients use dark text.
    final textColor =
        AppColors.current.isDark ? Colors.white : AppColors.glassText;

    return Container(
      width: width ?? double.infinity,
      height: height ?? 50,
      decoration: BoxDecoration(
        color: gradient != null ? null : AppColors.primary,
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isProgress
          ? _ProgressFill(
              progress: progress!,
              gradient: gradient,
              label: _progressLabel(progress!),
              textColor: textColor,
            )
          : ElevatedButton(
              onPressed: isLoading ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: textColor,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      text,
                      style: AppTextStyles.labelLarge.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
            ),
    );
  }
}

class _ProgressFill extends StatelessWidget {
  final double progress;
  final Gradient? gradient;
  final String label;
  final Color textColor;

  const _ProgressFill({
    required this.progress,
    required this.gradient,
    required this.label,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).clamp(0, 100).toInt();
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          // Dimmed base
          Positioned.fill(
            child: Opacity(
              opacity: 0.45,
              child: Container(
                decoration: BoxDecoration(
                  gradient: gradient,
                  color: gradient == null ? AppColors.primary : null,
                ),
              ),
            ),
          ),
          // Filled portion
          AnimatedFractionallySizedBox(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            widthFactor: progress.clamp(0.0, 1.0),
            heightFactor: 1.0,
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                gradient: gradient,
                color: gradient == null ? AppColors.primary : null,
              ),
            ),
          ),
          // Label
          Center(
            child: Text(
              '$percent%  $label',
              style: AppTextStyles.labelLarge.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
