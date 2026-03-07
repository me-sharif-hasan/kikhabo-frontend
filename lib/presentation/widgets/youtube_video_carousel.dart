import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/youtube_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/providers/youtube_provider.dart';
import 'glass_card.dart';

class YouTubeVideoCarousel extends ConsumerWidget {
  final List<String> searchTerms;

  const YouTubeVideoCarousel({super.key, required this.searchTerms});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use first search term as primary query; fall back to joining all terms
    final query = searchTerms.first;
    final asyncVideos = ref.watch(youtubeSearchProvider(query));

    return GlassCard(
      blur: 10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          asyncVideos.when(
            loading: () => const SizedBox(
              height: 180,
              child: Center(
                child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2),
              ),
            ),
            error: (_, __) => _FallbackSearchLinks(searchTerms: searchTerms),
            data: (videos) {
              if (videos.isEmpty) return _FallbackSearchLinks(searchTerms: searchTerms);
              return _VideoPageView(videos: videos, searchTerm: query);
            },
          ),
        ],
      ),
    );
  }
}

class _VideoPageView extends StatefulWidget {
  final List<YouTubeVideo> videos;
  final String searchTerm;

  const _VideoPageView({required this.videos, required this.searchTerm});

  @override
  State<_VideoPageView> createState() => _VideoPageViewState();
}

class _VideoPageViewState extends State<_VideoPageView> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.videos.length,
            onPageChanged: (page) => setState(() => _currentPage = page),
            itemBuilder: (context, index) {
              final video = widget.videos[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _VideoThumbnailCard(
                  video: video,
                  searchTerm: widget.searchTerm,
                ),
              );
            },
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

class _VideoThumbnailCard extends StatelessWidget {
  final YouTubeVideo video;
  final String searchTerm;

  const _VideoThumbnailCard({required this.video, required this.searchTerm});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AnalyticsService.instance.logYouTubeVideoPlayed(
          videoId: video.videoId,
          videoTitle: video.title,
          searchTerm: searchTerm,
        );
        _openPlayer(context);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              video.thumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.black26,
                child: const Icon(Icons.image_not_supported, color: Colors.white30, size: 48),
              ),
            ),
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                ),
              ),
            ),
            // Play button
            Center(
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
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

  void _openPlayer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (_) => _YouTubePlayerSheet(videoId: video.videoId, title: video.title),
    );
  }
}

class _YouTubePlayerSheet extends StatefulWidget {
  final String videoId;
  final String title;

  const _YouTubePlayerSheet({required this.videoId, required this.title});

  @override
  State<_YouTubePlayerSheet> createState() => _YouTubePlayerSheetState();
}

class _YouTubePlayerSheetState extends State<_YouTubePlayerSheet> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(autoPlay: true, mute: false),
    );
  }

  Future<void> _enterFullScreen() async {
    final position = _controller.value.position;
    _controller.pause();
    AnalyticsService.instance.logYouTubeFullscreen(videoId: widget.videoId);
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullScreenVideoPage(
          videoId: widget.videoId,
          startAt: position,
          title: widget.title,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.pause();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: AppColors.glassBorder, width: 1),
      ),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            YoutubePlayer(
              controller: _controller,
              showVideoProgressIndicator: true,
              progressIndicatorColor: Colors.redAccent,
              bottomActions: [
                const SizedBox(width: 8),
                CurrentPosition(),
                const SizedBox(width: 8),
                ProgressBar(isExpanded: true),
                const SizedBox(width: 8),
                RemainingDuration(),
                const SizedBox(width: 8),
                PlaybackSpeedButton(),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.fullscreen, color: Colors.white),
                  onPressed: _enterFullScreen,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Text(
                widget.title,
                style: AppTextStyles.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullScreenVideoPage extends StatefulWidget {
  final String videoId;
  final Duration startAt;
  final String title;

  const _FullScreenVideoPage({
    required this.videoId,
    required this.startAt,
    required this.title,
  });

  @override
  State<_FullScreenVideoPage> createState() => _FullScreenVideoPageState();
}

class _FullScreenVideoPageState extends State<_FullScreenVideoPage> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: YoutubePlayerFlags(
        autoPlay: true,
        startAt: widget.startAt.inSeconds,
      ),
    );
  }

  @override
  void dispose() {
    _controller.pause();
    _controller.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: YoutubePlayer(
          controller: _controller,
          showVideoProgressIndicator: true,
          progressIndicatorColor: Colors.redAccent,
          bottomActions: [
            const SizedBox(width: 8),
            CurrentPosition(),
            const SizedBox(width: 8),
            ProgressBar(isExpanded: true),
            const SizedBox(width: 8),
            RemainingDuration(),
            const SizedBox(width: 8),
            PlaybackSpeedButton(),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fallback when API key is not set — shows YouTube search links
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
