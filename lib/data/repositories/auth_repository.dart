import 'package:dio/dio.dart';
import '../../data/datasources/auth_datasource.dart';
import '../../data/models/user.dart';

/// Repository for Authentication logic.
/// Handles errors and provides clean API to providers.
class AuthRepository {
  final AuthDataSource _dataSource;

  AuthRepository(this._dataSource);

  /// Helper to map exceptions to messages
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

  Future<LoginResponseDto> login(String email, String password) async {
    try {
      return await _dataSource.login(CredentialsDto(email: email, password: password));
    } catch (e) {
      throw Exception(_mapError(e));
    }
  }

  Future<void> register(UserDto userDto) async {
    try {
      await _dataSource.register(userDto);
    } catch (e) {
      throw Exception(_mapError(e));
    }
  }

  /// Returns true if the stored token is valid (server returns 2xx).
  /// Returns false on any 4xx response (expired/invalid token).
  /// Throws on network errors so the caller can distinguish the two cases.
  Future<bool> verifyAuth() async {
    try {
      await _dataSource.verifyAuth();
      return true;
    } catch (e) {
      if (e is DioException) {
        final status = e.response?.statusCode;
        if (status != null && status >= 400 && status < 500) {
          return false; // 4xx → not authenticated
        }
      }
      rethrow; // network error — let splash decide
    }
  }

  Future<LoginResponseDto> socialLogin(String firebaseIdToken) async {
    try {
      return await _dataSource.socialLogin(firebaseIdToken);
    } catch (e) {
      throw Exception(_mapError(e));
    }
  }

  Future<void> registerFcmToken(String token) async {
    try {
      await _dataSource.registerFcmToken(token);
    } catch (_) {
      // Non-critical — silently ignore failures
    }
  }

  Future<void> deleteFcmToken(String token) async {
    try {
      await _dataSource.deleteFcmToken(token);
    } catch (_) {
      // Non-critical — silently ignore failures
    }
  }
}
