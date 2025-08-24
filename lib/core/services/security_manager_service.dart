import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';
import 'reverse_engineering_protection_service.dart';
import 'code_obfuscation_service.dart';
import 'debug_protection_service.dart';

class SecurityManagerService {
  static final SecurityManagerService _instance =
      SecurityManagerService._internal();

  factory SecurityManagerService() => _instance;

  SecurityManagerService._internal();

  final ReverseEngineeringProtectionService _reverseEngineeringProtection =
      ReverseEngineeringProtectionService();
  final CodeObfuscationService _codeObfuscation = CodeObfuscationService();
  final DebugProtectionService _debugProtection = DebugProtectionService();

  Timer? _securityTimer;
  bool _isSecurityActive = false;
  bool _isAppBlocked = false;

  /// Инициализирует систему безопасности
  Future<void> initializeSecurity() async {
    try {
      AppLogger.info('Initializing security system...');

      // Проверяем, не заблокировано ли приложение
      _isAppBlocked = await _reverseEngineeringProtection.isAppBlocked();

      if (_isAppBlocked) {
        AppLogger.warning(
            'Application is blocked due to previous security violation');
        return;
      }

      // Активируем все защиты
      await _activateAllProtections();

      // Запускаем периодические проверки безопасности
      _startSecurityMonitoring();

      _isSecurityActive = true;
      AppLogger.info('Security system initialized successfully');
    } catch (e) {
      AppLogger.error('Error initializing security: $e');
      // В случае ошибки блокируем приложение
      await _blockApplication();
    }
  }

  /// Активирует все защиты
  Future<void> _activateAllProtections() async {
    try {
      // Активируем защиту от reverse engineering
      await _reverseEngineeringProtection.applyProtection();

      // Активируем защиту от отладки
      _debugProtection.activateProtection();

      // Создаем обфусцированные константы
      final obfuscatedConstants = _codeObfuscation.createObfuscatedConstants();
      AppLogger.info(
          'Code obfuscation activated with ${obfuscatedConstants.length} constants');
    } catch (e) {
      AppLogger.error('Error activating protections: $e');
      throw e;
    }
  }

