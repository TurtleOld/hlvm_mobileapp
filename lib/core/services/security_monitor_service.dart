import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hlvm_mobileapp/core/services/session_manager.dart';
import 'package:hlvm_mobileapp/core/services/secure_http_client.dart';

/// Сервис мониторинга безопасности
///
/// Отслеживает:
/// - Подозрительную активность
/// - Аномальные паттерны поведения
/// - Попытки атак
/// - Нарушения безопасности
class SecurityMonitorService {
  final SessionManager _sessionManager;
  final SecureHttpClient _secureHttpClient;
  final FlutterSecureStorage _secureStorage;

  // Ключи для хранения данных мониторинга
  static const String _securityEventsKey = 'security_events';
  static const String _threatLevelKey = 'threat_level';
  static const String _anomalyPatternsKey = 'anomaly_patterns';
  static const String _attackAttemptsKey = 'attack_attempts';
  static const String _lastSecurityCheckKey = 'last_security_check';

  // Константы безопасности
  static const Duration _securityCheckInterval = Duration(minutes: 5);
  static const Duration _eventRetentionPeriod = Duration(days: 30);
  static const int _maxSecurityEvents = 1000;
  static const int _maxAnomalyPatterns = 100;

  // Таймеры и контроллеры
  Timer? _securityCheckTimer;
  StreamController<SecurityEvent>? _securityEventController;

  // Статистика угроз
  int _threatLevel = 0; // 0-10, где 10 - критический уровень
  int _totalSecurityEvents = 0;
  int _suspiciousActivities = 0;
  int _attackAttempts = 0;

  SecurityMonitorService({
    required SessionManager sessionManager,
    required SecureHttpClient secureHttpClient,
    FlutterSecureStorage? secureStorage,
  })  : _sessionManager = sessionManager,
        _secureHttpClient = secureHttpClient,
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Инициализация сервиса мониторинга
  Future<void> initialize() async {
    try {
      // Загружаем сохраненные данные
      await _loadSecurityData();

      // Запускаем периодические проверки
      _startSecurityMonitoring();

      // Инициализируем контроллер событий
      _securityEventController = StreamController<SecurityEvent>.broadcast();

      // Подписываемся на события сессии
      _sessionManager.sessionEvents.listen(_handleSessionEvent);
    } catch (e) {
      // Логируем ошибку инициализации
      _recordSecurityEvent(
        SecurityEventType.initializationError,
        'Ошибка инициализации SecurityMonitorService: $e',
        severity: SecuritySeverity.high,
      );
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

      // 1. Проверяем целостность сессии
      await _checkSessionIntegrity();

      // 2. Анализируем паттерны активности
      await _analyzeActivityPatterns();

      // 3. Проверяем сетевую безопасность
      await _checkNetworkSecurity();

      // 4. Обновляем уровень угроз
      await _updateThreatLevel();

      // 5. Очищаем устаревшие события
      await _cleanupOldEvents();

      // Обновляем время последней проверки
      await _secureStorage.write(
        key: _lastSecurityCheckKey,
        value: now.toIso8601String(),
      );
    } catch (e) {
      _recordSecurityEvent(
        SecurityEventType.securityCheckError,
        'Ошибка проверки безопасности: $e',
        severity: SecuritySeverity.medium,
      );
    }
  }

