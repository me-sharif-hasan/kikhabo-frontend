import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kikhabo_flutter/core/constants/api_constants.dart';
import 'package:kikhabo_flutter/core/constants/app_constants.dart';

void main() async {
  print("Starting test...");
  try {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: AppConstants.tokenKey);
    print("Token: ${token?.substring(0, 10)}...");
    if (token == null) {
      print('No token, please log in first on emulator');
      return;
    }
    
    final dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      headers: {
        'Authorization': 'Bearer $token',
      }
    ));
    
    print("Fetching meal history...");
    final response = await dio.get(ApiConstants.mealHistory, queryParameters: {'page': 0, 'size': 1});
    print('GET Data: ${response.data}');
  } catch (e) {
    print('Error: $e');
  }
}
