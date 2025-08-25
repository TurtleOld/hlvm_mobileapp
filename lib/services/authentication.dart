import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:hlvm_mobileapp/core/services/server_settings_service.dart';

class AuthService {
  final Dio _dio = Dio();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  AuthService() {
    _configureDio();
    addAuthInterceptor();
  }

  void _configureDio() {
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.sendTimeout = const Duration(seconds: 30);
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
              // Проверяем, есть ли refresh token
              final refreshToken =
                  await _secureStorage.read(key: 'refresh_token');
              if (refreshToken == null) {
                await _clearTokens();
                return handler.reject(error);
              }

              // Пытаемся обновить токен
              await this.refreshToken();
              final newAccessToken = await getAccessToken();

              if (newAccessToken != null) {
                // Обновляем заголовок и повторяем запрос
                error.requestOptions.headers['Authorization'] =
                    'Bearer $newAccessToken';
                final cloneReq = await _dio.fetch(error.requestOptions);
                return handler.resolve(cloneReq);
              } else {
                // Если не удалось получить новый токен, очищаем все
                await _clearTokens();
                return handler.reject(error);
              }
            } catch (e) {
              // Если обновление токена не удалось, очищаем все токены
              await _clearTokens();
              return handler.reject(error);
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  Future<String?> get _baseUrl async {
    final serverSettings = ServerSettingsService();
    final server = await serverSettings.getFullServerUrl();

    if (server != null && server.isNotEmpty) {
      // Проверяем корректность URL
      if (server.length > 200 ||
          server.contains(' ') ||
          server.contains('\n')) {
        return null; // Возвращаем null вместо исключения
      }
      
      // Добавляем /api к базовому URL, если его нет
      String baseUrl = server;
      if (baseUrl.endsWith('/api/')) {
        // Убираем trailing slash для единообразия
        baseUrl = baseUrl.substring(0, baseUrl.length - 1);
      } else if (!baseUrl.endsWith('/api')) {
        baseUrl = baseUrl.endsWith('/') ? '${baseUrl}api' : '$baseUrl/api';
      }

      return baseUrl;
    }

    return null; // Возвращаем null вместо исключения
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final baseUrl = await _baseUrl;

      // Проверяем, что адрес сервера настроен
      if (baseUrl == null) {
        return {
          'success': false,
          'message': 'Необходимо указать адрес сервера в настройках',
        };
      }

      final response = await _dio.post(
        '$baseUrl/auth/token/',
        data: {'username': username, 'password': password},
        options: Options(
          headers: {'Content-Type': 'application/json'},
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      if (response.statusCode == 200) {
        final accessToken = response.data['access'];
        final refreshToken = response.data['refresh'];
        await _secureStorage.write(key: 'access_token', value: accessToken);
        await _secureStorage.write(key: 'refresh_token', value: refreshToken);
        await _secureStorage.write(key: 'isLoggedIn', value: 'true');
        await _secureStorage.write(
            key: 'token_refreshed_at', value: DateTime.now().toIso8601String());
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
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout) {
          return {'success': false, 'message': 'Таймаут соединения с сервером'};
        }
        if (e.response?.data != null) {
          final serverMsg = e.response?.data.toString();
          return {'success': false, 'message': serverMsg};
        }
        return {'success': false, 'message': 'Ошибка сети: ${e.message}'};
      }
      return {'success': false, 'message': 'Неожиданная ошибка: $e'};
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

      // Проверяем, что адрес сервера настроен
      if (baseUrl == null) {
        throw Exception("Необходимо указать адрес сервера в настройках");
      }

      final response = await _dio.post(
        '$baseUrl/auth/token/refresh/',
        data: {"refresh": refreshToken},
        options: Options(
          headers: {'Content-Type': 'application/json'},
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      final newAccessToken = response.data['access'];
      await _secureStorage.write(key: 'access_token', value: newAccessToken);
      
      // Обновляем время последнего обновления токена
      await _secureStorage.write(
          key: 'token_refreshed_at', value: DateTime.now().toIso8601String());
    } catch (e) {
      if (e is DioException) {
        if (e.response?.statusCode == 401) {
          await _clearTokens();
          throw Exception(
              "Ваша сессия в приложении истекла, пожалуйста, войдите снова");
        }

        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.connectionError) {
          throw Exception("Ошибка подключения к серверу");
        }
      }

      throw Exception("Ошибка обновления токена: $e");
    }
  }

  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: 'access_token');
  }

  /// Проверяет, нужно ли обновить токен
  Future<bool> shouldRefreshToken() async {
    try {
      final tokenRefreshedAt =
          await _secureStorage.read(key: 'token_refreshed_at');
      if (tokenRefreshedAt == null) {
        // Если токен никогда не обновлялся, проверяем время создания
        return true;
      }

      final lastRefresh = DateTime.parse(tokenRefreshedAt);
      final now = DateTime.now();

      // Проверяем, прошло ли больше 45 минут с последнего обновления
      // (токен живет 60 минут, обновляем заранее)
      return now.difference(lastRefresh).inMinutes >= 45;
    } catch (e) {
      return true; // В случае ошибки лучше обновить токен
    }
  }

  Future<String?> getCurrentUsername() async {
    // В стандартной авторизации имя пользователя не сохраняется отдельно
    // Можно получить из токена или оставить null
    return null;
  }

  Future<void> logout() async {
    await _clearTokens();
  }

  Future<void> _clearTokens() async {
    await _secureStorage.delete(key: 'access_token');
    await _secureStorage.delete(key: 'refresh_token');
    await _secureStorage.delete(key: 'isLoggedIn');
    await _secureStorage.delete(key: 'token_refreshed_at');
  }

  Dio get dio => _dio;
}