  /// Проверка целостности сессии
  Future<void> _checkSessionIntegrity() async {
    try {
      final sessionInfo = await _sessionManager.getCurrentSessionInfo();
      if (sessionInfo == null) return;

      // Проверяем, не истекла ли сессия
      if (sessionInfo.isExpired) {
        _recordSecurityEvent(
          SecurityEventType.sessionExpired,
          'Сессия истекла: ${sessionInfo.sessionId}',
          severity: SecuritySeverity.medium,
          sessionId: sessionInfo.sessionId,
        );

        // Принудительно завершаем сессию
        await _sessionManager.forceLogout(
          reason: 'Сессия истекла по времени',
          notifyUser: true,
        );
        return;
      }

      // Проверяем неактивность
      if (sessionInfo.inactivityTime.inHours > 2) {
        _recordSecurityEvent(
          SecurityEventType.sessionInactive,
          'Сессия неактивна: ${sessionInfo.inactivityTime.inHours} часов',
          severity: SecuritySeverity.low,
          sessionId: sessionInfo.sessionId,
        );
      }

      // Проверяем fingerprint устройства
      final storedFingerprint =
          await _secureStorage.read(key: 'device_fingerprint');
      if (storedFingerprint != sessionInfo.deviceFingerprint) {
        _recordSecurityEvent(
          SecurityEventType.deviceFingerprintMismatch,
          'Несоответствие fingerprint устройства',
          severity: SecuritySeverity.high,
          sessionId: sessionInfo.sessionId,
        );

        // Принудительно завершаем сессию
        await _sessionManager.forceLogout(
          reason: 'Обнаружено изменение устройства',
          notifyUser: true,
        );
      }
    } catch (e) {
      _recordSecurityEvent(
        SecurityEventType.sessionIntegrityError,
        'Ошибка проверки целостности сессии: $e',
        severity: SecuritySeverity.medium,
      );
    }
  }

  /// Анализ паттернов активности
  Future<void> _analyzeActivityPatterns() async {
    try {
      final events = await _getSecurityEvents();
      if (events.isEmpty) return;

      // Анализируем частоту событий
      final recentEvents = events
          .where((event) =>
              DateTime.now().difference(event.timestamp) < Duration(hours: 1))
          .toList();

      if (recentEvents.length > 10) {
        _recordSecurityEvent(
          SecurityEventType.highEventFrequency,
          'Высокая частота событий безопасности: ${recentEvents.length} за час',
          severity: SecuritySeverity.medium,
        );
      }

      // Анализируем типы событий
      final eventTypes = recentEvents.map((e) => e.type).toSet();
      if (eventTypes.length > 5) {
        _recordSecurityEvent(
          SecurityEventType.multipleEventTypes,
          'Множественные типы событий безопасности: ${eventTypes.length}',
          severity: SecuritySeverity.low,
        );
      }

      // Проверяем аномальные паттерны
      await _detectAnomalyPatterns(recentEvents);
    } catch (e) {
      _recordSecurityEvent(
        SecurityEventType.patternAnalysisError,
        'Ошибка анализа паттернов: $e',
        severity: SecuritySeverity.low,
      );
    }
  }

  /// Обнаружение аномальных паттернов
  Future<void> _detectAnomalyPatterns(List<SecurityEvent> events) async {
    try {
      // Проверяем множественные неудачные попытки входа
      final failedLogins = events
          .where((e) => e.type == SecurityEventType.loginFailure)
          .toList();

      if (failedLogins.length > 3) {
        _recordSecurityEvent(
          SecurityEventType.multipleLoginFailures,
          'Множественные неудачные попытки входа: ${failedLogins.length}',
          severity: SecuritySeverity.high,
        );

        // Увеличиваем уровень угроз
        _threatLevel = min(_threatLevel + 2, 10);
      }

      // Проверяем подозрительную активность
      final suspiciousEvents = events
          .where((e) =>
              e.severity == SecuritySeverity.high ||
              e.severity == SecuritySeverity.critical)
          .toList();

      if (suspiciousEvents.length > 2) {
        _recordSecurityEvent(
          SecurityEventType.suspiciousActivityCluster,
          'Кластер подозрительной активности: ${suspiciousEvents.length} событий',
          severity: SecuritySeverity.high,
        );

        // Увеличиваем уровень угроз
        _threatLevel = min(_threatLevel + 3, 10);
      }

      // Сохраняем паттерн аномалии
      if (suspiciousEvents.isNotEmpty) {
        await _saveAnomalyPattern(suspiciousEvents);
      }
    } catch (e) {
      _recordSecurityEvent(
        SecurityEventType.anomalyDetectionError,
        'Ошибка обнаружения аномалий: $e',
        severity: SecuritySeverity.low,
      );
    }
  }

