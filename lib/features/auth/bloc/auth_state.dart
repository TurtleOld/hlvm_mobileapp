import 'package:hlvm_mobileapp/core/services/session_manager.dart';

/// Базовый класс для состояний аутентификации
abstract class AuthState {
  const AuthState();
}

/// Начальное состояние
class AuthInitial extends AuthState {
  const AuthInitial();

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other is AuthInitial;
  }

  @override
  int get hashCode => 0;
}

/// Состояние загрузки
class AuthLoading extends AuthState {
  const AuthLoading();

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other is AuthLoading;
  }

  @override
  int get hashCode => 0;
}

/// Состояние аутентификации
class AuthAuthenticated extends AuthState {
  final String username;
  final SessionInfo? sessionInfo;

  const AuthAuthenticated({
    required this.username,
    this.sessionInfo,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthAuthenticated &&
        other.username == username &&
        other.sessionInfo == sessionInfo;
  }

  @override
  int get hashCode => username.hashCode ^ sessionInfo.hashCode;
}

/// Состояние неаутентификации
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other is AuthUnauthenticated;
  }

  @override
  int get hashCode => 0;
}

/// Состояние ошибки
class AuthError extends AuthState {
  final String message;
  final Object? error;

  const AuthError({
    required this.message,
    this.error,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthError &&
        other.message == message &&
        other.error == error;
  }

  @override
  int get hashCode => message.hashCode ^ error.hashCode;
}

/// Результат проверки защиты от брутфорса
class AuthBruteforceCheckResult extends AuthState {
  final Map<String, dynamic> result;

  const AuthBruteforceCheckResult(this.result);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthBruteforceCheckResult && other.result == result;
  }

  @override
  int get hashCode => result.hashCode;
}

/// Состояние валидной сессии
///
/// Указывает на то, что текущая сессия:
/// - Прошла все проверки безопасности
/// - Не истекла по времени
/// - Не имеет подозрительной активности
/// - Соответствует fingerprint устройства
class AuthSessionValid extends AuthState {
  final SessionInfo? sessionInfo;

  const AuthSessionValid({this.sessionInfo});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthSessionValid && other.sessionInfo == sessionInfo;
  }

  @override
  int get hashCode => sessionInfo.hashCode;
}

/// Состояние невалидной сессии
///
/// Указывает на проблемы с сессией:
/// - Сессия истекла
/// - Обнаружена подозрительная активность
/// - Нарушена целостность данных
/// - Изменение устройства
class AuthSessionInvalid extends AuthState {
  final String reason;
  final bool isExpired;
  final bool isSuspicious;
  final SessionInfo? previousSession;

  const AuthSessionInvalid({
    required this.reason,
    this.isExpired = false,
    this.isSuspicious = false,
    this.previousSession,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthSessionInvalid &&
        other.reason == reason &&
        other.isExpired == isExpired &&
        other.isSuspicious == isSuspicious &&
        other.previousSession == previousSession;
  }

  @override
  int get hashCode =>
      reason.hashCode ^
      isExpired.hashCode ^
      isSuspicious.hashCode ^
      previousSession.hashCode;
}

/// Состояние обновления сессии
///
/// Указывает на процесс:
/// - Создания новой сессии
/// - Обновления session ID
/// - Валидации данных
class AuthSessionRefreshing extends AuthState {
  final String? currentUsername;
  final Duration? estimatedTime;

  const AuthSessionRefreshing({
    this.currentUsername,
    this.estimatedTime,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthSessionRefreshing &&
        other.currentUsername == currentUsername &&
        other.estimatedTime == estimatedTime;
  }

  @override
  int get hashCode => currentUsername.hashCode ^ estimatedTime.hashCode;
}

/// Состояние принудительного завершения сессии
///
/// Указывает на:
/// - Обнаружение угрозы безопасности
/// - Подозрительную активность
/// - Нарушение правил безопасности
/// - Критические ошибки сервера
class AuthForceLogout extends AuthState {
  final String reason;
  final bool notifyUser;
  final DateTime timestamp;
  final SessionInfo? terminatedSession;

  const AuthForceLogout({
    required this.reason,
    required this.notifyUser,
    required this.timestamp,
    this.terminatedSession,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthForceLogout &&
        other.reason == reason &&
        other.notifyUser == notifyUser &&
        other.timestamp == timestamp &&
        other.terminatedSession == terminatedSession;
  }

  @override
  int get hashCode =>
      reason.hashCode ^
      notifyUser.hashCode ^
      timestamp.hashCode ^
      terminatedSession.hashCode;
}

/// Состояние блокировки аккаунта
///
/// Указывает на:
/// - Превышение лимита попыток входа
/// - Подозрительную активность
/// - Временную блокировку
class AuthAccountLocked extends AuthState {
  final String username;
  final Duration lockoutDuration;
  final DateTime lockoutUntil;
  final String reason;

  const AuthAccountLocked({
    required this.username,
    required this.lockoutDuration,
    required this.lockoutUntil,
    required this.reason,
  });

  Duration get remainingLockoutTime {
    final now = DateTime.now();
    if (now.isAfter(lockoutUntil)) {
      return Duration.zero;
    }
    return lockoutUntil.difference(now);
  }

  bool get isLocked => DateTime.now().isBefore(lockoutUntil);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthAccountLocked &&
        other.username == username &&
        other.lockoutDuration == lockoutDuration &&
        other.lockoutUntil == lockoutUntil &&
        other.reason == reason;
  }

  @override
  int get hashCode =>
      username.hashCode ^
      lockoutDuration.hashCode ^
      lockoutUntil.hashCode ^
      reason.hashCode;
}

/// Состояние проверки соединения
///
/// Указывает на:
/// - Доступность сервера
/// - Качество соединения
/// - Статус сетевого подключения
class AuthConnectionStatus extends AuthState {
  final bool isConnected;
  final Duration? responseTime;
  final String? serverStatus;
  final DateTime lastCheck;

  const AuthConnectionStatus({
    required this.isConnected,
    this.responseTime,
    this.serverStatus,
    required this.lastCheck,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthConnectionStatus &&
        other.isConnected == isConnected &&
        other.responseTime == responseTime &&
        other.serverStatus == serverStatus &&
        other.lastCheck == lastCheck;
  }

  @override
  int get hashCode =>
      isConnected.hashCode ^
      responseTime.hashCode ^
      serverStatus.hashCode ^
      lastCheck.hashCode;
}

/// Состояние информации о сессии
///
/// Содержит детальную информацию о:
/// - Текущей сессии
/// - Статусе безопасности
/// - Времени жизни
/// - Активности пользователя
class AuthSessionInfo extends AuthState {
  final SessionInfo sessionInfo;
  final Map<String, dynamic> clientStatus;
  final bool isSecure;
  final List<String> securityWarnings;

  const AuthSessionInfo({
    required this.sessionInfo,
    required this.clientStatus,
    required this.isSecure,
    this.securityWarnings = const [],
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthSessionInfo &&
        other.sessionInfo == sessionInfo &&
        other.clientStatus == clientStatus &&
        other.isSecure == isSecure &&
        other.securityWarnings == securityWarnings;
  }

  @override
  int get hashCode =>
      sessionInfo.hashCode ^
      clientStatus.hashCode ^
      isSecure.hashCode ^
      securityWarnings.hashCode;
}
