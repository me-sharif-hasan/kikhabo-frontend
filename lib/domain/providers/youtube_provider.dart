import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/youtube_service.dart';

final _youtubeDioProvider = Provider<Dio>((ref) => Dio());

final youtubeServiceProvider = Provider<YouTubeService>((ref) {
  return YouTubeService(ref.watch(_youtubeDioProvider));
});

/// Searches YouTube for videos matching [query]. Returns empty list if API key
/// is not configured or if the query is empty.
final youtubeSearchProvider =
    FutureProvider.family<List<YouTubeVideo>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];
  return ref.watch(youtubeServiceProvider).searchVideos(query);
});
