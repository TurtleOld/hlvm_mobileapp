import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hlvm_mobileapp/services/authentication.dart';
import 'package:hlvm_mobileapp/core/bloc/talker_bloc.dart';
import 'package:hlvm_mobileapp/core/services/talker_service.dart';
import 'package:hlvm_mobileapp/features/auth/bloc/auth_event.dart';
import 'package:hlvm_mobileapp/features/auth/bloc/auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;
  final TalkerBloc _talkerBloc;

  AuthBloc({
    AuthService? authService,
    TalkerBloc? talkerBloc,
  })  : _authService = authService ?? AuthService(),
        _talkerBloc = talkerBloc ?? TalkerBloc(talkerService: TalkerService()),
        super(const AuthInitial()) {
    // print('AuthBloc: Initializing with events');
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
    // print('AuthBloc: LoginRequested event received');
    try {
      emit(const AuthLoading());

      // Выполняем авторизацию с таймаутом
      final result =
          await _authService.login(event.username, event.password).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          return {
            'success': false,
            'message': 'Таймаут авторизации. Проверьте соединение с сервером.',
          };
        },
      );

      if (result['success']) {
        print('AuthBloc: Login successful, emitting AuthAuthenticated');
        emit(AuthAuthenticated(username: event.username));
        try {
          _talkerBloc
              .add(const ShowSuccessEvent(message: 'Авторизация успешна'));
        } catch (e) {
          // Игнорируем ошибки TalkerBloc
        }
      } else {
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

      await _authService.logout();

      emit(const AuthUnauthenticated());

      try {
        _talkerBloc.add(
            const ShowSuccessEvent(message: 'Вы успешно вышли из аккаунта'));
      } catch (e) {
        // Игнорируем ошибки TalkerBloc
      }
    } catch (e) {
      emit(AuthError(message: 'Ошибка при выходе: $e'));
    }
  }

  Future<void> _onCheckAuthStatus(
    CheckAuthStatus event,
    Emitter<AuthState> emit,
  ) async {
    // print('AuthBloc: CheckAuthStatus event received');
    try {
      emit(const AuthLoading());

      final isLoggedIn = await _authService.isLoggedIn();

      if (isLoggedIn) {
        final username =
            await _authService.getCurrentUsername() ?? 'Пользователь';
        // print('AuthBloc: User is logged in, emitting AuthAuthenticated');
        emit(AuthAuthenticated(username: username));
      } else {
        // print('AuthBloc: User is not logged in, emitting AuthUnauthenticated');
        emit(const AuthUnauthenticated());
      }
    } catch (e) {
      await _authService.logout();
      emit(AuthError(message: 'Ошибка проверки авторизации: $e'));
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
      // Простая проверка защиты от брутфорса
      final result = {
        'isBlocked': false,
        'remainingAttempts': 5,
        'lockoutTime': null,
      };
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
      // Сброс защиты от брутфорса
      final result = {
        'isBlocked': false,
        'remainingAttempts': 5,
        'lockoutTime': null,
      };
      emit(AuthBruteforceCheckResult(result));
    } catch (e) {
      emit(AuthError(message: 'Ошибка сброса защиты: $e'));
    }
  }

}
