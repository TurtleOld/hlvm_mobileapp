import 'package:flutter/material.dart';

/// Базовый класс для событий аутентификации
abstract class AuthEvent {
  const AuthEvent();
}

/// Запрос на вход в систему
class LoginRequested extends AuthEvent {
  final String username;
  final String password;

  const LoginRequested({
    required this.username,
    required this.password,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LoginRequested &&
        other.username == username &&
        other.password == password;
  }

  @override
  int get hashCode => username.hashCode ^ password.hashCode;
}

/// Запрос на выход из системы
class LogoutRequested extends AuthEvent {
  final BuildContext context;

  const LogoutRequested({required this.context});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LogoutRequested && other.context == context;
  }

  @override
  int get hashCode => context.hashCode;
}

/// Проверка статуса аутентификации
class CheckAuthStatus extends AuthEvent {
  const CheckAuthStatus();

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other is CheckAuthStatus;
  }

  @override
  int get hashCode => 0;
}

/// Очистка ошибки
class ClearError extends AuthEvent {
  const ClearError();

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other is ClearError;
  }

  @override
  int get hashCode => 0;
}

/// Проверка защиты от брутфорса
class CheckBruteforceProtection extends AuthEvent {
  final String username;

  const CheckBruteforceProtection({required this.username});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CheckBruteforceProtection && other.username == username;
  }

  @override
  int get hashCode => username.hashCode;
}

/// Сброс защиты от брутфорса
class ResetBruteforceProtection extends AuthEvent {
  final String username;

  const ResetBruteforceProtection({required this.username});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ResetBruteforceProtection && other.username == username;
  }

  @override
  int get hashCode => username.hashCode;
}

/// Обновление сессии
///
/// Используется для защиты от Session Fixation:
/// - Создает новую сессию с новым session ID
/// - Сохраняет данные пользователя
/// - Обновляет временные метки
class RefreshSession extends AuthEvent {
  const RefreshSession();

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other is RefreshSession;
  }

  @override
  int get hashCode => 0;
}

/// Принудительное завершение сессии
///
/// Используется при обнаружении:
/// - Подозрительной активности
/// - Нарушения безопасности
/// - Истечения сессии
/// - Изменения устройства
class ForceLogout extends AuthEvent {
  final String reason;
  final bool notifyUser;

  const ForceLogout({
    required this.reason,
    this.notifyUser = true,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ForceLogout &&
        other.reason == reason &&
        other.notifyUser == notifyUser;
  }

  @override
  int get hashCode => reason.hashCode ^ notifyUser.hashCode;
}

/// Валидация текущей сессии
///
/// Проверяет:
/// - Целостность сессионных данных
/// - Время жизни сессии
/// - Активность пользователя
/// - Подозрительную активность
class ValidateSession extends AuthEvent {
  const ValidateSession();

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other is ValidateSession;
  }

  @override
  int get hashCode => 0;
}

/// Создание новой безопасной сессии
///
/// Ключевой метод защиты от Session Fixation:
/// - Аннулирует все предыдущие сессии
/// - Генерирует новый уникальный session ID
/// - Создает fingerprint устройства
/// - Устанавливает временные метки
class CreateSecureSession extends AuthEvent {
  final String username;
  final Map<String, dynamic> userData;
  final Duration? customTimeout;

  const CreateSecureSession({
    required this.username,
    required this.userData,
    this.customTimeout,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CreateSecureSession &&
        other.username == username &&
        other.userData == userData &&
        other.customTimeout == customTimeout;
  }

  @override
  int get hashCode =>
      username.hashCode ^ userData.hashCode ^ customTimeout.hashCode;
}

/// Регистрация попытки входа
///
/// Используется для:
/// - Отслеживания подозрительной активности
/// - Блокировки аккаунтов при превышении лимита
/// - Анализа паттернов входа
class RecordLoginAttempt extends AuthEvent {
  final String username;
  final bool success;
  final String? ipAddress;
  final String? userAgent;

  const RecordLoginAttempt({
    required this.username,
    required this.success,
    this.ipAddress,
    this.userAgent,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecordLoginAttempt &&
        other.username == username &&
        other.success == success &&
        other.ipAddress == ipAddress &&
        other.userAgent == userAgent;
  }

  @override
  int get hashCode =>
      username.hashCode ^
      success.hashCode ^
      ipAddress.hashCode ^
      userAgent.hashCode;
}

/// Проверка состояния соединения
class CheckConnection extends AuthEvent {
  const CheckConnection();

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other is CheckConnection;
  }

  @override
  int get hashCode => 0;
}

/// Получение информации о сессии
class GetSessionInfo extends AuthEvent {
  const GetSessionInfo();

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other is GetSessionInfo;
  }

  @override
  int get hashCode => 0;
}
