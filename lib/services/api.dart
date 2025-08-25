import 'dart:async';
import 'package:dio/dio.dart';
import 'package:hlvm_mobileapp/models/finance_account_model.dart';
import 'package:hlvm_mobileapp/core/services/server_settings_service.dart';

import 'authentication.dart';

class ApiService {
  final Dio _dio = Dio();
  final AuthService _authService = AuthService();
  final ServerSettingsService _serverSettings = ServerSettingsService();

  ApiService() {
    // Используем interceptor из AuthService вместо дублирования
    _dio.interceptors.addAll(_authService.dio.interceptors);
  }

  Future<String?> get _baseUrl async {
    final serverUrl = await _serverSettings.getFullServerUrl();
    if (serverUrl != null && serverUrl.isNotEmpty) {
      // Проверяем корректность URL
      if (serverUrl.length > 200 ||
          serverUrl.contains(' ') ||
          serverUrl.contains('\n')) {
        return null; // Возвращаем null вместо исключения
      }
      return serverUrl;
    }
    return null; // Возвращаем null вместо исключения
  }

  Future<String?> get _baseServerUrl async {
    final serverUrl = await _serverSettings.getFullServerUrl();
    if (serverUrl != null && serverUrl.isNotEmpty) {
      // Проверяем корректность URL
      if (serverUrl.length > 200 ||
          serverUrl.contains(' ') ||
          serverUrl.contains('\n')) {
        return null; // Возвращаем null вместо исключения
      }
      return serverUrl;
    }
    return null; // Возвращаем null вместо исключения
  }

