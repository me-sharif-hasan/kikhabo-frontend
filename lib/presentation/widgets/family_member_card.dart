import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/user.dart';

class FamilyMemberCard extends StatelessWidget {
  final User member;
  final VoidCallback? onDelete;

  const FamilyMemberCard({
    super.key,
    required this.member,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.2),
                border: Border.all(
                    color: AppColors.glassBorder.withValues(alpha: 0.5)),
              ),
              child: Center(
                child: Text(
                  (member.firstName?.substring(0, 1) ?? 'U').toUpperCase(),
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.current.isDark
                        ? Colors.white
                        : AppColors.glassText,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${member.firstName} ${member.lastName}',
                    style: AppTextStyles.titleMedium,
                  ),
                  Text(
                    member.email,
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: AppColors.error),
              onPressed: onDelete,
              tooltip: 'Remove Member',
            ),
          ],
        ),
      ),
    );
  }
}
