import 'package:dio/dio.dart';
import '../constants/api_constants.dart';

class YouTubeVideo {
  final String videoId;
  final String title;
  final String thumbnailUrl;

  const YouTubeVideo({
    required this.videoId,
    required this.title,
    required this.thumbnailUrl,
  });

  factory YouTubeVideo.fromJson(Map<String, dynamic> json) {
    final snippet = json['snippet'] as Map<String, dynamic>;
    final id = json['id'] as Map<String, dynamic>;
    final thumbnails = snippet['thumbnails'] as Map<String, dynamic>;
    final medium = thumbnails['medium'] as Map<String, dynamic>?;
    final high = thumbnails['high'] as Map<String, dynamic>?;
    return YouTubeVideo(
      videoId: id['videoId'] as String,
      title: snippet['title'] as String,
      thumbnailUrl: (high ?? medium ?? thumbnails['default'])['url'] as String,
    );
  }
}

class YouTubeService {
  final Dio _dio;

  YouTubeService(this._dio);

  Future<List<YouTubeVideo>> searchVideos(String query, {int maxResults = 4}) async {
    if (ApiConstants.youtubeApiKey.isEmpty) return [];
    final response = await _dio.get(
      ApiConstants.youtubeSearch,
      queryParameters: {
        'part': 'snippet',
        'q': query,
        'type': 'video',
        'maxResults': maxResults,
        'key': ApiConstants.youtubeApiKey,
      },
    );
    final items = (response.data['items'] as List<dynamic>?) ?? [];
    return items
        .map((item) => YouTubeVideo.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
