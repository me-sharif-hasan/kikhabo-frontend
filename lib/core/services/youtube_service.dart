import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YouTubeVideo {
  final String videoId;
  final String title;
  final String thumbnailUrl;

  const YouTubeVideo({
    required this.videoId,
    required this.title,
    required this.thumbnailUrl,
  });

  Map<String, dynamic> toJson() => {
        'videoId': videoId,
        'title': title,
        'thumbnailUrl': thumbnailUrl,
      };

  factory YouTubeVideo.fromJson(Map<String, dynamic> json) => YouTubeVideo(
        videoId: json['videoId'] as String,
        title: json['title'] as String,
        thumbnailUrl: json['thumbnailUrl'] as String,
      );
}

class YouTubeService {
  static const String _cachePrefix = 'yt_search_';
  final YoutubeExplode _yt = YoutubeExplode();

  Future<List<YouTubeVideo>> searchVideos(String query, {int maxResults = 4}) async {
    final cacheKey = '$_cachePrefix${query.trim().toLowerCase()}';

    // Return cached results if available
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(cacheKey);
    if (cached != null) {
      final list = (jsonDecode(cached) as List<dynamic>)
          .map((e) => YouTubeVideo.fromJson(e as Map<String, dynamic>))
          .toList();
      if (list.isNotEmpty) return list;
    }

    // Fetch from YouTube and cache
    final results = await _yt.search.search(query);
    final videos = results
        .take(maxResults)
        .map((video) => YouTubeVideo(
              videoId: video.id.value,
              title: video.title,
              thumbnailUrl: video.thumbnails.highResUrl,
            ))
        .toList();

    if (videos.isNotEmpty) {
      await prefs.setString(cacheKey, jsonEncode(videos.map((v) => v.toJson()).toList()));
    }

    return videos;
  }

  void dispose() => _yt.close();
}
