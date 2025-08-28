import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../utils/logger.dart';

class SecurityMonitorService {
  final FlutterSecureStorage _secureStorage;

  static const String _lastSecurityCheckKey = 'last_security_check';

  Timer? _securityCheckTimer;
  static const Duration _securityCheckInterval = Duration(minutes: 15);

  SecurityMonitorService({
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  Future<void> initialize() async {
    try {
      AppLogger.info('SecurityMonitorService инициализирован');

      _startSecurityMonitoring();
    } catch (e) {
      AppLogger.error('Ошибка инициализации SecurityMonitorService: $e');
    }
  }

  void _startSecurityMonitoring() {
    _securityCheckTimer = Timer.periodic(_securityCheckInterval, (timer) async {
      await _performSecurityCheck();
    });
  }

  Future<void> _performSecurityCheck() async {
    try {
      final now = DateTime.now();

      await _checkBasicSession();

      await _secureStorage.write(
        key: _lastSecurityCheckKey,
        value: now.toIso8601String(),
      );
    } catch (e) {
      AppLogger.error('Ошибка проверки безопасности: $e');
    }
  }

  Future<void> _checkBasicSession() async {
    try {
      final accessToken = await _secureStorage.read(key: 'access_token');
      final refreshToken = await _secureStorage.read(key: 'refresh_token');
      
      if (accessToken == null || refreshToken == null) {
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

  void dispose() {
    _securityCheckTimer?.cancel();
    _securityCheckTimer = null;
  }

  Map<String, dynamic> getStatus() {
    return {
      'isActive': _securityCheckTimer != null,
      'lastCheck': DateTime.now().toIso8601String(),
      'checkInterval': _securityCheckInterval.inMinutes,
    };
  }
}
