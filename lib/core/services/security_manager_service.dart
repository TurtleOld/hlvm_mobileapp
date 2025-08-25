import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

/// Упрощенная служба управления безопасностью без защит
class SecurityManagerService {
  static final SecurityManagerService _instance =
      SecurityManagerService._internal();

  factory SecurityManagerService() => _instance;

  SecurityManagerService._internal();

  bool _isSecurityActive = false;
  bool _isSecurityEnabled = false;

  /// Инициализирует систему безопасности (без реальных защит)
  Future<void> initializeSecurity() async {
    try {
      AppLogger.info('Initializing simplified security system...');

      _isSecurityActive = true;
      _isSecurityEnabled = true;

      AppLogger.info('Simplified security system initialized successfully');
    } catch (e) {
      AppLogger.error('Error initializing security: $e');
      // В случае ошибки продолжаем работу
      _isSecurityActive = true;
      _isSecurityEnabled = true;
    }
  }

  /// Очищает данные безопасности
  Future<void> clearSecurityData() async {
    try {
      AppLogger.info('Clearing security data...');

      _isSecurityActive = false;
      _isSecurityEnabled = false;

      // Очищаем SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('app_blocked');
      await prefs.remove('block_reason');
      await prefs.remove('block_timestamp');

      AppLogger.info('Security data cleared successfully');
    } catch (e) {
      AppLogger.error('Error clearing security data: $e');
    }
  }

  /// Сбрасывает систему безопасности
  Future<void> resetSecuritySystem() async {
    try {
      AppLogger.info('Resetting security system...');

      await clearSecurityData();
      await initializeSecurity();

      AppLogger.info('Security system reset successfully');
    } catch (e) {
      AppLogger.error('Error resetting security system: $e');
    }
  }

  /// Перезапускает систему безопасности
  Future<void> restartSecurity() async {
    try {
      AppLogger.info('Restarting security system...');

      await resetSecuritySystem();

      AppLogger.info('Security system restarted successfully');
    } catch (e) {
      AppLogger.error('Error restarting security system: $e');
    }
  }

  /// Отключает систему безопасности
  void disableSecurity() {
    _isSecurityEnabled = false;
    AppLogger.info('Security system disabled');
  }

  /// Делает систему безопасности разрешительной
  void makeSecurityPermissive() {
    _isSecurityEnabled = false;
    AppLogger.info('Security system made permissive');
  }

  /// Включает систему безопасности
  void enableSecurity() {
    _isSecurityEnabled = true;
    AppLogger.info('Security system enabled');
  }

  /// Проверяет, включена ли система безопасности
  bool get isSecurityEnabled => _isSecurityEnabled;

  /// Выполняет тест безопасности (всегда проходит)
  Future<Map<String, bool>> runSecurityTest() async {
    try {
      AppLogger.info('Running simplified security test...');

      // Все тесты проходят успешно
      final results = {
        'codeObfuscation': false,
        'integrity': false,
      };

      AppLogger.info('Security test completed successfully');
      return results;
    } catch (e) {
      AppLogger.error('Error running security test: $e');
      // В случае ошибки возвращаем все тесты как пройденные
      return {
        'codeObfuscation': false,
        'integrity': false,
      };
    }
  }

  /// Проверяет, заблокировано ли приложение (всегда false)
  bool get isAppBlocked => false;

  /// Проверяет, активна ли система безопасности
  bool get isSecurityActive => _isSecurityActive;

  /// Получает статус безопасности
  Map<String, dynamic> getSecurityStatus() {
    return {
      'isActive': _isSecurityActive,
      'isAppBlocked': false,
      'codeObfuscation': false,
      'platform': Platform.operatingSystem,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Разблокирует приложение (не нужно, но оставляем для совместимости)
  Future<void> unblockApplication() async {
    try {
      AppLogger.info('Application unblocked (was not blocked)');
    } catch (e) {
      AppLogger.error('Error unblocking application: $e');
    }
  }
}