  /// Проверка сетевой безопасности
  Future<void> _checkNetworkSecurity() async {
    try {
      // Проверяем соединение с сервером
      final isConnected = await _secureHttpClient.checkConnection();

      if (!isConnected) {
        _recordSecurityEvent(
          SecurityEventType.networkConnectionLost,
          'Потеря соединения с сервером',
          severity: SecuritySeverity.medium,
        );
      }

      // Получаем статус HTTP клиента
      final clientStatus = await _secureHttpClient.getClientStatus();

      // Проверяем наличие валидной сессии
      if (clientStatus['hasValidSession'] == false) {
        _recordSecurityEvent(
          SecurityEventType.invalidSessionState,
          'Невалидное состояние сессии в HTTP клиенте',
          severity: SecuritySeverity.high,
        );
      }

      // Проверяем наличие токенов
      if (clientStatus['hasAccessToken'] == false) {
        _recordSecurityEvent(
          SecurityEventType.missingAccessToken,
          'Отсутствует access token',
          severity: SecuritySeverity.medium,
        );
      }
    } catch (e) {
      _recordSecurityEvent(
        SecurityEventType.networkSecurityError,
        'Ошибка проверки сетевой безопасности: $e',
        severity: SecuritySeverity.medium,
      );
    }
  }

  /// Обновление уровня угроз
  Future<void> _updateThreatLevel() async {
    try {
      // Базовый уровень угроз
      int newThreatLevel = 0;

      // Учитываем количество подозрительных событий
      if (_suspiciousActivities > 5) {
        newThreatLevel += 3;
      } else if (_suspiciousActivities > 2) {
        newThreatLevel += 2;
      } else if (_suspiciousActivities > 0) {
        newThreatLevel += 1;
      }

      // Учитываем попытки атак
      if (_attackAttempts > 3) {
        newThreatLevel += 4;
      } else if (_attackAttempts > 1) {
        newThreatLevel += 2;
      } else if (_attackAttempts > 0) {
        newThreatLevel += 1;
      }

      // Учитываем общее количество событий
      if (_totalSecurityEvents > 50) {
        newThreatLevel += 2;
      } else if (_totalSecurityEvents > 20) {
        newThreatLevel += 1;
      }

      // Ограничиваем уровень угроз
      newThreatLevel = newThreatLevel.clamp(0, 10);

      // Обновляем уровень угроз
      if (newThreatLevel != _threatLevel) {
        _threatLevel = newThreatLevel;

        // Записываем событие изменения уровня угроз
        _recordSecurityEvent(
          SecurityEventType.threatLevelChanged,
          'Уровень угроз изменен: $_threatLevel',
          severity: _getSeverityForThreatLevel(_threatLevel),
        );

        // Сохраняем новый уровень угроз
        await _secureStorage.write(
          key: _threatLevelKey,
          value: _threatLevel.toString(),
        );
      }
    } catch (e) {
      _recordSecurityEvent(
        SecurityEventType.threatLevelUpdateError,
        'Ошибка обновления уровня угроз: $e',
        severity: SecuritySeverity.low,
      );
    }
  }

  /// Получение уровня серьезности для уровня угроз
  SecuritySeverity _getSeverityForThreatLevel(int threatLevel) {
    if (threatLevel >= 8) return SecuritySeverity.critical;
    if (threatLevel >= 6) return SecuritySeverity.high;
    if (threatLevel >= 4) return SecuritySeverity.medium;
    if (threatLevel >= 2) return SecuritySeverity.low;
    return SecuritySeverity.info;
  }