  /// Проверяет доступность сервера
  Future<bool> checkServerHealth() async {
    try {
      final baseUrl = await _baseServerUrl;
      if (baseUrl == null) {
        return false; // Сервер не настроен
      }

      final timeout = await _serverSettings.getTimeout() ?? 30;

      final response = await _dio.get(
        '$baseUrl/health/',
        options: Options(
          sendTimeout: Duration(seconds: timeout),
          receiveTimeout: Duration(seconds: timeout),
        ),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Получает информацию о сервере
  Future<Map<String, dynamic>?> getServerInfo() async {
    try {
      final baseUrl = await _baseServerUrl;
      if (baseUrl == null) {
        return null; // Сервер не настроен
      }

      final timeout = await _serverSettings.getTimeout() ?? 30;

      final response = await _dio.get(
        '$baseUrl/info/',
        options: Options(
          sendTimeout: Duration(seconds: timeout),
          receiveTimeout: Duration(seconds: timeout),
        ),
      );

      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Очищает некорректные настройки сервера
  Future<void> clearInvalidServerSettings() async {
    try {
      await _serverSettings.clearInvalidSettings();
    } catch (e) {
      // Игнорируем ошибки очистки настроек
    }
  }

  /// Проверяет, настроен ли сервер
  Future<bool> checkServerConfiguration() async {
    try {
      final baseUrl = await _baseUrl;
      return baseUrl != null;
    } catch (e) {
      return false;
    }
  }

  /// Получает сообщение о состоянии настроек сервера
  Future<String> getServerConfigurationMessage() async {
    try {
      final baseUrl = await _baseUrl;
      if (baseUrl == null) {
        return 'Необходимо указать адрес сервера в настройках';
      }
      return 'Сервер настроен: $baseUrl';
    } catch (e) {
      return 'Ошибка проверки настроек сервера';
    }
  }

  Future<List> listReceipt() async {
    try {
      final baseUrl = await _baseUrl;
      if (baseUrl == null) {
        throw Exception("Необходимо указать адрес сервера в настройках");
      }

      final timeout = await _serverSettings.getTimeout() ?? 30;
      final retryAttempts = await _serverSettings.getMaxRetries() ?? 3;

      final response = await _makeRequestWithRetry(
        () => _dio.get(
          '$baseUrl/receipts/list/',
          options: Options(
            sendTimeout: Duration(seconds: timeout),
            receiveTimeout: Duration(seconds: timeout),
          ),
        ),
        retryAttempts,
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception("Failed to load receipts");
      }
    } catch (e) {
      throw Exception("Error: $e");
    }
  }

  Future<Map<String, dynamic>> getSeller(int sellerId) async {
    try {
      final baseUrl = await _baseUrl;
      if (baseUrl == null) {
        throw Exception("Необходимо указать адрес сервера в настройках");
      }

      final timeout = await _serverSettings.getTimeout() ?? 30;
      final retryAttempts = await _serverSettings.getMaxRetries() ?? 3;

      final response = await _makeRequestWithRetry(
        () => _dio.get(
          '$baseUrl/receipts/seller/$sellerId',
          options: Options(
            sendTimeout: Duration(seconds: timeout),
            receiveTimeout: Duration(seconds: timeout),
          ),
        ),
        retryAttempts,
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception("Failed to load receipts");
      }
    } catch (e) {
      throw Exception("Error: $e");
    }
  }

  Future<String> createReceipt(Map<String, dynamic> jsonData) async {
    try {
      final baseUrl = await _baseUrl;
      if (baseUrl == null) {
        return "Необходимо указать адрес сервера в настройках";
      }

      final timeout = await _serverSettings.getTimeout() ?? 30;
      final retryAttempts = await _serverSettings.getMaxRetries() ?? 3;

      final response = await _makeRequestWithRetry(
        () => _dio.post(
          '$baseUrl/receipts/create-receipt/',
          data: jsonData,
          options: Options(
            headers: {
              'Content-Type': 'application/json',
            },
            sendTimeout: Duration(seconds: timeout),
            receiveTimeout: Duration(seconds: timeout),
          ),
        ),
        retryAttempts,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return 'Чек успешно добавлен!';
      } else {
        if (response.data != null) {
          if (response.data is Map && response.data['detail'] != null) {
            return response.data['detail'].toString();
          }
          return response.data.toString();
        }
        return 'Чек не был добавлен, повторите попытку!';
      }
    } catch (e) {
      if (e is DioException) {
        // Обработка ошибок авторизации
        if (e.response?.statusCode == 401) {
          return 'Ошибка авторизации. Попробуйте войти заново.';
        }

        if (e.response?.data != null) {
          final data = e.response?.data;
          if (data is Map && data['detail'] != null) {
            return data['detail'].toString();
          }
          return data.toString();
        }

        // Обработка сетевых ошибок
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout) {
          return 'Ошибка подключения к серверу. Проверьте интернет-соединение.';
        }

        if (e.type == DioExceptionType.connectionError) {
          return 'Не удалось подключиться к серверу. Проверьте адрес сервера.';
        }
      }
      return 'Ошибка: $e';
    }
  }

  Future<List<FinanceAccount>> fetchFinanceAccount() async {
    try {
      final baseUrl = await _baseUrl;
      if (baseUrl == null) {
        throw Exception("Необходимо указать адрес сервера в настройках");
      }

      final timeout = await _serverSettings.getTimeout() ?? 30;
      final retryAttempts = await _serverSettings.getMaxRetries() ?? 3;

      final response = await _makeRequestWithRetry(
        () => _dio.get(
          '$baseUrl/finaccount/list/',
          options: Options(
            sendTimeout: Duration(seconds: timeout),
            receiveTimeout: Duration(seconds: timeout),
          ),
        ),
        retryAttempts,
      );

      if (response.statusCode == 200) {
        List<dynamic> data = response.data;
        return data.map((json) => FinanceAccount.fromJson(json)).toList();
      } else {
        throw Exception("Failed to load accounts");
      }
    } catch (e) {
      if (e is DioException) {
        // Если это ошибка авторизации, пробрасываем её как есть
        if (e.response?.statusCode == 401) {
          rethrow;
        }

        // Для других ошибок формируем понятное сообщение
        if (e.response?.data != null) {
          final data = e.response?.data;
          if (data is Map && data['detail'] != null) {
            throw Exception(data['detail'].toString());
          }
          throw Exception(data.toString());
        }

        // Обработка сетевых ошибок
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout) {
          throw Exception('Превышено время ожидания соединения');
        }

        if (e.type == DioExceptionType.connectionError) {
          throw Exception('Ошибка подключения к серверу');
        }
      }

      throw Exception("Error: $e");
    }
  }

  /// Выполняет запрос с повторными попытками
  Future<Response> _makeRequestWithRetry(
    Future<Response> Function() request,
    int maxRetries,
  ) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        return await request();
      } catch (e) {
        attempts++;
        if (attempts >= maxRetries) {
          rethrow;
        }

        // Ждем перед повторной попыткой (экспоненциальная задержка)
        await Future.delayed(Duration(seconds: attempts * 2));
      }
    }
    throw Exception('Превышено максимальное количество попыток');
  }

  /// Получает текущие настройки сервера
  Future<Map<String, dynamic>> getServerSettings() async {
    return {
      'address': await _serverSettings.getServerAddress(),
      'port': await _serverSettings.getServerPort(),
      'protocol': await _serverSettings.getServerProtocol(),
      'timeout': await _serverSettings.getTimeout(),
      'maxRetries': await _serverSettings.getMaxRetries(),
      'healthCheck': await _serverSettings.getHealthCheckEnabled(),
      'version': await _serverSettings.getServerVersion(),
    };
  }

  /// Проверяет, настроен ли сервер
  Future<bool> isServerConfigured() async {
    final address = await _serverSettings.getServerAddress();
    return address != null && address.isNotEmpty;
  }

  /// Валидирует настройки сервера
  Future<bool> validateServerSettings() async {
    final address = await _serverSettings.getServerAddress();
    final port = await _serverSettings.getServerPort();
    return address != null &&
        address.isNotEmpty &&
        port != null &&
        port > 0 &&
        port <= 65535;
  }
}
