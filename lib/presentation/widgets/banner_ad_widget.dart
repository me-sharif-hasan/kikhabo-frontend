import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../core/theme/app_colors.dart';

const String _kBannerUnitId = kDebugMode
    ? 'ca-app-pub-3940256099942544/6300978111' // test banner
    : 'ca-app-pub-8867603755047103/2373791829';

/// Full-width self-loading banner ad for vertical lists and detail pages.
///
/// Uses anchored adaptive banner — async API that returns a real pixel height
/// matching the device, and fills the full available width.
/// Renders SizedBox.shrink() while loading or on failure (no layout gap).
class BannerAdWidget extends StatefulWidget {
  final EdgeInsets margin;

  const BannerAdWidget({
    super.key,
    this.margin = const EdgeInsets.symmetric(vertical: 8),
  });

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _ad;
  AdSize? _adSize;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  Future<void> _loadAd() async {
    // Medium rectangle (300×250) — IAB standard, high fill rate, strong CTR.
    // Centered inside a full-width container so it looks native in the list.
    const adSize = AdSize.mediumRectangle;

    final ad = BannerAd(
      adUnitId: _kBannerUnitId,
      size: adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    );
    _ad = ad;
    _adSize = adSize;
    ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null || _adSize == null) return const SizedBox.shrink();

    return Container(
      margin: widget.margin,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
            child: Row(
              children: [
                Text(
                  'SPONSORED',
                  style: TextStyle(
                    fontSize: 9,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          // Center the 300×250 ad in the full-width container
          Center(
            child: SizedBox(
              width: _adSize!.width.toDouble(),   // 300
              height: _adSize!.height.toDouble(), // 250
              child: AdWidget(ad: _ad!),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Compact banner for the horizontal discover-recipes carousel.
/// Uses AdSize.banner (320×50) clipped into a 180px wide card.
class CarouselBannerAdWidget extends StatefulWidget {
  const CarouselBannerAdWidget({super.key});

  @override
  State<CarouselBannerAdWidget> createState() => _CarouselBannerAdWidgetState();
}

class _CarouselBannerAdWidgetState extends State<CarouselBannerAdWidget> {
  BannerAd? _ad;
  bool _loaded = false;

  static const _size = AdSize.largeBanner; // 320×100

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    final ad = BannerAd(
      adUnitId: _kBannerUnitId,
      size: _size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null) return const SizedBox.shrink();

    return Container(
      width: 180,
      height: 210,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
            child: Text(
              'SPONSORED',
              style: TextStyle(
                fontSize: 8,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          ClipRect(
            child: SizedBox(
              width: 180,
              height: _size.height.toDouble(),
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                maxWidth: _size.width.toDouble(),
                child: SizedBox(
                  width: _size.width.toDouble(),
                  height: _size.height.toDouble(),
                  child: AdWidget(ad: _ad!),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
