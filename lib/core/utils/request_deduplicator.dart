import 'package:dio/dio.dart';

/// Утилита для дедупликации HTTP запросов
/// Предотвращает отправку одинаковых запросов одновременно
class RequestDeduplicator {
  static final Map<String, Future<Response>> _pendingRequests = {};

  /// Генерирует ключ для запроса на основе URL и параметров
  static String generateRequestKey(RequestOptions options) {
    final url = options.uri.toString();
    final method = options.method;
    final data = options.data?.toString() ?? '';
    final queryParameters = options.queryParameters.toString();

    return '$method:$url:$data:$queryParameters';
  }

  /// Выполняет запрос с дедупликацией
  /// Если такой же запрос уже выполняется, возвращает существующий Future
  static Future<Response> executeRequest(
    Dio dio,
    RequestOptions options,
  ) async {
    final requestKey = generateRequestKey(options);

    // Если запрос уже выполняется, возвращаем существующий Future
    if (_pendingRequests.containsKey(requestKey)) {
      return _pendingRequests[requestKey]!;
    }

    // Создаем новый запрос
    final future = dio.fetch(options);
    _pendingRequests[requestKey] = future;

    try {
      final response = await future;
      return response;
    } finally {
      // Удаляем запрос из списка выполненных
      _pendingRequests.remove(requestKey);
    }
  }

  /// Очищает все pending запросы
  static void clearPendingRequests() {
    _pendingRequests.clear();
  }

  /// Возвращает количество pending запросов
  static int get pendingRequestsCount => _pendingRequests.length;

  /// Проверяет, есть ли pending запросы
  static bool get hasPendingRequests => _pendingRequests.isNotEmpty;
}

/// Dio interceptor для автоматической дедупликации запросов
class RequestDeduplicationInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Для GET запросов применяем дедупликацию
    if (options.method == 'GET') {
      final requestKey = RequestDeduplicator.generateRequestKey(options);

      if (RequestDeduplicator._pendingRequests.containsKey(requestKey)) {
        // Если запрос уже выполняется, ждем его завершения
        try {
          final response =
              await RequestDeduplicator._pendingRequests[requestKey]!;
          handler.resolve(response);
          return;
        } catch (e) {
          // Если запрос завершился с ошибкой, продолжаем с новым запросом
          RequestDeduplicator._pendingRequests.remove(requestKey);
        }
      }
    }

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // Удаляем запрос из pending после успешного завершения
    final requestKey =
        RequestDeduplicator.generateRequestKey(response.requestOptions);
    RequestDeduplicator._pendingRequests.remove(requestKey);

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Удаляем запрос из pending после ошибки
    final requestKey =
        RequestDeduplicator.generateRequestKey(err.requestOptions);
    RequestDeduplicator._pendingRequests.remove(requestKey);

    handler.next(err);
  }
}