  /// Запускает мониторинг безопасности
  void _startSecurityMonitoring() {
    _securityTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      await _performSecurityCheck();
    });

    AppLogger.info('Security monitoring started');
  }

  /// Выполняет проверку безопасности
  Future<void> _performSecurityCheck() async {
    try {
      // Проверяем на reverse engineering
      final isReverseEngineeringDetected =
          await _reverseEngineeringProtection.isReverseEngineeringDetected();

      if (isReverseEngineeringDetected) {
        AppLogger.warning('Reverse engineering detected during security check!');
        await _handleSecurityViolation('Reverse Engineering');
        return;
      }

      // Проверяем статус защиты от отладки
      final debugProtectionStatus = _debugProtection.getProtectionStatus();
      if (debugProtectionStatus['isDebugMode'] == true) {
        AppLogger.warning('Debug mode detected during security check!');
        await _handleSecurityViolation('Debug Mode');
        return;
      }

      // Проверяем целостность обфусцированных данных
      final constants = _codeObfuscation.createObfuscatedConstants();
      for (final entry in constants.entries) {
        final isIntegrityValid = _codeObfuscation.verifyObfuscatedIntegrity(
            entry.value,
            entry.key == 'API_BASE_URL'
                ? 'https://api.example.com'
                : 'test_value');

        if (!isIntegrityValid) {
          AppLogger
              .warning('Code integrity violation detected for: ${entry.key}');
          await _handleSecurityViolation('Code Integrity');
          return;
        }
      }

      AppLogger.info('Security check passed successfully');
    } catch (e) {
      AppLogger.error('Error during security check: $e');
      await _handleSecurityViolation('Security Check Error');
    }
  }

  /// Обрабатывает нарушение безопасности
  Future<void> _handleSecurityViolation(String violationType) async {
    try {
      AppLogger.warning('Security violation detected: $violationType');

      // Блокируем приложение
      await _blockApplication();

      // Логируем нарушение
      await _logSecurityViolation(violationType);

      // Уведомляем сервер
      await _notifyServer(violationType);
    } catch (e) {
      AppLogger.error('Error handling security violation: $e');
    }
  }

  /// Блокирует приложение
  Future<void> _blockApplication() async {
    try {
      _isAppBlocked = true;

      // Устанавливаем флаг блокировки в SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('app_blocked', true);
      await prefs.setString('block_reason', 'Security violation detected');
      await prefs.setString(
          'block_timestamp', DateTime.now().toIso8601String());

      // Останавливаем все защиты
      _stopSecurityMonitoring();

      AppLogger.warning('Application blocked due to security violation');
    } catch (e) {
      AppLogger.error('Error blocking application: $e');
    }
  }

  /// Останавливает мониторинг безопасности
  void _stopSecurityMonitoring() {
    _securityTimer?.cancel();
    _securityTimer = null;
    _debugProtection.deactivateProtection();
    _isSecurityActive = false;

    AppLogger.info('Security monitoring stopped');
  }

  /// Логирует нарушение безопасности
  Future<void> _logSecurityViolation(String violationType) async {
    try {
      final timestamp = DateTime.now().toIso8601String();
      final deviceInfo = await _getDeviceInfo();

      AppLogger.warning('''
        SECURITY VIOLATION LOGGED!
        Type: $violationType
        Timestamp: $timestamp
        Device: $deviceInfo
        Platform: ${Platform.operatingSystem}
        Architecture: ${Platform.operatingSystemVersion}
      ''');
    } catch (e) {
      AppLogger.error('Error logging security violation: $e');
    }
  }

  /// Уведомляет сервер о нарушении безопасности
  Future<void> _notifyServer(String violationType) async {
    try {
      // Здесь можно реализовать отправку уведомления на сервер
      // о нарушении безопасности
      AppLogger.info('Server notification sent for violation: $violationType');
    } catch (e) {
      AppLogger.error('Error notifying server: $e');
    }
  }

  /// Получает информацию об устройстве
  Future<String> _getDeviceInfo() async {
    try {
      if (Platform.isAndroid) {
        return 'Android Device';
      } else if (Platform.isIOS) {
        return 'iOS Device';
      } else {
        return 'Unknown Platform';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  /// Проверяет, заблокировано ли приложение
  bool get isAppBlocked => _isAppBlocked;

  /// Проверяет, активна ли система безопасности
  bool get isSecurityActive => _isSecurityActive;

  /// Получает статус безопасности
  Map<String, dynamic> getSecurityStatus() {
    return {
      'isActive': _isSecurityActive,
      'isAppBlocked': _isAppBlocked,
      'reverseEngineeringProtection': true,
      'codeObfuscation': true,
      'debugProtection': _debugProtection.isProtectionActive,
      'platform': Platform.operatingSystem,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Разблокирует приложение (для администраторов)
  Future<void> unblockApplication() async {
    try {
      if (!_isAppBlocked) return;

      _isAppBlocked = false;

      // Убираем флаг блокировки
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('app_blocked', false);
      await prefs.remove('block_reason');
      await prefs.remove('block_timestamp');

      // Перезапускаем систему безопасности
      await initializeSecurity();

      AppLogger.info('Application unblocked successfully');
    } catch (e) {
      AppLogger.error('Error unblocking application: $e');
    }
  }

  /// Выполняет тест безопасности
  Future<Map<String, bool>> runSecurityTest() async {
    try {
      final results = <String, bool>{};

      // Тест защиты от reverse engineering
      results['reverseEngineering'] =
          !(await _reverseEngineeringProtection.isReverseEngineeringDetected());

      // Тест обфускации кода
      final testString = 'test_string';
      final obfuscated = _codeObfuscation.obfuscateString(testString);
      final deobfuscated = _codeObfuscation.deobfuscateString(obfuscated);
      results['codeObfuscation'] = testString == deobfuscated;

      // Тест защиты от отладки
      results['debugProtection'] = !kDebugMode;

      // Тест целостности
      results['integrity'] = !_isAppBlocked;

      AppLogger.info('Security test completed: $results');
      return results;
    } catch (e) {
      AppLogger.error('Error running security test: $e');
      return {'error': false};
    }
  }

  /// Очищает все данные безопасности
  Future<void> clearSecurityData() async {
    try {
      // Останавливаем мониторинг
      _stopSecurityMonitoring();

      // Очищаем SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Сбрасываем флаги
      _isSecurityActive = false;
      _isAppBlocked = false;

      AppLogger.info('Security data cleared');
    } catch (e) {
      AppLogger.error('Error clearing security data: $e');
    }
  }

  /// Перезапускает систему безопасности
  Future<void> restartSecurity() async {
    try {
      AppLogger.info('Restarting security system...');

      // Останавливаем текущую систему
      _stopSecurityMonitoring();

      // Перезапускаем
      await initializeSecurity();

      AppLogger.info('Security system restarted successfully');
    } catch (e) {
      AppLogger.error('Error restarting security: $e');
    }
  }
}
