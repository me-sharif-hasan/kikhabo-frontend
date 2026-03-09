import 'dart:io';
import 'package:dio/dio.dart';
import '../models/user.dart';
import '../../core/constants/api_constants.dart';

/// Responsible for Authentication related API calls.
class AuthDataSource {
  final Dio _dio;

  AuthDataSource(this._dio);

  /// Authenticates a user and returns the login response (token).
  /// 
  /// Throws [DioException] on failure.
  Future<LoginResponseDto> login(CredentialsDto credentials) async {
    try {
      final response = await _dio.post(
        ApiConstants.login,
        data: credentials.toJson(),
      );
      
      // The API returns the DTO directly based on analysis
      return LoginResponseDto.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  /// Registers a new user.
  ///
  /// Throws [DioException] on failure.
  Future<void> register(UserDto userDto) async {
    try {
      await _dio.post(
        ApiConstants.register,
        data: userDto.toJson(),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> registerFcmToken(String token) async {
    try {
      await _dio.post(
        ApiConstants.fcmToken,
        data: {
          'fcmToken': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
        },
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Verifies the stored token is still valid by hitting an authenticated endpoint.
  /// Throws [DioException] on 4xx/5xx.
  Future<void> verifyAuth() async {
    await _dio.get(ApiConstants.currentUser);
  }

  Future<void> deleteFcmToken(String token) async {
    try {
      await _dio.delete(
        ApiConstants.fcmToken,
        data: {'fcmToken': token},
      );
    } catch (e) {
      rethrow;
    }
  }
}