  /// Очистка устаревших событий
  Future<void> _cleanupOldEvents() async {
    try {
      final events = await _getSecurityEvents();
      final cutoffTime = DateTime.now().subtract(_eventRetentionPeriod);

      // Удаляем устаревшие события
      final recentEvents =
          events.where((event) => event.timestamp.isAfter(cutoffTime)).toList();

      // Ограничиваем количество событий
      if (recentEvents.length > _maxSecurityEvents) {
        recentEvents.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        final trimmedEvents = recentEvents.take(_maxSecurityEvents).toList();

        await _saveSecurityEvents(trimmedEvents);
        _totalSecurityEvents = trimmedEvents.length;
      }
    } catch (e) {
      _recordSecurityEvent(
        SecurityEventType.cleanupError,
        'Ошибка очистки событий: $e',
        severity: SecuritySeverity.low,
      );
    }
  }

  /// Обработка событий сессии
  void _handleSessionEvent(SessionEvent event) {
    try {
      final eventType = event.runtimeType.toString();

      if (eventType.contains('SessionCreated')) {
        final sessionCreatedEvent = event as dynamic;
        _recordSecurityEvent(
          SecurityEventType.sessionCreated,
          'Создана новая сессия: ${sessionCreatedEvent.sessionId}',
          severity: SecuritySeverity.info,
          sessionId: sessionCreatedEvent.sessionId,
          username: sessionCreatedEvent.username,
        );
      } else if (eventType.contains('SessionInvalidated')) {
        final sessionInvalidatedEvent = event as dynamic;
        _recordSecurityEvent(
          SecurityEventType.sessionInvalidated,
          'Сессия аннулирована: ${sessionInvalidatedEvent.reason}',
          severity: SecuritySeverity.medium,
          sessionId: sessionInvalidatedEvent.sessionId,
        );
      } else if (eventType.contains('SessionExpired')) {
        _recordSecurityEvent(
          SecurityEventType.sessionExpired,
          'Сессия истекла',
          severity: SecuritySeverity.medium,
        );
      } else if (eventType.contains('ForceLogout')) {
        final forceLogoutEvent = event as dynamic;
        _recordSecurityEvent(
          SecurityEventType.forceLogout,
          'Принудительное завершение сессии: ${forceLogoutEvent.reason}',
          severity: SecuritySeverity.high,
        );
      } else if (eventType.contains('AccountLocked')) {
        final accountLockedEvent = event as dynamic;
        _recordSecurityEvent(
          SecurityEventType.accountLocked,
          'Аккаунт заблокирован: ${accountLockedEvent.username}',
          severity: SecuritySeverity.high,
          username: accountLockedEvent.username,
        );
      }
    } catch (e) {
      // Логируем ошибку обработки события
      _recordSecurityEvent(
        SecurityEventType.eventHandlingError,
        'Ошибка обработки события сессии: $e',
        severity: SecuritySeverity.low,
      );
    }
  }

  /// Запись события безопасности
  void _recordSecurityEvent(
    SecurityEventType type,
    String message, {
    SecuritySeverity severity = SecuritySeverity.info,
    String? sessionId,
    String? username,
    Map<String, dynamic>? additionalData,
  }) {
    try {
      final event = SecurityEvent(
        type: type,
        message: message,
        severity: severity,
        timestamp: DateTime.now(),
        sessionId: sessionId,
        username: username,
        additionalData: additionalData,
      );

      // Увеличиваем счетчики
      _totalSecurityEvents++;
      if (severity == SecuritySeverity.high ||
          severity == SecuritySeverity.critical) {
        _suspiciousActivities++;
      }
      if (type == SecurityEventType.loginFailure ||
          type == SecurityEventType.suspiciousActivity) {
        _attackAttempts++;
      }

      // Отправляем событие в поток
      _securityEventController?.add(event);

      // Сохраняем событие
      _saveSecurityEvent(event);
    } catch (e) {
      // В случае ошибки логируем в консоль
      print('Ошибка записи события безопасности: $e');
    }
  }

