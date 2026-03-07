import 'package:dio/dio.dart';
import '../datasources/user_datasource.dart';
import '../models/user.dart';

/// Repository for User profile logic.
class UserRepository {
  final UserDataSource _dataSource;

  UserRepository(this._dataSource);

  String _mapError(Object e) {
    if (e is DioException) {
      final message = e.response?.data['message'];
      
      // Handle List of error messages
      if (message is List) {
        return message.map((e) => e.toString()).join('\n');
      } else if (message is String) {
        return message;
      }
      
      return 'Network error occurred';
    }
    return 'Unknown error occurred';
  }

  Future<User> getCurrentUser() async {
    try {
      return await _dataSource.getCurrentUser();
    } catch (e) {
      throw Exception(_mapError(e));
    }
  }

  Future<void> updateUser(Map<String, dynamic> data) async {
    try {
      await _dataSource.updateUser(data);
    } catch (e) {
      throw Exception(_mapError(e));
    }
  }

  Future<String> uploadProfileImage(String filePath) async {
    try {
      return await _dataSource.uploadProfileImage(filePath);
    } catch (e) {
      throw Exception(_mapError(e));
    }
  }

  Future<List<User>> searchUsers(String query) async {
    try {
      return await _dataSource.searchUsers(query);
    } catch (e) {
      throw Exception(_mapError(e));
    }
  }
}
