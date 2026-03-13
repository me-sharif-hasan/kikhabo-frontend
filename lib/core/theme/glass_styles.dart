import 'package:flutter/material.dart';
import 'app_colors.dart';

class GlassStyles {
  /// Base decoration for glass cards
  static BoxDecoration get glassDecoration => BoxDecoration(
    color: AppColors.glass,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: AppColors.glassBorder,
      width: 1,
    ),
  );

  /// Decoration for input fields
  static BoxDecoration get glassInputDecoration => BoxDecoration(
    color: AppColors.glass.withValues(alpha: 0.05),
    borderRadius: BorderRadius.circular(15),
    border: Border.all(
      color: AppColors.glassBorder.withValues(alpha: 0.3),
      width: 1,
    ),
  );

  /// Glass container without BackdropFilter — avoids expensive blur
  /// compositing which causes jank on OpenGL-based Android devices.
  /// The semi-transparent [AppColors.glass] color provides the glass
  /// look without the GPU overhead.
  static Widget glassContainer({
    required Widget child,
    double blur = 15, // kept for API compatibility, no longer used
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    double? width,
    double? height,
    BorderRadius? borderRadius,
  }) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      child: Container(
        width: width,
        height: height,
        padding: padding,
        decoration: glassDecoration.copyWith(
          borderRadius: borderRadius ?? BorderRadius.circular(20),
        ),
        child: child,
      ),
    );
  }
}
