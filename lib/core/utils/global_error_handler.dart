import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:hlvm_mobileapp/services/authentication.dart';
import 'package:hlvm_mobileapp/core/utils/error_handler.dart';
import 'package:hlvm_mobileapp/core/constants/app_constants.dart';

class GlobalErrorHandler {
  static final GlobalErrorHandler _instance = GlobalErrorHandler._internal();
  factory GlobalErrorHandler() => _instance;
  GlobalErrorHandler._internal();

  /// Глобальный обработчик ошибок для Dio
  static void setupDioErrorHandler(Dio dio) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            // Очищаем токены при ошибке авторизации
            await _clearTokens();

            // Если есть контекст, показываем дружелюбное сообщение
            if (error.requestOptions.extra.containsKey('context')) {
              final context =
                  error.requestOptions.extra['context'] as BuildContext?;
              if (context != null && context.mounted) {
                ErrorHandler.showSessionExpiredSnackBar(context);
              }
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  /// Обработка ошибок в BLoC
  static String handleBlocError(dynamic error) {
    // Проверяем на ошибки о не настроенном сервере
    if (error.toString().contains('Необходимо указать адрес сервера') ||
        error.toString().contains(AppConstants.serverAddressRequired)) {
      return AppConstants.serverAddressRequired;
    }

    if (error is DioException) {
      if (error.response?.statusCode == 401) {
        return AppConstants.sessionExpired;
      }

      // Обработка других HTTP ошибок
      if (error.response?.statusCode != null) {
        final statusCode = error.response!.statusCode!;
        if (statusCode >= 400 && statusCode < 500) {
          return 'Ошибка клиента: ${error.response?.data?['detail'] ?? 'Неверный запрос'}';
        } else if (statusCode >= 500) {
          return 'Ошибка сервера: попробуйте позже';
        }
      }

      // Обработка сетевых ошибок
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return 'Превышено время ожидания соединения';
      }

      if (error.type == DioExceptionType.connectionError) {
        return 'Ошибка подключения к серверу';
      }
    }

    // Проверяем на ошибки сессии в тексте ошибки
    if (error.toString().contains('Сессия истекла') ||
        error.toString().contains('session expired') ||
        error.toString().contains('token expired') ||
        error.toString().contains('unauthorized') ||
        error.toString().contains('401')) {
      return AppConstants.sessionExpired;
    }

    return error.toString();
  }

  /// Показ ошибки сессии с автоматическим переходом на экран входа
  static void showSessionExpiredError(BuildContext context) {
    if (!context.mounted) return;

    // Показываем диалог с дружелюбным сообщением
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppConstants.sessionExpiredTitle),
          content: Text(AppConstants.sessionExpired),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Переходим на экран входа
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login',
                  (route) => false,
                );
              },
              child: Text(AppConstants.sessionExpiredAction),
            ),
          ],
        );
      },
    );
  }

  /// Очистка токенов при истечении сессии
  static Future<void> _clearTokens() async {
    final authService = AuthService();
    await authService.logout();
  }

  /// Проверка, является ли ошибка ошибкой сессии
  static bool isSessionExpiredError(dynamic error) {
    if (error is DioException && error.response?.statusCode == 401) {
      return true;
    }

    final errorString = error.toString().toLowerCase();
    return errorString.contains('сессия истекла') ||
        errorString.contains('session expired') ||
        errorString.contains('token expired') ||
        errorString.contains('unauthorized') ||
        errorString.contains('401');
  }
}
