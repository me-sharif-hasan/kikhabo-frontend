import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'notification_navigation_handler.dart';

/// Background message handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialized by the time this runs.
  // No navigation here — the app is not running.
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _fcm = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  // Android channels
  static const _gamificationChannel = AndroidNotificationChannel(
    'kikhabo_gamification',
    'Achievements & Rewards',
    description: 'Achievements, points, and challenge notifications',
    importance: Importance.high,
  );

  static const _remindersChannel = AndroidNotificationChannel(
    'kikhabo_reminders',
    'Reminders',
    description: 'Streak reminders and meal plan updates',
    importance: Importance.defaultImportance,
  );

  /// Call once after Firebase.initializeApp().
  Future<void> initialize({required NotificationNavigationHandler navigationHandler}) async {
    // Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Request permission
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Create Android channels
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_gamificationChannel);
    await androidPlugin?.createNotificationChannel(_remindersChannel);

    // Init local notifications
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/launcher_icon'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Foreground notification tapped
        final payload = details.payload;
        if (payload != null) {
          final data = jsonDecode(payload) as Map<String, dynamic>;
          navigationHandler.handle(data);
        }
      },
    );

    // Foreground messages — show via local notifications
    FirebaseMessaging.onMessage.listen((message) {
      _showLocalNotification(message);
    });

    // Background notification tapped (app was in background, user tapped)
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      navigationHandler.handle(message.data);
    });
  }

  /// Returns the current FCM token. Null if permission was denied.
  Future<String?> getToken() => _fcm.getToken();

  /// Stream that emits whenever FCM rotates the token.
  Stream<String> get onTokenRefresh => _fcm.onTokenRefresh;

  /// Shows a local notification for foreground messages, including big-picture style for images.
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final isGamification = _isGamificationType(message.data['type']);
    final channelId = isGamification
        ? _gamificationChannel.id
        : _remindersChannel.id;
    final channelName = isGamification
        ? _gamificationChannel.name
        : _remindersChannel.name;

    AndroidNotificationDetails androidDetails;

    final imageUrl = notification.android?.imageUrl ?? notification.apple?.imageUrl;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      // Download image for big-picture style
      final bigPicture = await _downloadAndGetBigPicture(imageUrl);
      androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        importance: isGamification ? Importance.high : Importance.defaultImportance,
        priority: isGamification ? Priority.high : Priority.defaultPriority,
        styleInformation: bigPicture,
      );
    } else {
      androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        importance: isGamification ? Importance.high : Importance.defaultImportance,
        priority: isGamification ? Priority.high : Priority.defaultPriority,
      );
    }

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      notificationDetails,
      payload: jsonEncode(message.data),
    );
  }

  Future<BigPictureStyleInformation?> _downloadAndGetBigPicture(String imageUrl) async {
    try {
      final response = await HttpClient().getUrl(Uri.parse(imageUrl));
      final result = await response.close();
      final bytes = await result.expand((chunk) => chunk).toList();
      return BigPictureStyleInformation(
        ByteArrayAndroidBitmap.fromBase64String(base64Encode(bytes)),
      );
    } catch (_) {
      return null;
    }
  }

  bool _isGamificationType(String? type) {
    return type == 'achievement' ||
        type == 'points_earned' ||
        type == 'challenge' ||
        type == 'streak_reminder';
  }
}
