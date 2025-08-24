import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hlvm_mobileapp/core/services/session_manager.dart';
import 'package:hlvm_mobileapp/core/services/server_settings_service.dart';
import 'package:hlvm_mobileapp/core/constants/app_constants.dart';

import 'package:talker/talker.dart';

/// Безопасный HTTP клиент с защитой от Session Fixation
class SecureHttpClient {
  final http.Client _httpClient;
  final SessionManager _sessionManager;
  final FlutterSecureStorage _secureStorage;
  final ServerSettingsService _serverSettings;
  final Talker _logger;

  final String? _baseUrl;

  static const Duration _requestTimeout =
      Duration(milliseconds: AppConstants.defaultApiTimeout);
  static const Duration _retryDelay = Duration(seconds: 1);
  static const int _maxRetries = 3;

  SecureHttpClient({
    required SessionManager sessionManager,
    String? baseUrl,
    http.Client? httpClient,
    FlutterSecureStorage? secureStorage,
    ServerSettingsService? serverSettings,
    Talker? logger,
  })  : _sessionManager = sessionManager,
        _baseUrl = baseUrl,
        _httpClient = httpClient ?? http.Client(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _serverSettings = serverSettings ?? ServerSettingsService(),
        _logger = logger ?? Talker();

  /// Проверяет, настроен ли сервер
  Future<bool> isServerConfigured() async {
    try {
      return await _serverSettings.isServerConfigured();
    } catch (e) {
      _logger.error('Ошибка проверки настроек сервера: $e');
      return false;
    }
  }

  /// Получает базовый URL сервера из настроек
  Future<String?> getServerBaseUrl() async {
    try {
      if (_baseUrl != null) {
        return _baseUrl;
      }
      return await _serverSettings.getFullServerUrl();
    } catch (e) {
      _logger.error('Ошибка получения URL сервера: $e');
      return null;
    }
  }

  /// Проверяет доступность сервера
  Future<bool> checkServerAvailability() async {
    try {
      final serverUrl = await getServerBaseUrl();
      if (serverUrl == null) {
        return false;
      }

      final response = await _httpClient
          .get(Uri.parse('$serverUrl/health'))
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      _logger.warning('Сервер недоступен: $e');
      return false;
    }
  }

  Future<http.Response> get(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    return _executeRequest(
      'GET',
      endpoint,
      headers: headers,
      queryParameters: queryParameters,
    );
  }

  Future<http.Response> post(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    Object? body,
  }) async {
    return _executeRequest(
      'POST',
      endpoint,
      headers: headers,
      queryParameters: queryParameters,
      body: body,
    );
  }

