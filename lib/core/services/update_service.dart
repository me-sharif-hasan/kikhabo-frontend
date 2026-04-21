import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Checks Google Play for app updates and triggers the right flow.
///
/// **How to mark an update as mandatory:**
/// When publishing a release in Play Console, set "Update priority" (0–5):
///   • Priority >= [_mandatoryThreshold] (4–5) → immediate update.
///     Full-screen system UI, non-dismissable. User CANNOT use the app until
///     they update.
///   • Priority 0–3 → flexible update. Background download, user is shown a
///     dialog and can choose to update or defer.
///
/// The service is a no-op on iOS, web, or in debug/side-loaded builds where
/// the Play APIs are unavailable.
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  /// Update priority threshold at or above which we force an immediate update.
  static const int _mandatoryThreshold = 4;

  /// Prevents showing the optional-update dialog more than once per session.
  bool _flexibleShownThisSession = false;

  /// Check for updates and, if available, trigger the appropriate flow.
  ///
  /// Pass a [BuildContext] that is still mounted when the check completes.
  Future<void> checkAndPrompt(BuildContext context) async {
    // in_app_update only works on Android / Google Play builds.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    try {
      final info = await InAppUpdate.checkForUpdate();
      debugPrint(
        '[UpdateService] availability=${info.updateAvailability} '
        'priority=${info.updatePriority} '
        'immediate=${info.immediateUpdateAllowed} '
        'flexible=${info.flexibleUpdateAllowed}',
      );

      if (info.updateAvailability != UpdateAvailability.updateAvailable) return;
      if (!context.mounted) return;

      final isMandatory = info.updatePriority >= _mandatoryThreshold;

      if (isMandatory && info.immediateUpdateAllowed) {
        // Immediate update: hands off to Play Store's full-screen UI.
        // The user cannot dismiss it — they must update or the app closes.
        await _doImmediateUpdate(context);
      } else if (!isMandatory &&
          info.flexibleUpdateAllowed &&
          !_flexibleShownThisSession) {
        _flexibleShownThisSession = true;
        _showFlexibleDialog(context);
      }
    } catch (e) {
      // Swallow silently — emulator, side-loaded APK, no network, etc.
      debugPrint('[UpdateService] update check skipped: $e');
    }
  }

  // ── Immediate (mandatory) update ───────────────────────────────────────────

  Future<void> _doImmediateUpdate(BuildContext context) async {
    if (!context.mounted) return;

    // Show a non-dismissable dialog while we hand off to Play Store.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _MandatoryUpdateDialog(),
    );

    try {
      final result = await InAppUpdate.performImmediateUpdate();
      debugPrint('[UpdateService] immediate result: $result');
    } catch (e) {
      debugPrint('[UpdateService] immediate update error: $e');
    }
  }

  // ── Flexible (optional) update ─────────────────────────────────────────────

  void _showFlexibleDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _FlexibleUpdateDialog(),
    );
  }
}

// ── Mandatory update dialog ─────────────────────────────────────────────────

class _MandatoryUpdateDialog extends StatelessWidget {
  const _MandatoryUpdateDialog();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // prevent back-button dismiss
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.system_update_rounded, color: AppColors.primary, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Update Required',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'A critical update is required to continue using Kikhabo. '
          'Please update the app from the Play Store.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              try {
                await InAppUpdate.performImmediateUpdate();
              } catch (e) {
                debugPrint('[UpdateService] retry immediate update error: $e');
              }
            },
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Update Now'),
          ),
        ],
      ),
    );
  }
}

// ── Flexible update dialog ──────────────────────────────────────────────────

class _FlexibleUpdateDialog extends StatefulWidget {
  const _FlexibleUpdateDialog();

  @override
  State<_FlexibleUpdateDialog> createState() => _FlexibleUpdateDialogState();
}

class _FlexibleUpdateDialogState extends State<_FlexibleUpdateDialog> {
  bool _updating = false;

  Future<void> _startUpdate() async {
    setState(() => _updating = true);
    try {
      await InAppUpdate.startFlexibleUpdate();
      await InAppUpdate.completeFlexibleUpdate();
    } catch (e) {
      debugPrint('[UpdateService] flexible update failed: $e');
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
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary),
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
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _startUpdate,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Update Now'),
              ),
            ],
    );
  }
}
