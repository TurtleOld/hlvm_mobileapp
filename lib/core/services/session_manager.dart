import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hlvm_mobileapp/services/authentication.dart';
import 'package:hlvm_mobileapp/core/utils/error_handler.dart';
import 'package:talker/talker.dart';

/// Сервис управления сессиями с защитой от Session Fixation атак
///
/// Защита от Session Fixation реализуется через:
/// 1. Принудительную регенерацию session ID при каждом входе
/// 2. Валидацию целостности сессионных данных
/// 3. Мониторинг подозрительной активности
/// 4. Автоматическое завершение сессий при обнаружении угроз
class SessionManager {
  final AuthService _authService;
  final FlutterSecureStorage _secureStorage;
  final Talker _logger;

  // Ключи для безопасного хранения
  static const String _sessionIdKey = 'session_id';
  static const String _sessionCreatedKey = 'session_created';
  static const String _sessionLastActivityKey = 'session_last_activity';
  static const String _sessionVersionKey = 'session_version';
  static const String _deviceFingerprintKey = 'device_fingerprint';
  static const String _suspiciousActivityKey = 'suspicious_activity';
  static const String _loginAttemptsKey = 'login_attempts';

  // Константы безопасности
  static const Duration _sessionTimeout = Duration(hours: 24);
  static const Duration _inactivityTimeout = Duration(hours: 2);
  static const int _maxLoginAttempts = 5;
  static const Duration _lockoutDuration = Duration(minutes: 30);

  Timer? _sessionMonitorTimer;
  StreamController<SessionEvent>? _sessionEventController;

  SessionManager({
    required AuthService authService,
    FlutterSecureStorage? secureStorage,
    Talker? logger,
  })  : _authService = authService,
        _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _logger = logger ?? Talker();

  /// Инициализация менеджера сессий
  Future<void> initialize() async {
    try {
      // Аннулируем любые существующие сессии при запуске
      await _invalidateExistingSessions();

      // Запускаем мониторинг сессий
      _startSessionMonitoring();

      // Инициализируем контроллер событий
      _sessionEventController = StreamController<SessionEvent>.broadcast();

      _logger.info('SessionManager инициализирован');
    } catch (e) {
      _logger.error('Ошибка инициализации SessionManager: $e');
      rethrow;
    }
  }

  /// Создание новой безопасной сессии после аутентификации
  ///
  /// Этот метод является ключевым для защиты от Session Fixation:
  /// - Аннулирует все предыдущие сессии
  /// - Генерирует новый уникальный session ID
  /// - Создает fingerprint устройства
  /// - Устанавливает временные метки
  Future<SessionInfo> createSecureSession({
    required String username,
    required Map<String, dynamic> userData,
    Duration? customTimeout,
  }) async {
    try {
      _logger
          .info('Создание новой безопасной сессии для пользователя: $username');

      // 1. Аннулируем все существующие сессии
      await _invalidateExistingSessions();

      // 2. Генерируем новый уникальный session ID
      final sessionId = await _generateSecureSessionId();

      // 3. Создаем fingerprint устройства
      final deviceFingerprint = await _generateDeviceFingerprint();

      // 4. Устанавливаем временные метки
      final now = DateTime.now();
      final sessionTimeout = customTimeout ?? _sessionTimeout;
      final sessionExpiry = now.add(sessionTimeout);

      // 5. Сохраняем информацию о сессии
      await _secureStorage.write(key: _sessionIdKey, value: sessionId);
      await _secureStorage.write(
          key: _sessionCreatedKey, value: now.toIso8601String());
      await _secureStorage.write(
          key: _sessionLastActivityKey, value: now.toIso8601String());
      await _secureStorage.write(
          key: _deviceFingerprintKey, value: deviceFingerprint);
      await _secureStorage.write(key: _sessionVersionKey, value: '1.0');

      // 6. Сбрасываем счетчики попыток входа
      await _resetLoginAttempts();

      // 7. Уведомляем о создании сессии
      _notifySessionEvent(SessionEvent.sessionCreated(sessionId, username));

      final sessionInfo = SessionInfo(
        sessionId: sessionId,
        username: username,
        createdAt: now,
        expiresAt: sessionExpiry,
        deviceFingerprint: deviceFingerprint,
        version: '1.0',
      );

      _logger.info('Безопасная сессия создана: ${sessionInfo.sessionId}');
      return sessionInfo;
    } catch (e) {
      _logger.error('Ошибка создания безопасной сессии: $e');
      rethrow;
    }
  }

