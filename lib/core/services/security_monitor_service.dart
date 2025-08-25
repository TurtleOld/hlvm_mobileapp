import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../utils/logger.dart';

/// Упрощенный сервис мониторинга безопасности
class SecurityMonitorService {
  final FlutterSecureStorage _secureStorage;

  static const String _lastSecurityCheckKey = 'last_security_check';

  Timer? _securityCheckTimer;
  static const Duration _securityCheckInterval = Duration(minutes: 15);

  SecurityMonitorService({
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Инициализация сервиса
  Future<void> initialize() async {
    try {
      AppLogger.info('SecurityMonitorService инициализирован');

      // Запускаем базовый мониторинг
      _startSecurityMonitoring();
    } catch (e) {
      AppLogger.error('Ошибка инициализации SecurityMonitorService: $e');
    }
  }

  /// Запуск мониторинга безопасности
  void _startSecurityMonitoring() {
    _securityCheckTimer = Timer.periodic(_securityCheckInterval, (timer) async {
      await _performSecurityCheck();
    });
  }

  /// Выполнение проверки безопасности
  Future<void> _performSecurityCheck() async {
    try {
      final now = DateTime.now();

      // Базовая проверка сессии
      await _checkBasicSession();

      // Обновляем время последней проверки
      await _secureStorage.write(
        key: _lastSecurityCheckKey,
        value: now.toIso8601String(),
      );
    } catch (e) {
      AppLogger.error('Ошибка проверки безопасности: $e');
    }
  }

  /// Базовая проверка токенов
  Future<void> _checkBasicSession() async {
    try {
      final accessToken = await _secureStorage.read(key: 'access_token');
      final refreshToken = await _secureStorage.read(key: 'refresh_token');
      
      if (accessToken == null || refreshToken == null) {
        // Токены отсутствуют, очищаем все
        await _secureStorage.delete(key: 'access_token');
        await _secureStorage.delete(key: 'refresh_token');
        await _secureStorage.delete(key: 'isLoggedIn');
        AppLogger.warning('Токены отсутствуют, очищены');
        return;
      }
    } catch (e) {
      AppLogger.error('Ошибка проверки токенов: $e');
    }
  }

  /// Остановка мониторинга
  void dispose() {
    _securityCheckTimer?.cancel();
    _securityCheckTimer = null;
  }

  /// Получение статуса сервиса
  Map<String, dynamic> getStatus() {
    return {
      'isActive': _securityCheckTimer != null,
      'lastCheck': DateTime.now().toIso8601String(),
      'checkInterval': _securityCheckInterval.inMinutes,
    };
  }
}
