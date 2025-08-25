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

  const AuthAuthenticated({
    required this.username,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthAuthenticated && other.username == username;
  }

  @override
  int get hashCode => username.hashCode;
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
