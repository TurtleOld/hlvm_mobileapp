import 'package:talker/talker.dart';

/// Упрощенный логгер без проверок отладки
class AppLogger {
  static final Talker _talker = Talker();

  /// Логирование информационных сообщений
  static void info(String message) {
    _talker.info(message);
  }

  /// Логирование предупреждений
  static void warning(String message) {
    _talker.warning(message);
  }

  /// Логирование ошибок
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _talker.error(message, error, stackTrace);
  }

  /// Логирование критических ошибок
  static void critical(String message,
      [dynamic error, StackTrace? stackTrace]) {
    _talker.critical(message, error, stackTrace);
  }

  /// Логирование отладочной информации
  static void debug(String message) {
    _talker.debug(message);
  }

  /// Логирование с уровнем
  static void log(String message, {LogLevel level = LogLevel.info}) {
    switch (level) {
      case LogLevel.info:
        info(message);
        break;
      case LogLevel.warning:
        warning(message);
        break;
      case LogLevel.error:
        error(message);
        break;
      case LogLevel.critical:
        critical(message);
        break;
      case LogLevel.debug:
        debug(message);
        break;
    }
  }
}

/// Уровни логирования
enum LogLevel {
  info,
  warning,
  error,
  critical,
  debug,
}
