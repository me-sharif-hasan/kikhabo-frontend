import 'package:firebase_analytics/firebase_analytics.dart';

/// Central Firebase Analytics service.
/// All events are logged through this class so the app stays decoupled
/// from the Firebase SDK. Call [AnalyticsService.instance] from anywhere.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Expose the observer so it can be added to MaterialApp/GoRouter.
  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  // ── Screen tracking ───────────────────────────────────────────────────────

  /// Log a screen view. Called from each screen's initState / didChangeDependencies.
  Future<void> logScreenView(String screenName) async {
    await _analytics.logScreenView(screenName: screenName);
  }

  // ── Auth events ───────────────────────────────────────────────────────────

  /// Called after a successful login. Logs the user identity for segmentation.
  Future<void> logLogin({
    required String userId,
    required String email,
    String? displayName,
  }) async {
    // Set user properties so every subsequent event is tagged with user info.
    await _analytics.setUserId(id: userId);
    await _analytics.setUserProperty(name: 'email', value: email);
    if (displayName != null) {
      await _analytics.setUserProperty(name: 'display_name', value: displayName);
    }
    await _analytics.logLogin(loginMethod: 'email_password');
  }

  /// Called on logout — clears the user identity.
  Future<void> logLogout() async {
    await _analytics.logEvent(name: 'user_logout');
    await _analytics.setUserId(id: null);
  }

  // ── Meal generation ───────────────────────────────────────────────────────

  /// Fired when the user taps "Generate Meal Plan".
  Future<void> logMealPlanGenerated({
    required int days,
    required int mealsPerDay,
    required double spiciness,
    required double saltiness,
    required String priceRange,
  }) async {
    await _analytics.logEvent(
      name: 'meal_plan_generated',
      parameters: {
        'days': days,
        'meals_per_day': mealsPerDay,
        'spiciness': spiciness.toInt(),
        'saltiness': saltiness.toInt(),
        'price_range': priceRange,
        'total_meals': days * mealsPerDay,
      },
    );
  }

  // ── PDF ───────────────────────────────────────────────────────────────────

  /// Fired when a shopping list PDF is successfully generated.
  Future<void> logPdfGenerated({required int mealCount}) async {
    await _analytics.logEvent(
      name: 'pdf_generated',
      parameters: {'meal_count': mealCount},
    );
  }

  // ── YouTube ───────────────────────────────────────────────────────────────

  /// Fired when a user taps a YouTube video thumbnail to open the player.
  Future<void> logYouTubeVideoPlayed({
    required String videoId,
    required String videoTitle,
    required String searchTerm,
  }) async {
    await _analytics.logEvent(
      name: 'youtube_video_played',
      parameters: {
        'video_id': videoId,
        'video_title': videoTitle.length > 100
            ? videoTitle.substring(0, 100)
            : videoTitle,
        'search_term': searchTerm,
      },
    );
  }

  /// Fired when a user enters fullscreen on a YouTube video.
  Future<void> logYouTubeFullscreen({required String videoId}) async {
    await _analytics.logEvent(
      name: 'youtube_fullscreen',
      parameters: {'video_id': videoId},
    );
  }

  // ── Meal interactions ─────────────────────────────────────────────────────

  /// Fired when a meal card is tapped to open detail.
  Future<void> logMealDetailViewed({
    required String mealName,
    int? mealId,
  }) async {
    await _analytics.logEvent(
      name: 'meal_detail_viewed',
      parameters: {
        'meal_name': mealName,
        if (mealId != null) 'meal_id': mealId,
      },
    );
  }

  /// Fired when a user saves a rating/status update.
  Future<void> logMealStatusUpdated({
    required String status,
    required int rating,
    int? mealId,
  }) async {
    await _analytics.logEvent(
      name: 'meal_status_updated',
      parameters: {
        'status': status,
        'rating': rating,
        if (mealId != null) 'meal_id': mealId,
      },
    );
  }

  // ── Navigation / button taps ──────────────────────────────────────────────

  /// Generic button tap tracker. Use a consistent [buttonId] label.
  Future<void> logButtonTap({
    required String buttonId,
    String? screenName,
    Map<String, Object>? extra,
  }) async {
    await _analytics.logEvent(
      name: 'button_tapped',
      parameters: {
        'button_id': buttonId,
        if (screenName != null) 'screen_name': screenName,
        ...?extra,
      },
    );
  }

  /// Fired when the user opens the side drawer.
  Future<void> logDrawerOpened() async {
    await _analytics.logEvent(name: 'drawer_opened');
  }

  /// Fired when a drawer menu item is tapped.
  Future<void> logDrawerNavigation(String destination) async {
    await _analytics.logEvent(
      name: 'drawer_navigation',
      parameters: {'destination': destination},
    );
  }

  // ── Profile ───────────────────────────────────────────────────────────────

  Future<void> logProfileUpdated() async {
    await _analytics.logEvent(name: 'profile_updated');
  }

  Future<void> logProfileImageUpdated() async {
    await _analytics.logEvent(name: 'profile_image_updated');
  }

  // ── Family ────────────────────────────────────────────────────────────────

  Future<void> logFamilyMemberAdded() async {
    await _analytics.logEvent(name: 'family_member_added');
  }

  // ── Preferences ──────────────────────────────────────────────────────────

  Future<void> logPreferencesUpdated() async {
    await _analytics.logEvent(name: 'preferences_updated');
  }
}