  /// Валидация текущей сессии
  ///
  /// Проверяет:
  /// - Существование session ID
  /// - Время жизни сессии
  /// - Активность пользователя
  /// - Целостность данных
  /// - Подозрительную активность
  Future<SessionValidationResult> validateCurrentSession() async {
    try {
      final sessionId = await _secureStorage.read(key: _sessionIdKey);
      if (sessionId == null) {
        return SessionValidationResult.invalid('Сессия не найдена');
      }

      // Проверяем время создания сессии
      final createdString = await _secureStorage.read(key: _sessionCreatedKey);
      if (createdString == null) {
        return SessionValidationResult.invalid(
            'Отсутствует время создания сессии');
      }

      final createdAt = DateTime.parse(createdString);
      final now = DateTime.now();

      // Проверяем истечение сессии
      if (now.isAfter(createdAt.add(_sessionTimeout))) {
        await _invalidateSession('Сессия истекла по времени');
        return SessionValidationResult.expired('Сессия истекла по времени');
      }

      // Проверяем неактивность
      final lastActivityString =
          await _secureStorage.read(key: _sessionLastActivityKey);
      if (lastActivityString != null) {
        final lastActivity = DateTime.parse(lastActivityString);
        if (now.isAfter(lastActivity.add(_inactivityTimeout))) {
          await _invalidateSession('Сессия истекла по неактивности');
          return SessionValidationResult.expired(
              'Сессия истекла по неактивности');
        }
      }

      // Проверяем fingerprint устройства
      final storedFingerprint =
          await _secureStorage.read(key: _deviceFingerprintKey);
      final currentFingerprint = await _generateDeviceFingerprint();

      if (storedFingerprint != currentFingerprint) {
        await _invalidateSession('Обнаружено изменение устройства');
        return SessionValidationResult.suspicious(
            'Обнаружено изменение устройства');
      }

      // Проверяем подозрительную активность
      if (await _hasSuspiciousActivity()) {
        await _invalidateSession('Обнаружена подозрительная активность');
        return SessionValidationResult.suspicious(
            'Обнаружена подозрительная активность');
      }

      // Обновляем время последней активности
      await _updateLastActivity();

      return SessionValidationResult.valid(sessionId);
    } catch (e) {
      _logger.error('Ошибка валидации сессии: $e');
      return SessionValidationResult.invalid('Ошибка валидации: $e');
    }
  }

  /// Обновление сессии (refresh)
  ///
  /// Создает новую сессию с тем же пользователем,
  /// но с новым session ID для защиты от Session Fixation
  Future<SessionInfo?> refreshSession() async {
    try {
      final currentSession = await validateCurrentSession();
      if (!currentSession.isValid) {
        return null;
      }

      // Получаем данные пользователя
      final username = await _authService.getCurrentUsername();
      if (username == null) {
        await _invalidateSession('Не удалось получить имя пользователя');
        return null;
      }

      // Создаем новую сессию
      final newSession =
          await createSecureSession(username: username, userData: {});

      _logger.info('Сессия обновлена: ${newSession.sessionId}');
      return newSession;
    } catch (e) {
      _logger.error('Ошибка обновления сессии: $e');
      return null;
    }
  }

  /// Принудительное завершение сессии
  Future<void> forceLogout({
    required String reason,
    bool notifyUser = true,
  }) async {
    try {
      _logger.warning('Принудительное завершение сессии: $reason');

      await _invalidateSession(reason);

      if (notifyUser) {
        _notifySessionEvent(SessionEvent.forceLogout(reason));
      }
    } catch (e) {
      _logger.error('Ошибка принудительного завершения сессии: $e');
    }
  }

  /// Выход из аккаунта с UI уведомлением
  Future<void> logoutWithUI(BuildContext context) async {
    try {
      await _authService.logout();
      await _invalidateSession('Пользователь вышел из аккаунта');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Вы успешно вышли из аккаунта')),
        );
      }

