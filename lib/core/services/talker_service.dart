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

  void info(String message) {
    _talker.info(message);
  }

  void warning(String message) {
    _talker.warning(message);
  }

  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _talker.error(message, error, stackTrace);
  }

  void critical(String message, [dynamic error, StackTrace? stackTrace]) {
    _talker.critical(message, error, stackTrace);
  }

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

  String getFriendlyErrorMessage(dynamic error) {
    if (error is String) {
      return error;
    }

    if (error.toString().contains('SocketException') ||
        error.toString().contains('NetworkException')) {
      return 'Ошибка подключения к серверу. Проверьте интернет-соединение.';
    }

    if (error.toString().contains('401') ||
        error.toString().contains('Unauthorized')) {
      return 'Ваша сессия в приложении истекла, пожалуйста, войдите снова';
    }

    if (error.toString().contains('500') ||
        error.toString().contains('Internal Server Error')) {
      return 'Ошибка сервера. Попробуйте позже.';
    }

    if (error.toString().contains('400') ||
        error.toString().contains('Bad Request')) {
      return 'Неверные данные. Проверьте введенную информацию.';
    }

    if (error.toString().contains('404') ||
        error.toString().contains('Not Found')) {
      return 'Запрашиваемые данные не найдены.';
    }

    return 'Произошла ошибка. Попробуйте еще раз.';
  }

  List<TalkerData> getHistory() {
    return _talker.history;
  }

  void clearHistory() {
    _talker = Talker(
      settings: TalkerSettings(
        useConsoleLogs: true,
        useHistory: true,
        maxHistoryItems: 100,
      ),
    );
  }
}
