import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/youtube_service.dart';

final youtubeServiceProvider = Provider<YouTubeService>((ref) {
  final service = YouTubeService();
  ref.onDispose(service.dispose);
  return service;
});

final youtubeSearchProvider =
    FutureProvider.family<List<YouTubeVideo>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];
  return ref.watch(youtubeServiceProvider).searchVideos(query);
});
