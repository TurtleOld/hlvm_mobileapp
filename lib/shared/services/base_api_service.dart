import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/request_deduplicator.dart';

abstract class BaseApiService {
  final Dio _dio = Dio();
  final SharedPreferences _prefs;

  BaseApiService(this._prefs) {
    _setupInterceptors();
  }

  void _setupInterceptors() {
    // Добавляем interceptor для дедупликации запросов
    _dio.interceptors.add(RequestDeduplicationInterceptor());

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final accessToken = await _getAccessToken();
          if (accessToken != null) {
            options.headers['Authorization'] = 'Bearer $accessToken';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            try {
              await _refreshToken();
              final newAccessToken = await _getAccessToken();
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
    final server = _prefs.getString(AppConstants.serverAddressKey);
    if (server != null && server.isNotEmpty) {
      return server.endsWith('/api') ? server : '$server/api';
    }
    throw Exception(AppConstants.serverAddressRequired);
  }

  Future<String?> _getAccessToken() async {
    return _prefs.getString(AppConstants.accessTokenKey);
  }

  Future<void> _refreshToken() async {
    final refreshToken = _prefs.getString(AppConstants.refreshTokenKey);
    if (refreshToken == null) {
      throw Exception("Refresh token is missing");
    }

    try {
      final baseUrl = await _baseUrl;
      final response = await _dio.post(
        '$baseUrl${AppConstants.authRefreshEndpoint}',
        data: {"refresh": refreshToken},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      final newAccessToken = response.data['access'];
      await _prefs.setString(AppConstants.accessTokenKey, newAccessToken);
    } catch (e) {
      await _clearTokens();
      throw Exception(
          "Ваша сессия в приложении истекла, пожалуйста, войдите снова");
    }
  }

  Future<void> _clearTokens() async {
    await _prefs.remove(AppConstants.accessTokenKey);
    await _prefs.remove(AppConstants.refreshTokenKey);
    await _prefs.remove(AppConstants.isLoggedInKey);
  }

  Dio get dio => _dio;
  Future<String> get baseUrl => _baseUrl;
}
