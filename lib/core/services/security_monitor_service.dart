import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hlvm_mobileapp/core/services/session_manager.dart';
import 'package:hlvm_mobileapp/services/authentication.dart';
import '../utils/logger.dart';

/// Упрощенный сервис мониторинга безопасности
class SecurityMonitorService {
  final FlutterSecureStorage _secureStorage;
  final SessionManager _sessionManager;

  static const String _lastSecurityCheckKey = 'last_security_check';

  Timer? _securityCheckTimer;
  static const Duration _securityCheckInterval = Duration(minutes: 5);

  SecurityMonitorService({
    FlutterSecureStorage? secureStorage,
    SessionManager? sessionManager,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _sessionManager =
            sessionManager ?? SessionManager(authService: AuthService());

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

  /// Базовая проверка сессии
  Future<void> _checkBasicSession() async {
    try {
      final sessionInfo = await _sessionManager.getCurrentSessionInfo();
      if (sessionInfo == null) return;

      // Проверяем, не истекла ли сессия
      if (sessionInfo.isExpired) {
        // Принудительно завершаем сессию
        await _sessionManager.forceLogout(
          reason: 'Сессия истекла по времени',
          notifyUser: true,
        );
        return;
      }

      // Проверяем неактивность
      if (sessionInfo.inactivityTime.inHours > 2) {
        // Логируем неактивность
        AppLogger.warning(
            'Сессия неактивна: ${sessionInfo.inactivityTime.inHours} часов');
      }
    } catch (e) {
      AppLogger.error('Ошибка проверки сессии: $e');
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
