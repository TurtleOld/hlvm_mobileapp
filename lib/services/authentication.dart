import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

class AuthService {
  final Dio _dio = Dio();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  final String _baseUrl = 'https://hlvm.pavlovteam.ru/api';

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await _dio.post('$_baseUrl/auth/token/', data: {
        'username': username,
        'password': password,
      });

      if (response.statusCode == 200) {
        final accessToken = response.data['access'];
        final refreshToken = response.data['refresh'];
        await _secureStorage.write(key: 'access_token', value: accessToken);
        await _secureStorage.write(key: 'refresh_token', value: refreshToken);
        await _secureStorage.write(key: 'isLoggedIn', value: 'true');
        return {'success': true, 'message': 'Авторизация пройдена'};
      } else {
        return {'success': false, 'message': 'Ошибка авторизации'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Ошибка $e'};
    }
  }

  Future<bool> isLoggedIn() async {
    final isLoggedIn = await _secureStorage.read(key: 'isLoggedIn');
    final accessToken = await _secureStorage.read(key: 'access_token');
    final refreshToken = await _secureStorage.read(key: 'refresh_token');
    return isLoggedIn == 'true' && accessToken != null && refreshToken != null;
  }

  Future<void> refreshToken() async {
    final refreshToken = await _secureStorage.read(key: 'refresh_token');

    if (refreshToken == null) {
      throw Exception("Refresh token is missing");
    }

    try {
      final response = await _dio.post(
        "$_baseUrl/auth/token/refresh/",
        data: {"refresh": refreshToken},
      );

      final newAccessToken = response.data['access'];
      await _secureStorage.write(key: 'access_token', value: newAccessToken);
    } catch (e) {
      throw Exception("Failed to refresh token: $e");
    }
  }

  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: 'access_token');
  }

  Future<void> logout(BuildContext context) async {
    await _secureStorage.delete(key: 'access_token');
    await _secureStorage.delete(key: 'refresh_token');
    await _secureStorage.delete(key: 'isLoggedIn');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Вы успешно вышли из аккаунта')),
    );
  }
}
