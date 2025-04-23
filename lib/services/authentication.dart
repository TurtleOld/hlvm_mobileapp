import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

class AuthService {
  final Dio _dio = Dio();

  final String _baseUrl = 'https://hlvm.pavlovteam.ru/api';

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await _dio.post('$_baseUrl/auth/token/', data: {
        'username': username,
        'password': password,
      });

      if (response.statusCode == 200) {
        await saveLoginStatus(true);
        final accessToken = response.data['access'];
        final refreshToken = response.data['refresh'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', accessToken);
        await prefs.setString('refresh_token', refreshToken);
        return {'success': true, 'message': 'Авторизация пройдена'};
      } else {
        return {'success': false, 'message': 'Ошибка авторизации'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Ошибка $e'};
    }
  }

  Future<void> saveLoginStatus(bool isLoggedIn) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', isLoggedIn);
  }

  Future<bool> isLoggedIn() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  Future<void> refreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refresh_token');
    if (refreshToken == null) {
      throw Exception("Refresh token is missing");
    }
    try {
      final response = await _dio.post(
        "$_baseUrl/auth/token/refresh/",
        data: {"refresh": refreshToken},
      );
      final newAccessToken = response.data['access'];
      await prefs.setString('access_token', newAccessToken);
    } catch (e) {
      throw Exception("Failed to refresh token: $e");
    }
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<void> logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('isLoggedIn');
    await saveLoginStatus(false);
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Вы успешно вышли из аккаунта')));
  }
}
