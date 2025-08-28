import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hlvm_mobileapp/models/finance_account_model.dart';
import 'package:hlvm_mobileapp/core/services/server_settings_service.dart';

import 'authentication.dart';

class ApiService {
  final Dio _dio = Dio();
  final AuthService _authService = AuthService();
  final ServerSettingsService _serverSettings = ServerSettingsService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  ApiService() {
    // Используем interceptor из AuthService вместо дублирования
    _dio.interceptors.addAll(_authService.dio.interceptors);
  }

  /// Создает отдельный Dio клиент для GitHub AI API с GitHub token
  Dio _createGithubApiClient() {
    final dio = Dio();
    dio.options.connectTimeout = const Duration(seconds: 60);
    dio.options.receiveTimeout = const Duration(seconds: 120);
    dio.options.sendTimeout = const Duration(seconds: 60);
    
    // Настраиваем validateStatus чтобы не выбрасывать исключения для 4xx ошибок
    dio.options.validateStatus = (status) {
      return status != null && status < 500; // Принимаем все статусы меньше 500
    };
    
    return dio;
  }

  /// Выполняет запрос к GitHub AI API с GitHub token
  Future<Response> postToGithubAI(String url, dynamic data) async {
    final githubToken = await _secureStorage.read(key: 'github_token');

    if (githubToken == null || githubToken.isEmpty) {
      throw Exception('GitHub API токен не настроен');
    }

    // Проверяем формат токена (поддерживаем оба формата: старый ghp_ и новый github_pat_)
    if (!githubToken.startsWith('ghp_') &&
        !githubToken.startsWith('github_pat_')) {
      throw Exception(
          'GitHub API токен имеет неправильный формат. Должен начинаться с ghp_ или github_pat_');
    }

    final dio = _createGithubApiClient();

    return await dio.post(
      url,
      data: data,
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $githubToken',
        },
      ),
    );
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

      // Добавляем /api к базовому URL, если его нет
      String baseUrl = serverUrl;
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

      final timeout = await _serverSettings.getTimeout() ?? 120;

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

      final timeout = await _serverSettings.getTimeout() ?? 120;

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

      final timeout = await _serverSettings.getTimeout() ?? 120;
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

      final timeout = await _serverSettings.getTimeout() ?? 120;
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

  Future<Map<String, dynamic>> createReceipt(
      Map<String, dynamic> jsonData) async {
    try {
      print('DEBUG: createReceipt called with data: ${jsonData.keys.toList()}');
      print('DEBUG: Full JSON data: $jsonData');

      // Детальное логирование каждого поля
      print('DEBUG: === JSON FIELD DETAILS ===');
      jsonData.forEach((key, value) {
        print('DEBUG: $key: $value (type: ${value.runtimeType})');
        if (value is List) {
          print('DEBUG:   $key is List with ${value.length} items');
          for (int i = 0; i < value.length && i < 3; i++) {
            print('DEBUG:     item $i: ${value[i]}');
          }
          if (value.length > 3) {
            print('DEBUG:     ... and ${value.length - 3} more items');
          }
        }
      });
      print('DEBUG: === END JSON FIELD DETAILS ===');

      final baseUrl = await _baseUrl;
      if (baseUrl == null) {
        print('DEBUG: Server URL is null');
        return {
          'success': false,
          'message': "Необходимо указать адрес сервера в настройках",
          'receipt_id': null,
        };
      }

      print('DEBUG: Using base URL: $baseUrl');
      final timeout = await _serverSettings.getTimeout() ?? 120;
      final retryAttempts = await _serverSettings.getMaxRetries() ?? 3;

      print('DEBUG: Making POST request to: $baseUrl/receipts/create-receipt/');
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

      print('DEBUG: Response status code: ${response.statusCode}');
      print('DEBUG: Response data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('DEBUG: Receipt created successfully');
        
        // Извлекаем ID чека из ответа сервера
        int? receiptId;
        if (response.data is Map) {
          receiptId = response.data['id'] ?? response.data['receipt_id'];
        }

        return {
          'success': true,
          'message': 'Чек успешно добавлен!',
          'receipt_id': receiptId,
        };
      } else {
        print(
            'DEBUG: Receipt creation failed with status: ${response.statusCode}');
        String errorMessage = 'Чек не был добавлен, повторите попытку!';
        if (response.data != null) {
          if (response.data is Map && response.data['detail'] != null) {
            errorMessage = response.data['detail'].toString();
          } else {
            errorMessage = response.data.toString();
          }
        }
        return {
          'success': false,
          'message': errorMessage,
          'receipt_id': null,
        };
      }
    } catch (e) {
      print('DEBUG: Exception in createReceipt: $e');
      if (e is DioException) {
        // Обработка ошибок авторизации
        if (e.response?.statusCode == 401) {
          return {
            'success': false,
            'message': 'Ошибка авторизации. Попробуйте войти заново.',
            'receipt_id': null,
          };
        }

        if (e.response?.data != null) {
          final data = e.response?.data;
          String errorMessage;
          if (data is Map && data['detail'] != null) {
            errorMessage = data['detail'].toString();
          } else {
            errorMessage = data.toString();
          }
          return {
            'success': false,
            'message': errorMessage,
            'receipt_id': null,
          };
        }

        // Обработка сетевых ошибок
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout) {
          return {
            'success': false,
            'message':
                'Ошибка подключения к серверу. Проверьте интернет-соединение.',
            'receipt_id': null,
          };
        }

        if (e.type == DioExceptionType.connectionError) {
          return {
            'success': false,
            'message':
                'Не удалось подключиться к серверу. Проверьте адрес сервера.',
            'receipt_id': null,
          };
        }
      }
      return {
        'success': false,
        'message': 'Ошибка: $e',
        'receipt_id': null,
      };
    }
  }

  Future<Map<String, dynamic>> deleteReceipt(int receiptId) async {
    try {
      final baseUrl = await _baseUrl;
      if (baseUrl == null) {
        return {
          'success': false,
          'message': "Необходимо указать адрес сервера в настройках",
        };
      }

      final timeout = await _serverSettings.getTimeout() ?? 120;
      final retryAttempts = await _serverSettings.getMaxRetries() ?? 3;

      print(
          'DEBUG: Making DELETE request to: $baseUrl/receipts/delete/$receiptId');
      final response = await _makeRequestWithRetry(
        () => _dio.delete(
          '$baseUrl/receipts/delete/$receiptId',
          options: Options(
            sendTimeout: Duration(seconds: timeout),
            receiveTimeout: Duration(seconds: timeout),
          ),
        ),
        retryAttempts,
      );

      print('DEBUG: Delete response status code: ${response.statusCode}');
      print('DEBUG: Delete response data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        return {
          'success': true,
          'message': 'Чек успешно удален!',
        };
      } else {
        String errorMessage = 'Не удалось удалить чек';
        if (response.data != null) {
          if (response.data is Map && response.data['detail'] != null) {
            errorMessage = response.data['detail'].toString();
          } else {
            errorMessage = response.data.toString();
          }
        }
        return {
          'success': false,
          'message': errorMessage,
        };
      }
    } catch (e) {
      print('DEBUG: Exception in deleteReceipt: $e');
      if (e is DioException) {
        if (e.response?.statusCode == 401) {
          return {
            'success': false,
            'message': 'Ошибка авторизации. Попробуйте войти заново.',
          };
        }

        if (e.response?.statusCode == 404) {
          return {
            'success': false,
            'message': 'Чек не найден',
          };
        }

        if (e.response?.data != null) {
          final data = e.response?.data;
          String errorMessage;
          if (data is Map && data['detail'] != null) {
            errorMessage = data['detail'].toString();
          } else {
            errorMessage = data.toString();
          }
          return {
            'success': false,
            'message': errorMessage,
          };
        }

        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout) {
          return {
            'success': false,
            'message':
                'Ошибка подключения к серверу. Проверьте интернет-соединение.',
          };
        }

        if (e.type == DioExceptionType.connectionError) {
          return {
            'success': false,
            'message':
                'Не удалось подключиться к серверу. Проверьте адрес сервера.',
          };
        }
      }
      return {
        'success': false,
        'message': 'Ошибка: $e',
      };
    }
  }

  Future<List<FinanceAccount>> fetchFinanceAccount() async {
    try {
      final baseUrl = await _baseUrl;
      if (baseUrl == null) {
        throw Exception("Необходимо указать адрес сервера в настройках");
      }

      final timeout = await _serverSettings.getTimeout() ?? 120;
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

  /// Получает Dio клиент с настроенными интерцепторами
  Dio get dio => _dio;

  /// Получает базовый URL с /api суффиксом
  Future<String?> get baseUrl => _baseUrl;
}
