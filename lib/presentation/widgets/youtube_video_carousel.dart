import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/youtube_service.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/providers/youtube_provider.dart';
import 'glass_card.dart';

class YouTubeVideoCarousel extends ConsumerWidget {
  final List<String> searchTerms;

  /// When false, the "Watch Recipes" header and divider are hidden and the
  /// GlassCard wrapper is removed — suitable for use as a full-bleed hero.
  final bool showHeader;

  const YouTubeVideoCarousel({
    super.key,
    required this.searchTerms,
    this.showHeader = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = searchTerms.first;
    final asyncVideos = ref.watch(youtubeSearchProvider(query));

    // Height of the thumbnail area: larger when used as a hero
    final thumbHeight = showHeader ? 180.0 : 260.0;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) ...[
          Row(
            children: [
              const Icon(Icons.play_circle_outline, color: Colors.redAccent, size: 24),
              const SizedBox(width: 8),
              Text('Watch Recipes', style: AppTextStyles.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10),
          const SizedBox(height: 8),
        ],
        asyncVideos.when(
          loading: () => SizedBox(
            height: thumbHeight,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2),
            ),
          ),
          error: (_, __) => _FallbackSearchLinks(searchTerms: searchTerms),
          data: (videos) {
            if (videos.isEmpty) return _FallbackSearchLinks(searchTerms: searchTerms);
            return _VideoPageView(
              videos: videos,
              searchTerm: query,
              thumbHeight: thumbHeight,
            );
          },
        ),
      ],
    );

    if (!showHeader) return content; // edge-to-edge, no card wrapper

    return GlassCard(blur: 10, child: content);
  }
}

class _VideoPageView extends StatefulWidget {
  final List<YouTubeVideo> videos;
  final String searchTerm;
  final double thumbHeight;

  const _VideoPageView({
    required this.videos,
    required this.searchTerm,
    required this.thumbHeight,
  });

  @override
  State<_VideoPageView> createState() => _VideoPageViewState();
}

class _VideoPageViewState extends State<_VideoPageView> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  YoutubePlayerController? _playerCtrl;

  @override
  void dispose() {
    _playerCtrl?.pause();
    _playerCtrl?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _play(YouTubeVideo video) {
    _playerCtrl?.pause();
    _playerCtrl?.dispose();
    AnalyticsService.instance.logYouTubeVideoPlayed(
      videoId: video.videoId,
      videoTitle: video.title,
      searchTerm: widget.searchTerm,
    );
    setState(() {
      _playerCtrl = YoutubePlayerController(
        initialVideoId: video.videoId,
        flags: const YoutubePlayerFlags(autoPlay: true, mute: false),
      );
    });
  }

  void _closePlayer() {
    _playerCtrl?.pause();
    _playerCtrl?.dispose();
    setState(() => _playerCtrl = null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_playerCtrl != null)
          _InlinePlayer(controller: _playerCtrl!, onClose: _closePlayer)
        else
          SizedBox(
            height: widget.thumbHeight,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.videos.length,
              onPageChanged: (p) => setState(() => _currentPage = p),
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _VideoThumbnailCard(
                  video: widget.videos[i],
                  onPlay: () => _play(widget.videos[i]),
                ),
              ),
            ),
          ),
        if (widget.videos.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.videos.length, (i) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _currentPage == i ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _currentPage == i ? Colors.redAccent : Colors.white24,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

/// Inline YouTube player that replaces the thumbnail in-place.
/// StatefulWidget so we can listen to the controller and force
/// play() once the WebView is ready — Android blocks autoPlay
/// without an explicit programmatic play() call.
class _InlinePlayer extends StatefulWidget {
  final YoutubePlayerController controller;
  final VoidCallback onClose;

  const _InlinePlayer({required this.controller, required this.onClose});

  @override
  State<_InlinePlayer> createState() => _InlinePlayerState();
}

class _InlinePlayerState extends State<_InlinePlayer> {
  bool _didPlay = false;

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: widget.controller,
        showVideoProgressIndicator: true,
        progressIndicatorColor: Colors.redAccent,
        onReady: () {
          if (!_didPlay) {
            _didPlay = true;
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted) widget.controller.play();
            });
          }
        },
        bottomActions: [
          const SizedBox(width: 8),
          CurrentPosition(),
          const SizedBox(width: 8),
          ProgressBar(isExpanded: true),
          const SizedBox(width: 8),
          RemainingDuration(),
          const SizedBox(width: 8),
          PlaybackSpeedButton(),
          const SizedBox(width: 4),
          FullScreenButton(),
          const SizedBox(width: 8),
        ],
      ),
      builder: (context, player) => Stack(
        children: [
          player,
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: widget.onClose,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoThumbnailCard extends StatelessWidget {
  final YouTubeVideo video;
  final VoidCallback onPlay;

  const _VideoThumbnailCard({required this.video, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPlay,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: video.thumbnailUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => _thumbnailPlaceholder(),
              errorWidget: (_, __, ___) => _thumbnailPlaceholder(),
            ),
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                ),
              ),
            ),
            // Play button
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
              ),
            ),
            // Title at bottom
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Text(
                video.title,
                style: AppTextStyles.labelSmall.copyWith(color: Colors.white),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbnailPlaceholder() => Container(
        color: Colors.black45,
        child: Center(
          child: Opacity(
            opacity: 0.5,
            child: Image.asset('assets/logo.png', width: 48, height: 48),
          ),
        ),
      );
}

/// Fallback when search returns no results — shows YouTube search links
class _FallbackSearchLinks extends StatelessWidget {
  final List<String> searchTerms;

  const _FallbackSearchLinks({required this.searchTerms});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: searchTerms.map((term) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () {
              final query = Uri.encodeComponent(term);
              launchUrl(
                Uri.parse('https://www.youtube.com/results?search_query=$query'),
                mode: LaunchMode.externalApplication,
              );
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.redAccent, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      term,
                      style: AppTextStyles.bodyMedium.copyWith(color: Colors.redAccent),
                    ),
                  ),
                  const Icon(Icons.open_in_new, color: Colors.redAccent, size: 16),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