      _notifySessionEvent(SessionEvent.userLogout());
    } catch (e) {
      _logger.error('Ошибка выхода из аккаунта: $e');
      // Fallback: прямая очистка сессии
      await _invalidateSession('Ошибка выхода из аккаунта');
    }
  }

  /// Выход из аккаунта при истечении сессии
  Future<void> logoutOnSessionExpired(BuildContext context) async {
    try {
      await _authService.logout();
      await _invalidateSession('Сессия истекла');

      if (context.mounted) {
        ErrorHandler.showSessionExpiredDialog(context);
      }

      _notifySessionEvent(SessionEvent.sessionExpired());
    } catch (e) {
      _logger.error('Ошибка выхода при истечении сессии: $e');
      // Fallback: прямая очистка сессии
      await _invalidateSession('Ошибка выхода при истечении сессии');

      if (context.mounted) {
        ErrorHandler.showSessionExpiredDialog(context);
      }
    }
  }

  /// Проверка аутентификации с UI обработкой
  Future<bool> checkAuthenticationWithUI(BuildContext context) async {
    try {
      final validation = await validateCurrentSession();

      if (!validation.isValid) {
        if (context.mounted) {
          await logoutOnSessionExpired(context);
        }
        return false;
      }

      return true;
    } catch (e) {
      _logger.error('Ошибка проверки аутентификации: $e');
      return false;
    }
  }

  /// Регистрация попытки входа
  Future<void> recordLoginAttempt({
    required String username,
    required bool success,
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      final attempts = await _getLoginAttempts();

      if (success) {
        // Сбрасываем счетчик при успешном входе
        await _resetLoginAttempts();
      } else {
        // Увеличиваем счетчик при неудачном входе
        attempts.add(LoginAttempt(
          username: username,
          timestamp: DateTime.now(),
          ipAddress: ipAddress,
          userAgent: userAgent,
          success: false,
        ));

        // Проверяем, не превышен ли лимит попыток
        if (attempts.length >= _maxLoginAttempts) {
          await _lockAccount(username);
        }

        await _saveLoginAttempts(attempts);
      }
    } catch (e) {
      _logger.error('Ошибка регистрации попытки входа: $e');
    }
  }

  /// Получение информации о текущей сессии
  Future<SessionInfo?> getCurrentSessionInfo() async {
    try {
      final sessionId = await _secureStorage.read(key: _sessionIdKey);
      if (sessionId == null) return null;

      final createdString = await _secureStorage.read(key: _sessionCreatedKey);
      final lastActivityString =
          await _secureStorage.read(key: _sessionLastActivityKey);
      final deviceFingerprint =
          await _secureStorage.read(key: _deviceFingerprintKey);
      final version = await _secureStorage.read(key: _sessionVersionKey);

      if (createdString == null) return null;

      final createdAt = DateTime.parse(createdString);
      final lastActivity = lastActivityString != null
          ? DateTime.parse(lastActivityString)
          : createdAt;

      return SessionInfo(
        sessionId: sessionId,
        username: await _authService.getCurrentUsername() ?? 'Неизвестно',
        createdAt: createdAt,
        expiresAt: createdAt.add(_sessionTimeout),
        lastActivity: lastActivity,
        deviceFingerprint: deviceFingerprint ?? 'Неизвестно',
        version: version ?? '1.0',
      );
    } catch (e) {
      _logger.error('Ошибка получения информации о сессии: $e');
      return null;
    }
  }

  /// Получение потока событий сессии
  Stream<SessionEvent> get sessionEvents {
    return _sessionEventController?.stream ?? const Stream.empty();
  }

  // Приватные методы

  /// Генерация безопасного session ID
  Future<String> _generateSecureSessionId() async {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (i) => random.nextInt(256));
    final sessionId = base64Url.encode(bytes);

    // Добавляем временную метку для дополнительной уникальности
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${sessionId}_$timestamp';
  }

  /// Генерация fingerprint устройства
  Future<String> _generateDeviceFingerprint() async {
    // В реальном приложении здесь должна быть более сложная логика
    // с учетом характеристик устройства
    final random = Random.secure();
    final bytes = List<int>.generate(16, (i) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// Аннулирование существующих сессий
  Future<void> _invalidateExistingSessions() async {
    try {
      await _secureStorage.delete(key: _sessionIdKey);
      await _secureStorage.delete(key: _sessionCreatedKey);
      await _secureStorage.delete(key: _sessionLastActivityKey);
      await _secureStorage.delete(key: _deviceFingerprintKey);
      await _secureStorage.delete(key: _sessionVersionKey);

      _logger.info('Существующие сессии аннулированы');
    } catch (e) {
      _logger.error('Ошибка аннулирования сессий: $e');
    }
  }

  /// Аннулирование текущей сессии
  Future<void> _invalidateSession(String reason) async {
    try {
      final sessionId = await _secureStorage.read(key: _sessionIdKey);

      await _invalidateExistingSessions();

      if (sessionId != null) {
        _logger.info('Сессия аннулирована: $sessionId, причина: $reason');
        _notifySessionEvent(SessionEvent.sessionInvalidated(sessionId, reason));
      }
    } catch (e) {
      _logger.error('Ошибка аннулирования сессии: $e');
    }
  }

  /// Обновление времени последней активности
  Future<void> _updateLastActivity() async {
    try {
      final now = DateTime.now();
      await _secureStorage.write(
          key: _sessionLastActivityKey, value: now.toIso8601String());
    } catch (e) {
      _logger.error('Ошибка обновления времени активности: $e');
    }
  }

  /// Проверка подозрительной активности
  Future<bool> _hasSuspiciousActivity() async {
    try {
      final suspiciousData =
          await _secureStorage.read(key: _suspiciousActivityKey);
      return suspiciousData != null;
    } catch (e) {
      return false;
    }
  }

  /// Получение попыток входа
  Future<List<LoginAttempt>> _getLoginAttempts() async {
    try {
      final attemptsData = await _secureStorage.read(key: _loginAttemptsKey);
      if (attemptsData == null) return [];

      final List<dynamic> attemptsList = jsonDecode(attemptsData);
      return attemptsList.map((e) => LoginAttempt.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Сохранение попыток входа
  Future<void> _saveLoginAttempts(List<LoginAttempt> attempts) async {
    try {
      final attemptsData = jsonEncode(attempts.map((e) => e.toJson()).toList());
      await _secureStorage.write(key: _loginAttemptsKey, value: attemptsData);
    } catch (e) {
      _logger.error('Ошибка сохранения попыток входа: $e');
    }
  }

  /// Сброс счетчика попыток входа
  Future<void> _resetLoginAttempts() async {
    try {
      await _secureStorage.delete(key: _loginAttemptsKey);
    } catch (e) {
      _logger.error('Ошибка сброса попыток входа: $e');
    }
  }

  /// Блокировка аккаунта
  Future<void> _lockAccount(String username) async {
    try {
      final lockoutUntil = DateTime.now().add(_lockoutDuration);
      await _secureStorage.write(
        key: 'account_locked_$username',
        value: lockoutUntil.toIso8601String(),
      );

      _logger.warning('Аккаунт заблокирован: $username до $lockoutUntil');
      _notifySessionEvent(
          SessionEvent.accountLocked(username, _lockoutDuration));
    } catch (e) {
      _logger.error('Ошибка блокировки аккаунта: $e');
    }
  }

  /// Запуск мониторинга сессий
  void _startSessionMonitoring() {
    _sessionMonitorTimer =
        Timer.periodic(const Duration(minutes: 1), (timer) async {
      try {
        final validation = await validateCurrentSession();
        if (!validation.isValid) {
          _logger.warning('Сессия не прошла валидацию: ${validation.reason}');
          _notifySessionEvent(SessionEvent.sessionValidationFailed(
              validation.reason ?? 'Неизвестная ошибка'));
        }
      } catch (e) {
        _logger.error('Ошибка мониторинга сессии: $e');
      }
    });
  }

  /// Уведомление о событиях сессии
  void _notifySessionEvent(SessionEvent event) {
    _sessionEventController?.add(event);
  }

  /// Освобождение ресурсов
  void dispose() {
    _sessionMonitorTimer?.cancel();
    _sessionEventController?.close();
  }
}

/// Информация о сессии
class SessionInfo {
  final String sessionId;
  final String username;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? lastActivity;
  final String deviceFingerprint;
  final String version;

  SessionInfo({
    required this.sessionId,
    required this.username,
    required this.createdAt,
    required this.expiresAt,
    this.lastActivity,
    required this.deviceFingerprint,
    required this.version,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Duration get remainingTime => expiresAt.difference(DateTime.now());

  Duration get inactivityTime => lastActivity != null
      ? DateTime.now().difference(lastActivity!)
      : Duration.zero;

  @override
  String toString() {
    return 'SessionInfo(sessionId: $sessionId, username: $username, expiresAt: $expiresAt)';
  }
}

/// Результат валидации сессии
class SessionValidationResult {
  final bool isValid;
  final String? sessionId;
  final String? reason;
  final bool isExpired;
  final bool isSuspicious;

  SessionValidationResult._({
    required this.isValid,
    this.sessionId,
    this.reason,
    this.isExpired = false,
    this.isSuspicious = false,
  });

  factory SessionValidationResult.valid(String sessionId) {
    return SessionValidationResult._(
      isValid: true,
      sessionId: sessionId,
    );
  }

  factory SessionValidationResult.invalid(String reason) {
    return SessionValidationResult._(
      isValid: false,
      reason: reason,
    );
  }

  factory SessionValidationResult.expired(String reason) {
    return SessionValidationResult._(
      isValid: false,
      reason: reason,
      isExpired: true,
    );
  }

  factory SessionValidationResult.suspicious(String reason) {
    return SessionValidationResult._(
      isValid: false,
      reason: reason,
      isSuspicious: true,
    );
  }
}

/// Попытка входа
class LoginAttempt {
  final String username;
  final DateTime timestamp;
  final String? ipAddress;
  final String? userAgent;
  final bool success;

  LoginAttempt({
    required this.username,
    required this.timestamp,
    this.ipAddress,
    this.userAgent,
    required this.success,
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'timestamp': timestamp.toIso8601String(),
      'ipAddress': ipAddress,
      'userAgent': userAgent,
      'success': success,
    };
  }

  factory LoginAttempt.fromJson(Map<String, dynamic> json) {
    return LoginAttempt(
      username: json['username'],
      timestamp: DateTime.parse(json['timestamp']),
      ipAddress: json['ipAddress'],
      userAgent: json['userAgent'],
      success: json['success'],
    );
  }
}

/// События сессии
abstract class SessionEvent {
  final DateTime timestamp;

  SessionEvent() : timestamp = DateTime.now();

  factory SessionEvent.sessionCreated(String sessionId, String username) =
      _SessionCreatedEvent;
  factory SessionEvent.sessionInvalidated(String sessionId, String reason) =
      _SessionInvalidatedEvent;
  factory SessionEvent.sessionExpired() = _SessionExpiredEvent;
  factory SessionEvent.userLogout() = _UserLogoutEvent;
  factory SessionEvent.forceLogout(String reason) = _ForceLogoutEvent;
  factory SessionEvent.accountLocked(String username, Duration duration) =
      _AccountLockedEvent;
  factory SessionEvent.sessionValidationFailed(String reason) =
      _SessionValidationFailedEvent;
}

class _SessionCreatedEvent extends SessionEvent {
  final String sessionId;
  final String username;
  _SessionCreatedEvent(this.sessionId, this.username);
}

class _SessionInvalidatedEvent extends SessionEvent {
  final String sessionId;
  final String reason;
  _SessionInvalidatedEvent(this.sessionId, this.reason);
}

class _SessionExpiredEvent extends SessionEvent {}

class _UserLogoutEvent extends SessionEvent {}

class _ForceLogoutEvent extends SessionEvent {
  final String reason;
  _ForceLogoutEvent(this.reason);
}

class _AccountLockedEvent extends SessionEvent {
  final String username;
  final Duration duration;
  _AccountLockedEvent(this.username, this.duration);
}

class _SessionValidationFailedEvent extends SessionEvent {
  final String reason;
  _SessionValidationFailedEvent(this.reason);
}
