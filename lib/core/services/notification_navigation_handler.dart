import 'dart:convert';
import 'package:go_router/go_router.dart';

/// Parses FCM data payload and navigates to the correct screen.
/// Must be initialized with a GoRouter after it is created.
class NotificationNavigationHandler {
  GoRouter? _router;

  /// Stores the route from a terminated-state notification tap.
  /// The splash screen reads this after auth is confirmed and clears it.
  Map<String, dynamic>? pendingNotificationData;

  void attachRouter(GoRouter router) {
    _router = router;
  }

  /// Called when a notification is tapped.
  /// If the router is not yet ready (terminated state), stores the data as pending.
  void handle(Map<String, dynamic> data) {
    if (_router == null) {
      pendingNotificationData = data;
      return;
    }
    _navigate(data);
  }

  /// Called by the splash screen after auth is confirmed.
  /// Returns true if a pending navigation was performed.
  bool handlePendingIfAny() {
    final data = pendingNotificationData;
    if (data == null) return false;
    pendingNotificationData = null;
    _navigate(data);
    return true;
  }

  void _navigate(Map<String, dynamic> data) {
    final router = _router;
    if (router == null) return;

    // Normalize type to lowercase so both "MEAL_LIST" and "meal_list" work
    final type = (data['type'] as String?)?.toLowerCase();
    final route = data['route'] as String?;

    switch (type) {
      case 'meal_list':
        router.go('/dashboard/meals');
      case 'streak_reminder':
        router.go('/dashboard/home');
      case 'achievement':
        final extra = _decodeExtra(data['extra']);
        router.go('/dashboard/profile', extra: extra);
      case 'points_earned':
        router.go('/dashboard/statistics');
      case 'challenge':
        router.go('/dashboard/statistics');
      case 'family_activity':
        router.go('/dashboard/family');
      default:
        // Fall back to the route field if type is unknown
        if (route != null && route.isNotEmpty) router.go(route);
    }
  }

  Map<String, dynamic> _decodeExtra(dynamic raw) {
    if (raw is String && raw.isNotEmpty) {
      try {
        return jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {}
    }
    return {};
  }
}