  /// Сохранение события безопасности
  Future<void> _saveSecurityEvent(SecurityEvent event) async {
    try {
      final events = await _getSecurityEvents();
      events.add(event);

      // Ограничиваем количество событий
      if (events.length > _maxSecurityEvents) {
        events.removeRange(0, events.length - _maxSecurityEvents);
      }

      await _saveSecurityEvents(events);
    } catch (e) {
      print('Ошибка сохранения события безопасности: $e');
    }
  }

  /// Сохранение аномального паттерна
  Future<void> _saveAnomalyPattern(List<SecurityEvent> events) async {
    try {
      final patterns = await _getAnomalyPatterns();

      final pattern = AnomalyPattern(
        events: events,
        detectedAt: DateTime.now(),
        threatLevel: _threatLevel,
      );

      patterns.add(pattern);

      // Ограничиваем количество паттернов
      if (patterns.length > _maxAnomalyPatterns) {
        patterns.removeRange(0, patterns.length - _maxAnomalyPatterns);
      }

      await _saveAnomalyPatterns(patterns);
    } catch (e) {
      print('Ошибка сохранения аномального паттерна: $e');
    }
  }

  // Методы загрузки и сохранения данных

  Future<void> _loadSecurityData() async {
    try {
      final threatLevelStr = await _secureStorage.read(key: _threatLevelKey);
      _threatLevel =
          threatLevelStr != null ? int.tryParse(threatLevelStr) ?? 0 : 0;

      final events = await _getSecurityEvents();
      _totalSecurityEvents = events.length;

      _suspiciousActivities = events
          .where((e) =>
              e.severity == SecuritySeverity.high ||
              e.severity == SecuritySeverity.critical)
          .length;

      _attackAttempts = events
          .where((e) =>
              e.type == SecurityEventType.loginFailure ||
              e.type == SecurityEventType.suspiciousActivity)
          .length;
    } catch (e) {
      print('Ошибка загрузки данных безопасности: $e');
    }
  }

