import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Manages interstitial ad loading, frequency capping, and display.
///
/// Policy: at most 1 ad per [_minInterval] (3 minutes).
/// The next ad is pre-loaded immediately after each display so it is
/// ready by the time the user triggers the next eligible event.
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  static const String _adUnitId =
      'ca-app-pub-8867603755047103/4910523503';

  static const Duration _minInterval = Duration(minutes: 3);

  InterstitialAd? _ad;
  bool _isLoading = false;
  DateTime? _lastShown;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    _load();
  }

  // ── Internal loading ───────────────────────────────────────────────────────

  void _load() {
    if (_isLoading || _ad != null) return;
    _isLoading = true;

    InterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _isLoading = false;
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          debugPrint('[AdService] Failed to load: ${error.message}');
          // Retry after 90 s — avoids hammering on network issues
          Future.delayed(const Duration(seconds: 90), _load);
        },
      ),
    );
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Attempts to show the interstitial.
  ///
  /// - Skipped silently if the frequency cap has not elapsed.
  /// - Skipped silently if no ad is loaded yet.
  /// - [onDone] is called in ALL cases (ad shown+dismissed, or skipped) so
  ///   the caller can always proceed with its own navigation/action.
  void show({VoidCallback? onDone}) {
    final now = DateTime.now();

    // Frequency cap check
    if (_lastShown != null && now.difference(_lastShown!) < _minInterval) {
      debugPrint('[AdService] Skipped — frequency cap active');
      onDone?.call();
      return;
    }

    // No ad ready
    if (_ad == null) {
      debugPrint('[AdService] Skipped — no ad loaded');
      onDone?.call();
      _load(); // Ensure loading is in progress
      return;
    }

    final ad = _ad!;
    _ad = null;
    _lastShown = now;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        onDone?.call();
        _load(); // Pre-load next ad
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[AdService] Failed to show: ${error.message}');
        ad.dispose();
        onDone?.call();
        _load();
      },
    );

    ad.show();
  }
}
