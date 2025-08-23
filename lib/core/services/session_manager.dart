import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hlvm_mobileapp/services/authentication.dart';
import 'package:hlvm_mobileapp/core/utils/error_handler.dart';

class SessionManager {
  final AuthService _authService;

  SessionManager({required AuthService authService})
      : _authService = authService;

  /// Выход из аккаунта с UI уведомлением
  Future<void> logoutWithUI(BuildContext context) async {
    try {
      await _authService.logout();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Вы успешно вышли из аккаунта')),
        );
      }
    } catch (e) {
      // Fallback: прямая очистка токенов
      await _clearTokensFallback();
    }
  }

  /// Выход из аккаунта при истечении сессии
  Future<void> logoutOnSessionExpired(BuildContext context) async {
    try {
      await _authService.logout();
      if (context.mounted) {
        ErrorHandler.showSessionExpiredSnackBar(context);
      }
    } catch (e) {
      // Fallback: прямая очистка токенов
      await _clearTokensFallback();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сессия истекла. Войдите снова.')),
        );
      }
    }
  }

  /// Проверка аутентификации с UI обработкой
  Future<bool> checkAuthenticationWithUI(BuildContext context) async {
    try {
      const storage = FlutterSecureStorage();
      final accessToken = await storage.read(key: 'access_token');
      if (accessToken == null) {
        if (context.mounted) {
          await logoutOnSessionExpired(context);
        }
        return false;
      }
      return true;
    } catch (e) {
      // В случае ошибки считаем, что аутентификация не прошла
      return false;
    }
  }

  /// Fallback метод для очистки токенов
  Future<void> _clearTokensFallback() async {
    try {
      const storage = FlutterSecureStorage();
      await storage.delete(key: 'access_token');
      await storage.delete(key: 'refresh_token');
      await storage.delete(key: 'isLoggedIn');
    } catch (e) {
      // Игнорируем ошибки при fallback очистке
    }
  }
}
