import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Checks for Play Store updates and shows a dialog offering to update or snooze.
/// The dialog re-appears every time the app is (re)opened — dismissing via
/// "Remind me later" only suppresses it for the current session.
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  /// True once we have already prompted the user in this process lifetime.
  bool _shownThisSession = false;

  /// Call this from the home screen (or any entry-point screen).
  /// Safely no-ops on iOS / when not installed from Play Store.
  Future<void> checkAndPrompt(BuildContext context) async {
    if (_shownThisSession) return;

    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) return;
      if (!context.mounted) return;

      _shownThisSession = true;
      _showUpdateDialog(context, info);
    } catch (e) {
      // Not installed via Play Store, no network, etc. — silently ignore.
      debugPrint('[UpdateService] update check skipped: $e');
    }
  }

  void _showUpdateDialog(BuildContext context, AppUpdateInfo info) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _UpdateDialog(info: info),
    );
  }
}

class _UpdateDialog extends StatefulWidget {
  final AppUpdateInfo info;
  const _UpdateDialog({required this.info});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _updating = false;

  Future<void> _startUpdate() async {
    setState(() => _updating = true);
    try {
      // Flexible update: user can keep using the app while it downloads.
      await InAppUpdate.startFlexibleUpdate();
      await InAppUpdate.completeFlexibleUpdate();
    } catch (e) {
      debugPrint('[UpdateService] update failed: $e');
    } finally {
      if (mounted) {
        setState(() => _updating = false);
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.system_update_alt_rounded, color: AppColors.primary, size: 28),
          const SizedBox(width: 10),
          Text(
            'Update Available',
            style: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimary),
          ),
        ],
      ),
      content: Text(
        'A new version of Kikhabo is available on the Play Store. '
        'Update now to get the latest features and improvements.',
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
      ),
      actions: _updating
          ? [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Updating…',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ]
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Remind me later',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _startUpdate,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Update Now'),
              ),
            ],
    );
  }
}