  Future<http.Response> put(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    Object? body,
  }) async {
    return _executeRequest(
      'PUT',
      endpoint,
      headers: headers,
      queryParameters: queryParameters,
      body: body,
    );
  }

  Future<http.Response> delete(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    Object? body,
  }) async {
    return _executeRequest(
      'DELETE',
      endpoint,
      headers: headers,
      queryParameters: queryParameters,
      body: body,
    );
  }

  /// Выполнение PATCH запроса с защитой сессии
  Future<http.Response> patch(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    Object? body,
  }) async {
    return _executeRequest(
      'PATCH',
      endpoint,
      headers: headers,
      queryParameters: queryParameters,
      body: body,
    );
  }

  Future<http.Response> _executeRequest(
    String method,
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    Object? body,
  }) async {
    int retryCount = 0;

    // Проверяем настройку сервера перед выполнением запросов
    if (!await isServerConfigured()) {
      throw Exception(AppConstants.serverAddressRequired);
    }

    while (retryCount < _maxRetries) {
      try {
        final sessionValidation =
            await _sessionManager.validateCurrentSession();
        if (!sessionValidation.isValid) {
          if (sessionValidation.isExpired) {
            _logger.warning('Сессия истекла, перенаправляем на аутентификацию');
            throw SessionExpiredException('Сессия истекла');
          } else if (sessionValidation.isSuspicious) {
            _logger.warning(
                'Обнаружена подозрительная активность: ${sessionValidation.reason}');
            throw SuspiciousActivityException(
                sessionValidation.reason ?? 'Подозрительная активность');
          } else {
            _logger
                .warning('Сессия недействительна: ${sessionValidation.reason}');
            throw InvalidSessionException(
                sessionValidation.reason ?? 'Сессия недействительна');
          }
        }

        final secureHeaders = await _prepareSecureHeaders(headers);
        final url = await _buildUrl(endpoint, queryParameters);
        final response = await _performHttpRequest(
          method,
          url,
          secureHeaders,
          body,
        );

        await _handleResponse(response, endpoint);
        await _updateSessionActivity();

        return response;
      } catch (e) {
        retryCount++;

        // Если это ошибка о не настроенном сервере, не повторяем попытки
        if (e.toString().contains(AppConstants.serverAddressRequired)) {
          rethrow;
        }

        if (e is SessionExpiredException ||
            e is SuspiciousActivityException ||
            e is InvalidSessionException) {
          rethrow;
        }

        if (retryCount >= _maxRetries) {
          _logger
              .error('Превышено количество попыток для $method $endpoint: $e');
          rethrow;
        }

        _logger.warning(
            'Попытка $retryCount для $method $endpoint не удалась: $e');
        await Future.delayed(_retryDelay * retryCount);
      }
    }

    throw Exception('Не удалось выполнить запрос после $_maxRetries попыток');
  }

  Future<Map<String, String>> _prepareSecureHeaders(
      Map<String, String>? headers) async {
    final secureHeaders = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'HLVM-Mobile-App/1.0',
      ...?headers,
    };

    final sessionInfo = await _sessionManager.getCurrentSessionInfo();
    if (sessionInfo != null) {
      secureHeaders['X-Session-ID'] = sessionInfo.sessionId;
      secureHeaders['X-Device-Fingerprint'] = sessionInfo.deviceFingerprint;
    }

    // Добавляем access token
    final accessToken = await _secureStorage.read(key: 'access_token');
    if (accessToken != null) {
      secureHeaders['Authorization'] = 'Bearer $accessToken';
    }

    // Добавляем временную метку для предотвращения replay атак
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    secureHeaders['X-Request-Timestamp'] = timestamp.toString();

    return secureHeaders;
  }

  Future<Uri> _buildUrl(
      String endpoint, Map<String, dynamic>? queryParameters) async {
    final serverUrl = await getServerBaseUrl();
    if (serverUrl == null) {
      throw Exception(AppConstants.serverAddressRequired);
    }

    final uri = Uri.parse('$serverUrl$endpoint');

    if (queryParameters != null && queryParameters.isNotEmpty) {
      final queryMap = <String, String>{};

      for (final entry in queryParameters.entries) {
        if (entry.value != null) {
          queryMap[entry.key] = entry.value.toString();
        }
      }

      return uri.replace(queryParameters: queryMap);
    }

    return uri;
  }

  Future<http.Response> _performHttpRequest(
    String method,
    Uri url,
    Map<String, String> headers,
    Object? body,
  ) async {
    try {
      final request = http.Request(method, url);
      request.headers.addAll(headers);

      if (body != null) {
        if (body is Map<String, dynamic>) {
          request.body = jsonEncode(body);
        } else if (body is String) {
          request.body = body;
        } else {
          request.body = body.toString();
        }
      }

      final streamedResponse =
          await _httpClient.send(request).timeout(_requestTimeout);
      return await http.Response.fromStream(streamedResponse);
    } catch (e) {
      _logger.error('Ошибка выполнения HTTP запроса: $e');
      rethrow;
    }
  }

  Future<void> _handleResponse(http.Response response, String endpoint) async {
    _logger.info('$endpoint: ${response.statusCode}');

    if (response.statusCode == 401) {
      await _handleUnauthorizedResponse(response);
    } else if (response.statusCode == 403) {
      await _handleForbiddenResponse(response);
    } else if (response.statusCode >= 500) {
      await _handleServerErrorResponse(response);
    }

    await _validateSecurityHeaders(response);
    await _updateTokensFromResponse(response);
  }

  Future<void> _handleUnauthorizedResponse(http.Response response) async {
    _logger.warning('Получен 401 ответ, проверяем токены');

    try {
      final refreshToken = await _secureStorage.read(key: 'refresh_token');
      if (refreshToken != null) {
        final newTokens = await _refreshTokens(refreshToken);
        if (newTokens != null) {
          _logger.info('Токены успешно обновлены');
          return;
        }
      }

      await _sessionManager.forceLogout(
        reason: 'Не удалось обновить токены аутентификации',
        notifyUser: true,
      );
    } catch (e) {
      _logger.error('Ошибка обработки 401 ответа: $e');
      await _sessionManager.forceLogout(
        reason: 'Ошибка обработки ответа аутентификации',
        notifyUser: true,
      );
    }
  }

  /// Обработка 403 ответа
  Future<void> _handleForbiddenResponse(http.Response response) async {
    _logger.warning('Получен 403 ответ - доступ запрещен');

    try {
      // Проверяем, не связана ли ошибка с сессией
      final responseBody = jsonDecode(response.body) as Map<String, dynamic>?;
      final errorCode = responseBody?['error_code'] as String?;

      if (errorCode == 'SESSION_EXPIRED' || errorCode == 'INVALID_SESSION') {
        await _sessionManager.forceLogout(
          reason: 'Сессия отклонена сервером',
          notifyUser: true,
        );
      } else {
        _logger.warning(
            'Ошибка доступа: ${responseBody?['message'] ?? 'Неизвестная ошибка'}');
      }
    } catch (e) {
      _logger.error('Ошибка обработки 403 ответа: $e');
    }
  }

  Future<void> _handleServerErrorResponse(http.Response response) async {
    _logger.error('Ошибка сервера ${response.statusCode}: ${response.body}');

    if (response.statusCode >= 500) {
      await _sessionManager.forceLogout(
        reason: 'Критическая ошибка сервера',
        notifyUser: false,
      );
    }
  }

  Future<void> _validateSecurityHeaders(http.Response response) async {
    try {
      final securityHeaders = response.headers;

      final frameOptions = securityHeaders['x-frame-options'];
      if (frameOptions == null) {
        _logger.warning('Отсутствует заголовок X-Frame-Options');
      }

      final contentTypeOptions = securityHeaders['x-content-type-options'];
      if (contentTypeOptions == null) {
        _logger.warning('Отсутствует заголовок X-Content-Type-Options');
      }

      final hsts = securityHeaders['strict-transport-security'];
      if (hsts == null) {
        _logger.warning('Отсутствует заголовок Strict-Transport-Security');
      }
    } catch (e) {
      _logger.error('Ошибка валидации заголовков безопасности: $e');
    }
  }

  Future<void> _updateTokensFromResponse(http.Response response) async {
    try {
      final responseBody = jsonDecode(response.body) as Map<String, dynamic>?;

      if (responseBody != null) {
        final newAccessToken = responseBody['access_token'] as String?;
        final newRefreshToken = responseBody['refresh_token'] as String?;
        final expiresIn = responseBody['expires_in'] as int?;

        if (newAccessToken != null) {
          await _secureStorage.write(
              key: 'access_token', value: newAccessToken);

          if (expiresIn != null) {
            final expiry = DateTime.now().add(Duration(seconds: expiresIn));
            await _secureStorage.write(
                key: 'token_expiry', value: expiry.toIso8601String());
          }

          _logger.info('Access token обновлен');
        }

        if (newRefreshToken != null) {
          await _secureStorage.write(
              key: 'refresh_token', value: newRefreshToken);
          _logger.info('Refresh token обновлен');
        }
      }
    } catch (e) {
      _logger.error('Ошибка обновления токенов из ответа: $e');
    }
  }

  Future<Map<String, dynamic>?> _refreshTokens(String refreshToken) async {
    try {
      final serverUrl = await getServerBaseUrl();
      if (serverUrl == null) {
        throw Exception(AppConstants.serverAddressRequired);
      }

      final response = await _httpClient
          .post(
            Uri.parse('$serverUrl/auth/refresh'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $refreshToken',
            },
            body: jsonEncode({
              'refresh_token': refreshToken,
            }),
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
        return responseBody;
      } else {
        _logger.warning('Не удалось обновить токены: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _logger.error('Ошибка обновления токенов: $e');
      return null;
    }
  }

  Future<void> _updateSessionActivity() async {
    try {
      final now = DateTime.now();
      await _secureStorage.write(
        key: 'session_last_activity',
        value: now.toIso8601String(),
      );
    } catch (e) {
      _logger.error('Ошибка обновления активности сессии: $e');
    }
  }

  Future<bool> checkConnection() async {
    try {
      final serverUrl = await getServerBaseUrl();
      if (serverUrl == null) {
        return false;
      }

      final response = await _httpClient
          .get(Uri.parse('$serverUrl/health'))
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      _logger.warning('Проверка соединения не удалась: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getClientStatus() async {
    try {
      final sessionInfo = await _sessionManager.getCurrentSessionInfo();
      final hasAccessToken =
          await _secureStorage.read(key: 'access_token') != null;
      final hasRefreshToken =
          await _secureStorage.read(key: 'refresh_token') != null;
      final connectionStatus = await checkConnection();

      return {
        'hasValidSession': sessionInfo != null,
        'sessionId': sessionInfo?.sessionId,
        'sessionExpiresAt': sessionInfo?.expiresAt?.toIso8601String(),
        'hasAccessToken': hasAccessToken,
        'hasRefreshToken': hasRefreshToken,
        'connectionStatus': connectionStatus,
        'baseUrl': _baseUrl,
      };
    } catch (e) {
      return {
        'error': e.toString(),
      };
    }
  }

  void dispose() {
    _httpClient.close();
  }
}

class SessionExpiredException implements Exception {
  final String message;
  SessionExpiredException(this.message);

  @override
  String toString() => 'SessionExpiredException: $message';
}

class SuspiciousActivityException implements Exception {
  final String message;
  SuspiciousActivityException(this.message);

  @override
  String toString() => 'SuspiciousActivityException: $message';
}

class InvalidSessionException implements Exception {
  final String message;
  InvalidSessionException(this.message);

  @override
  String toString() => 'InvalidSessionException: $message';
}
