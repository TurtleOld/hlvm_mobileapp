import 'package:talker/talker.dart';
import 'package:flutter/material.dart';

class TalkerService {
  static final TalkerService _instance = TalkerService._internal();
  factory TalkerService() => _instance;
  TalkerService._internal();

  late final Talker _talker;

  void initialize() {
    _talker = Talker(
      settings: TalkerSettings(
        useConsoleLogs: true,
        useHistory: true,
        maxHistoryItems: 100,
      ),
    );
  }

  Talker get talker => _talker;

  /// Логирование информационных сообщений
  void info(String message) {
    _talker.info(message);
  }

  /// Логирование предупреждений
  void warning(String message) {
    _talker.warning(message);
  }

  /// Логирование ошибок
  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _talker.error(message, error, stackTrace);
  }

  /// Логирование критических ошибок
  void critical(String message, [dynamic error, StackTrace? stackTrace]) {
    _talker.critical(message, error, stackTrace);
  }

  /// Показать дружелюбное сообщение об ошибке пользователю
  void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Закрыть',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Показать дружелюбное сообщение об успехе пользователю
  void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Закрыть',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Показать предупреждение пользователю
  void showWarning(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Закрыть',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Обработка ошибок API с дружелюбными сообщениями
  String getFriendlyErrorMessage(dynamic error) {
    if (error is String) {
      return error;
    }

    // Обработка сетевых ошибок
    if (error.toString().contains('SocketException') ||
        error.toString().contains('NetworkException')) {
      return 'Ошибка подключения к серверу. Проверьте интернет-соединение.';
    }

    // Ошибки авторизации
    if (error.toString().contains('401') ||
        error.toString().contains('Unauthorized')) {
      return 'Сессия истекла. Войдите в систему заново.';
    }

    // Ошибки сервера
    if (error.toString().contains('500') ||
        error.toString().contains('Internal Server Error')) {
      return 'Ошибка сервера. Попробуйте позже.';
    }

    // Ошибки валидации
    if (error.toString().contains('400') ||
        error.toString().contains('Bad Request')) {
      return 'Неверные данные. Проверьте введенную информацию.';
    }

    // Ошибки "не найдено"
    if (error.toString().contains('404') ||
        error.toString().contains('Not Found')) {
      return 'Запрашиваемые данные не найдены.';
    }

    // Общая ошибка
    return 'Произошла ошибка. Попробуйте еще раз.';
  }

  /// Получить историю логов
  List<TalkerData> getHistory() {
    return _talker.history;
  }

  /// Очистить историю логов
  void clearHistory() {
    // Talker не имеет прямого метода очистки истории
    // Можно создать новый экземпляр или использовать dispose
    _talker = Talker(
      settings: TalkerSettings(
        useConsoleLogs: true,
        useHistory: true,
        maxHistoryItems: 100,
      ),
    );
  }
}
