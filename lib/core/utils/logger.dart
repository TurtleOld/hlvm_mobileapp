import 'package:flutter/foundation.dart';

/// Простой класс Logger для совместимости
class Logger {
  static void info(String message) => AppLogger.info(message);
  static void warning(String message) => AppLogger.warning(message);
  static void error(String message) => AppLogger.error(message);
  static void debug(String message) => AppLogger.debug(message);
}

/// Современная утилита для логирования
class AppLogger {
  static const String _tag = '[HLVM]';

  /// Логирование отладочной информации
  static void debug(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      _log('DEBUG', message, error, stackTrace);
    }
  }

  /// Логирование информационных сообщений
  static void info(String message, [Object? error, StackTrace? stackTrace]) {
    _log('INFO', message, error, stackTrace);
  }

  /// Логирование предупреждений
  static void warning(String message, [Object? error, StackTrace? stackTrace]) {
    _log('WARNING', message, error, stackTrace);
  }

  /// Логирование ошибок
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log('ERROR', message, error, stackTrace);
  }

  /// Логирование критических ошибок
  static void critical(String message,
      [Object? error, StackTrace? stackTrace]) {
    _log('CRITICAL', message, error, stackTrace);
  }

  /// Внутренний метод логирования
  static void _log(String level, String message,
      [Object? error, StackTrace? stackTrace]) {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '$_tag [$level] [$timestamp] $message';

    if (kDebugMode) {
      debugPrint(logMessage);
      if (error != null) {
        debugPrint('Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('StackTrace: $stackTrace');
      }
    }
  }

  /// Логирование производительности
  static void performance(String operation, Duration duration) {
    if (kDebugMode) {
      _log('PERFORMANCE', '$operation took ${duration.inMilliseconds}ms');
    }
  }

  /// Логирование сетевых запросов
  static void network(String method, String url,
      {int? statusCode, String? response}) {
    if (kDebugMode) {
      final status = statusCode != null ? ' [$statusCode]' : '';
      final responseInfo =
          response != null ? ' - ${response.length} bytes' : '';
      _log('NETWORK', '$method $url$status$responseInfo');
    }
  }
}
