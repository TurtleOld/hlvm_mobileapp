import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final Dio _dio = Dio();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  AuthService() {
    addAuthInterceptor();
  }

  void addAuthInterceptor() {
    _dio.interceptors.clear();
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final accessToken = await getAccessToken();
          if (accessToken != null) {
            options.headers['Authorization'] = 'Bearer $accessToken';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            try {
              await refreshToken();
              final newAccessToken = await getAccessToken();
              error.requestOptions.headers['Authorization'] =
                  'Bearer $newAccessToken';
              final cloneReq = await _dio.fetch(error.requestOptions);
              return handler.resolve(cloneReq);
            } catch (e) {
              return handler.reject(error);
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  Future<String> get _baseUrl async {
    final prefs = await SharedPreferences.getInstance();
    final server = prefs.getString('server_address');
    if (server != null && server.isNotEmpty) {
      return server.endsWith('/api') ? server : server + '/api';
    }
    throw Exception('Необходимо указать адрес сервера');
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final baseUrl = await _baseUrl;
      final response = await _dio.post('${baseUrl}/auth/token/', data: {
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
        String msg = 'Ошибка авторизации';
        if (response.data != null &&
            response.data is Map &&
            response.data['detail'] != null) {
          msg = response.data['detail'];
        }
        return {'success': false, 'message': msg};
      }
    } catch (e) {
      if (e is DioException && e.response?.data != null) {
        final serverMsg = e.response?.data.toString();
        return {'success': false, 'message': serverMsg};
      }
      if (e.toString().contains('Необходимо указать адрес сервера')) {
        return {
          'success': false,
          'message': 'Необходимо указать адрес сервера в настройках'
        };
      }
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
      final baseUrl = await _baseUrl;
      final response = await _dio.post(
        '${baseUrl}/auth/token/refresh/',
        data: {"refresh": refreshToken},
      );

      final newAccessToken = response.data['access'];
      await _secureStorage.write(key: 'access_token', value: newAccessToken);
    } catch (e) {
      // Удаляем токены вручную, если нет контекста
      await _secureStorage.delete(key: 'access_token');
      await _secureStorage.delete(key: 'refresh_token');
      await _secureStorage.delete(key: 'isLoggedIn');
      throw Exception("Сессия истекла, войдите заново");
    }
  }

  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: 'access_token');
  }

  Future<void> logout([BuildContext? context]) async {
    await _secureStorage.delete(key: 'access_token');
    await _secureStorage.delete(key: 'refresh_token');
    await _secureStorage.delete(key: 'isLoggedIn');
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Вы успешно вышли из аккаунта')),
      );
    }
  }
}
