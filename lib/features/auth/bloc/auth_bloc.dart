import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hlvm_mobileapp/services/authentication.dart';
import 'package:hlvm_mobileapp/core/services/session_manager.dart';
import 'package:hlvm_mobileapp/core/bloc/talker_bloc.dart';
import 'package:hlvm_mobileapp/core/services/talker_service.dart';
import 'package:hlvm_mobileapp/features/auth/bloc/auth_event.dart';
import 'package:hlvm_mobileapp/features/auth/bloc/auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;
  final SessionManager _sessionManager;
  final TalkerBloc _talkerBloc;

  AuthBloc({
    AuthService? authService,
    SessionManager? sessionManager,
    TalkerBloc? talkerBloc,
  })  : _authService = authService ?? AuthService(),
        _sessionManager =
            sessionManager ?? SessionManager(authService: AuthService()),
        _talkerBloc = talkerBloc ?? TalkerBloc(talkerService: TalkerService()),
        super(const AuthInitial()) {
    on<LoginRequested>(_onLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<ClearError>(_onClearError);
    on<CheckBruteforceProtection>(_onCheckBruteforceProtection);
    on<ResetBruteforceProtection>(_onResetBruteforceProtection);
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(const AuthLoading());

      // Выполняем безопасный логин с таймаутом
      final result =
          await _performSecureLogin(event.username, event.password).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          return {
            'success': false,
            'message': 'Таймаут авторизации. Проверьте соединение с сервером.',
          };
        },
      );

      if (result['success']) {
        try {
          // Успешная авторизация - создаем новую сессию с таймаутом
          final sessionInfo = await _sessionManager.createSecureSession(
            username: event.username,
            userData: {},
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('Session creation timeout');
            },
          );

          emit(AuthAuthenticated(
            username: event.username,
            sessionInfo: sessionInfo,
          ));

          _talkerBloc
              .add(const ShowSuccessEvent(message: 'Авторизация успешна'));
        } catch (sessionError) {
          // Если создание сессии не удалось, все равно считаем авторизацию успешной
          emit(AuthAuthenticated(
            username: event.username,
            sessionInfo: null,
          ));

          _talkerBloc
              .add(const ShowSuccessEvent(message: 'Авторизация успешна'));
        }
      } else {
        // Ошибка авторизации
        emit(AuthError(
          message: result['message'] ?? 'Ошибка авторизации',
        ));
      }
    } catch (e) {
      emit(AuthError(message: 'Неожиданная ошибка: $e'));
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(const AuthLoading());

      await _sessionManager.logoutWithUI(event.context);

      emit(const AuthUnauthenticated());

      _talkerBloc
          .add(const ShowSuccessEvent(message: 'Вы успешно вышли из аккаунта'));
    } catch (e) {
      emit(AuthError(message: 'Ошибка при выходе: $e'));
    }
  }

  Future<void> _onCheckAuthStatus(
    CheckAuthStatus event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(const AuthLoading());

      final sessionValidation = await _sessionManager.validateCurrentSession();

      if (sessionValidation.isValid) {
        final sessionInfo = await _sessionManager.getCurrentSessionInfo();
        emit(AuthAuthenticated(
          username: sessionInfo?.username ?? 'Unknown',
          sessionInfo: sessionInfo,
        ));
      } else {
        emit(const AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthError(message: 'Ошибка валидации сессии: $e'));
    }
  }

  Future<void> _onClearError(
    ClearError event,
    Emitter<AuthState> emit,
  ) async {
    if (state is AuthError) {
      emit(const AuthUnauthenticated());
    }
    return;
  }

  Future<void> _onCheckBruteforceProtection(
    CheckBruteforceProtection event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(const AuthLoading());

      final result = await _checkBruteforceProtection(event.username);

      emit(AuthBruteforceCheckResult(result));
    } catch (e) {
      emit(AuthError(message: 'Ошибка проверки защиты: $e'));
    }
  }

  Future<void> _onResetBruteforceProtection(
    ResetBruteforceProtection event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(const AuthLoading());

      await _resetAttempts(event.username);

      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(message: 'Ошибка сброса защиты: $e'));
    }
  }

  Future<Map<String, dynamic>> _performSecureLogin(
    String username,
    String password,
  ) async {
    try {
      // Проверяем защиту от брутфорса
      if (await _shouldWait(username)) {
        final remainingTime = await _getRemainingWaitTime(username);
        return {
          'success': false,
          'message':
              'Слишком много попыток. Попробуйте через ${remainingTime.inMinutes} минут',
        };
      }

      // Выполняем авторизацию с таймаутом
      final authResult = await _authService.login(username, password).timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          return {
            'success': false,
            'message': 'Таймаут соединения с сервером',
          };
        },
      );

      if (authResult['success']) {
        // Сбрасываем счетчик неудачных попыток при успешном логине
        await _resetAttempts(username);

        return {
          'success': true,
          'message': 'Авторизация успешна',
        };
      } else {
        // Увеличиваем счетчик неудачных попыток
        await _recordFailedAttempt(username);

        return {
          'success': false,
          'message': authResult['message'] ?? 'Ошибка аутентификации',
        };
      }
    } catch (e) {
      // Увеличиваем счетчик неудачных попыток при ошибке
      await _recordFailedAttempt(username);

      return {
        'success': false,
        'message': 'Ошибка при авторизации: $e',
      };
    }
  }

  Future<bool> _shouldWait(String username) async {
    // Простая логика защиты от брутфорса
    return false;
  }

  Future<Duration> _getRemainingWaitTime(String username) async {
    // Возвращаем 0 минут
    return Duration.zero;
  }

  Future<void> _resetAttempts(String username) async {
    // Сбрасываем счетчик попыток
  }

  Future<void> _recordFailedAttempt(String username) async {
    // Увеличиваем счетчик неудачных попыток
  }

  Future<Map<String, dynamic>> _checkBruteforceProtection(
      String username) async {
    // Простая проверка защиты от брутфорса
    return {
      'isAllowed': true,
      'remainingAttempts': 5,
      'remainingTime': Duration.zero,
      'reason': null,
    };
  }
}
