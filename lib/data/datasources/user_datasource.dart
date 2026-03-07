import 'package:dio/dio.dart';
import '../models/user.dart';
import '../../core/constants/api_constants.dart';

/// Responsible for User profile related API calls.
class UserDataSource {
  final Dio _dio;

  UserDataSource(this._dio);

  /// Fetches the currently authenticated user's profile.
  Future<User> getCurrentUser() async {
    try {
      final response = await _dio.get(ApiConstants.currentUser);
      final data = response.data['data'] as Map<String, dynamic>;
      return User.fromJson(data);
    } catch (e) {
      rethrow;
    }
  }

  /// Updates the user's profile information.
  Future<void> updateUser(Map<String, dynamic> data) async {
    try {
      await _dio.put(ApiConstants.updateUser, data: data);
    } catch (e) {
      rethrow;
    }
  }

  /// Uploads a profile image (multipart). Returns the S3 URL.
  Future<String> uploadProfileImage(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });
      final response = await _dio.post(
        ApiConstants.profileImage,
        data: formData,
      );
      return response.data['data'] as String;
    } catch (e) {
      rethrow;
    }
  }

  /// Searches for users by query string.
  Future<List<User>> searchUsers(String query) async {
    try {
      final response = await _dio.get(
        ApiConstants.searchUser,
        queryParameters: {'query': query},
      );
      
      // API returns { "status": "success", "data": [...] }
      if (response.data is Map<String, dynamic>) {
        final data = response.data['data'];
        if (data is List) {
          return data.map((e) => User.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
      // Fallback if API returns direct list
      else if (response.data is List) {
        return (response.data as List)
            .map((e) => User.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }
}