  Future<List<SecurityEvent>> _getSecurityEvents() async {
    try {
      final eventsData = await _secureStorage.read(key: _securityEventsKey);
      if (eventsData == null) return [];

      final List<dynamic> eventsList = jsonDecode(eventsData);
      return eventsList.map((e) => SecurityEvent.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _saveSecurityEvents(List<SecurityEvent> events) async {
    try {
      final eventsData = jsonEncode(events.map((e) => e.toJson()).toList());
      await _secureStorage.write(key: _securityEventsKey, value: eventsData);
    } catch (e) {
      print('Ошибка сохранения событий безопасности: $e');
    }
  }

  Future<List<AnomalyPattern>> _getAnomalyPatterns() async {
    try {
      final patternsData = await _secureStorage.read(key: _anomalyPatternsKey);
      if (patternsData == null) return [];

      final List<dynamic> patternsList = jsonDecode(patternsData);
      return patternsList.map((e) => AnomalyPattern.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _saveAnomalyPatterns(List<AnomalyPattern> patterns) async {
    try {
      final patternsData = jsonEncode(patterns.map((e) => e.toJson()).toList());
      await _secureStorage.write(key: _anomalyPatternsKey, value: patternsData);
    } catch (e) {
      print('Ошибка сохранения аномальных паттернов: $e');
    }
  }

  // Публичные методы

  /// Получение текущего уровня угроз
  int get threatLevel => _threatLevel;

  /// Получение статистики безопасности
  Map<String, dynamic> get securityStats => {
        'threatLevel': _threatLevel,
        'totalEvents': _totalSecurityEvents,
        'suspiciousActivities': _suspiciousActivities,
        'attackAttempts': _attackAttempts,
      };

  /// Получение потока событий безопасности
  Stream<SecurityEvent> get securityEvents {
    return _securityEventController?.stream ?? Stream.empty();
  }

  /// Принудительная проверка безопасности
  Future<void> forceSecurityCheck() async {
    await _performSecurityCheck();
  }

  /// Сброс статистики безопасности
  Future<void> resetSecurityStats() async {
    _threatLevel = 0;
    _totalSecurityEvents = 0;
    _suspiciousActivities = 0;
    _attackAttempts = 0;

    await _secureStorage.delete(key: _threatLevelKey);
    await _secureStorage.delete(key: _securityEventsKey);
    await _secureStorage.delete(key: _anomalyPatternsKey);

    _recordSecurityEvent(
      SecurityEventType.statsReset,
      'Статистика безопасности сброшена',
      severity: SecuritySeverity.info,
    );
  }

  /// Освобождение ресурсов
  void dispose() {
    _securityCheckTimer?.cancel();
    _securityEventController?.close();
  }
}

/// Типы событий безопасности
enum SecurityEventType {
  // События сессии
  sessionCreated,
  sessionInvalidated,
  sessionExpired,
  sessionInactive,
  forceLogout,
  accountLocked,

  // События аутентификации
  loginSuccess,
  loginFailure,
  logout,

  // События безопасности
  suspiciousActivity,
  attackAttempt,
  multipleLoginFailures,
  suspiciousActivityCluster,

  // События сети
  networkConnectionLost,
  networkSecurityError,

  // События системы
  threatLevelChanged,
  securityCheckError,
  initializationError,
  eventHandlingError,

  // События очистки
  cleanupError,
  statsReset,

  // Другие события
  sessionIntegrityError,
  patternAnalysisError,
  anomalyDetectionError,
  threatLevelUpdateError,
  deviceFingerprintMismatch,
  invalidSessionState,
  missingAccessToken,
  highEventFrequency,
  multipleEventTypes,
}

/// Уровни серьезности событий
enum SecuritySeverity {
  info, // Информационные события
  low, // Низкий уровень угрозы
  medium, // Средний уровень угрозы
  high, // Высокий уровень угрозы
  critical, // Критический уровень угрозы
}

/// Событие безопасности
class SecurityEvent {
  final SecurityEventType type;
  final String message;
  final SecuritySeverity severity;
  final DateTime timestamp;
  final String? sessionId;
  final String? username;
  final Map<String, dynamic>? additionalData;

  SecurityEvent({
    required this.type,
    required this.message,
    required this.severity,
    required this.timestamp,
    this.sessionId,
    this.username,
    this.additionalData,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'message': message,
      'severity': severity.name,
      'timestamp': timestamp.toIso8601String(),
      'sessionId': sessionId,
      'username': username,
      'additionalData': additionalData,
    };
  }

  factory SecurityEvent.fromJson(Map<String, dynamic> json) {
    return SecurityEvent(
      type: SecurityEventType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => SecurityEventType.eventHandlingError,
      ),
      message: json['message'],
      severity: SecuritySeverity.values.firstWhere(
        (e) => e.name == json['severity'],
        orElse: () => SecuritySeverity.info,
      ),
      timestamp: DateTime.parse(json['timestamp']),
      sessionId: json['sessionId'],
      username: json['username'],
      additionalData: json['additionalData'] != null
          ? Map<String, dynamic>.from(json['additionalData'])
          : null,
    );
  }
}

/// Аномальный паттерн
class AnomalyPattern {
  final List<SecurityEvent> events;
  final DateTime detectedAt;
  final int threatLevel;

  AnomalyPattern({
    required this.events,
    required this.detectedAt,
    required this.threatLevel,
  });

  Map<String, dynamic> toJson() {
    return {
      'events': events.map((e) => e.toJson()).toList(),
      'detectedAt': detectedAt.toIso8601String(),
      'threatLevel': threatLevel,
    };
  }

  factory AnomalyPattern.fromJson(Map<String, dynamic> json) {
    return AnomalyPattern(
      events: (json['events'] as List)
          .map((e) => SecurityEvent.fromJson(e))
          .toList(),
      detectedAt: DateTime.parse(json['detectedAt']),
      threatLevel: json['threatLevel'],
    );
  }
}
