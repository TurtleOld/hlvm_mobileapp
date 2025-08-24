import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:hlvm_mobileapp/services/authentication.dart';
import 'package:hlvm_mobileapp/core/bloc/talker_bloc.dart';
import 'package:hlvm_mobileapp/core/utils/global_error_handler.dart';
import 'package:hlvm_mobileapp/core/services/bruteforce_protection_service.dart';
import 'package:hlvm_mobileapp/core/services/session_manager.dart';
import 'package:hlvm_mobileapp/core/services/secure_http_client.dart';
import 'package:hlvm_mobileapp/core/constants/app_constants.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import 'dart:convert';

/// Bloc для управления аутентификацией с защитой от Session Fixation
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;
  final TalkerBloc _talkerBloc;
  final BruteforceProtectionService _bruteforceProtection;
  final SessionManager _sessionManager;
  final SecureHttpClient _secureHttpClient;

  AuthBloc({
    required AuthService authService,
    required TalkerBloc talkerBloc,
    required SessionManager sessionManager,
    required SecureHttpClient secureHttpClient,
    BruteforceProtectionService? bruteforceProtection,
  })  : _authService = authService,
        _talkerBloc = talkerBloc,
        _sessionManager = sessionManager,
        _secureHttpClient = secureHttpClient,
        _bruteforceProtection =
            bruteforceProtection ?? BruteforceProtectionService(),
        super(AuthInitial()) {
    on<LoginRequested>(_onLoginRequested, transformer: droppable());
    on<LogoutRequested>(_onLogoutRequested);
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<ClearError>(_onClearError);
    on<CheckBruteforceProtection>(_onCheckBruteforceProtection);
    on<ResetBruteforceProtection>(_onResetBruteforceProtection);
    on<RefreshSession>(_onRefreshSession);
    on<ForceLogout>(_onForceLogout);
    on<ValidateSession>(_onValidateSession);
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      // Проверяем защиту от брутфорса перед попыткой входа
      final bruteforceCheck =
          await _bruteforceProtection.canAttemptLogin(event.username);

      if (!bruteforceCheck.isAllowed) {
        final remainingTime = bruteforceCheck.remainingTime;
        final hours = remainingTime?.inHours ?? 0;
        final minutes = remainingTime?.inMinutes.remainder(60) ?? 0;

        String timeMessage = '';
        if (hours > 0) {
          timeMessage = '$hours ч $minutes мин';
        } else {
          timeMessage = '$minutes мин';
        }

        final errorMessage =
            '${bruteforceCheck.reason}. Попробуйте снова через $timeMessage';
        _talkerBloc.add(ShowErrorEvent(message: errorMessage));
        emit(AuthError(message: errorMessage));
        return;
      }

      // Проверяем, нужно ли ждать перед следующей попыткой
      if (await _bruteforceProtection.shouldWait(event.username)) {
        final remainingWait =
            await _bruteforceProtection.getRemainingWaitTime(event.username);
        if (remainingWait != null) {
          final minutes = remainingWait.inMinutes;
          final seconds = remainingWait.inSeconds.remainder(60);
          final waitMessage =
              'Подождите перед следующей попыткой: $minutes мин $seconds сек';
          _talkerBloc.add(ShowErrorEvent(message: waitMessage));
          emit(AuthError(message: waitMessage));
          return;
        }
      }

      // Выполняем аутентификацию через безопасный HTTP клиент
      final result = await _performSecureLogin(event.username, event.password);

      if (result['success']) {
        // Сбрасываем счетчик попыток при успешном входе
        await _bruteforceProtection.resetAttempts(event.username);

        // Регистрируем успешную попытку входа
        await _sessionManager.recordLoginAttempt(
          username: event.username,
          success: true,
        );

        _talkerBloc.add(ShowSuccessEvent(message: 'Авторизация успешна'));
        emit(AuthAuthenticated(username: event.username));
      } else {
        // Регистрируем неудачную попытку
        await _bruteforceProtection.recordFailedAttempt(event.username);
        await _sessionManager.recordLoginAttempt(
          username: event.username,
          success: false,
        );

        final errorMessage = result['message'] ?? 'Ошибка авторизации';
        _talkerBloc.add(ShowErrorEvent(message: errorMessage));
        emit(AuthError(message: errorMessage));
      }
    } catch (e) {
      // Регистрируем неудачную попытку при ошибке
      await _bruteforceProtection.recordFailedAttempt(event.username);
      await _sessionManager.recordLoginAttempt(
        username: event.username,
        success: false,
      );

      final errorMessage = GlobalErrorHandler.handleBlocError(e);
      _talkerBloc.add(ShowErrorEvent(message: errorMessage, error: e));
      emit(AuthError(message: errorMessage));
    }
  }

  /// Выполнение безопасной аутентификации
  Future<Map<String, dynamic>> _performSecureLogin(
      String username, String password) async {
    try {
      // Проверяем настройку сервера перед выполнением запросов
      if (!await _secureHttpClient.isServerConfigured()) {
        return {
          'success': false,
          'message': AppConstants.serverAddressRequired,
        };
      }

      // 1. Выполняем аутентификацию через API
      final response = await _secureHttpClient.post(
        '/auth/login',
        body: {
          'username': username,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body) as Map<String, dynamic>;

        // 2. Сохраняем токены
        final accessToken = responseBody['access_token'] as String?;
        final refreshToken = responseBody['refresh_token'] as String?;
        final expiresIn = responseBody['expires_in'] as int?;

        if (accessToken != null) {
          // Сохраняем токены через SecureTokenStorageService
          // В реальном приложении здесь должен быть доступ к сервису хранения токенов
          // await _tokenStorageService.storeAccessToken(accessToken, expiry: expiresIn != null ? Duration(seconds: expiresIn) : null);

          if (refreshToken != null) {
            // await _tokenStorageService.storeRefreshToken(refreshToken);
          }
        }

        // 3. Создаем новую безопасную сессию
        final sessionInfo = await _sessionManager.createSecureSession(
          username: username,
          userData: responseBody['user_data'] as Map<String, dynamic>? ?? {},
          customTimeout:
              expiresIn != null ? Duration(seconds: expiresIn) : null,
        );

        return {
          'success': true,
          'sessionId': sessionInfo.sessionId,
          'message': 'Аутентификация успешна',
        };
      } else {
        final responseBody = jsonDecode(response.body) as Map<String, dynamic>?;
        return {
          'success': false,
          'message': responseBody?['message'] ?? 'Ошибка аутентификации',
        };
      }
    } catch (e) {
      // Проверяем, является ли это ошибкой о не настроенном сервере
      if (e.toString().contains(AppConstants.serverAddressRequired)) {
        return {
          'success': false,
          'message': AppConstants.serverAddressRequired,
        };
      }

      return {
        'success': false,
        'message': 'Ошибка соединения: $e',
      };
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      // Завершаем сессию через SessionManager
      await _sessionManager.logoutWithUI(event.context);

      // Выполняем logout через API
      await _authService.logout();

      _talkerBloc
          .add(ShowSuccessEvent(message: 'Вы успешно вышли из аккаунта'));
      emit(AuthUnauthenticated());
    } catch (e) {
      final errorMessage = GlobalErrorHandler.handleBlocError(e);
      _talkerBloc.add(ShowErrorEvent(message: errorMessage, error: e));
      emit(AuthError(message: errorMessage));
    }
  }

  Future<void> _onCheckAuthStatus(
    CheckAuthStatus event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      // Проверяем статус сессии через SessionManager
      final sessionValidation = await _sessionManager.validateCurrentSession();

      if (sessionValidation.isValid) {
        // Получаем информацию о сессии
        final sessionInfo = await _sessionManager.getCurrentSessionInfo();
        if (sessionInfo != null) {
          emit(AuthAuthenticated(username: sessionInfo.username));
        } else {
          emit(AuthUnauthenticated());
        }
      } else {
        // Проверяем, является ли это ошибкой сессии
        if (sessionValidation.isExpired) {
          _talkerBloc.add(ShowWarningEvent(message: 'Сессия истекла'));
          emit(AuthUnauthenticated());
        } else if (sessionValidation.isSuspicious) {
          _talkerBloc.add(
              ShowErrorEvent(message: 'Обнаружена подозрительная активность'));
          emit(AuthUnauthenticated());
        } else {
          emit(AuthUnauthenticated());
        }
      }
    } catch (e) {
      // При других ошибках проверки статуса не выходим из аккаунта автоматически
      // Пользователь может быть в офлайн режиме
      _talkerBloc.add(
          ShowWarningEvent(message: 'Ошибка проверки статуса авторизации'));
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onRefreshSession(
    RefreshSession event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      // Обновляем сессию через SessionManager
      final newSession = await _sessionManager.refreshSession();

      if (newSession != null) {
        _talkerBloc.add(ShowSuccessEvent(message: 'Сессия обновлена'));
        emit(AuthAuthenticated(username: newSession.username));
      } else {
        _talkerBloc.add(ShowErrorEvent(message: 'Не удалось обновить сессию'));
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      final errorMessage = GlobalErrorHandler.handleBlocError(e);
      _talkerBloc.add(ShowErrorEvent(message: errorMessage, error: e));
      emit(AuthError(message: errorMessage));
    }
  }

  Future<void> _onForceLogout(
    ForceLogout event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      // Принудительно завершаем сессию
      await _sessionManager.forceLogout(
        reason: event.reason,
        notifyUser: event.notifyUser,
      );

      _talkerBloc
          .add(ShowWarningEvent(message: 'Сессия завершена: ${event.reason}'));
      emit(AuthUnauthenticated());
    } catch (e) {
      final errorMessage = GlobalErrorHandler.handleBlocError(e);
      _talkerBloc.add(ShowErrorEvent(message: errorMessage, error: e));
      emit(AuthError(message: errorMessage));
    }
  }

  Future<void> _onValidateSession(
    ValidateSession event,
    Emitter<AuthState> emit,
  ) async {
    try {
      // Валидируем текущую сессию
      final validation = await _sessionManager.validateCurrentSession();

      if (validation.isValid) {
        emit(AuthSessionValid());
      } else {
        emit(AuthSessionInvalid(
            reason: validation.reason ?? 'Неизвестная ошибка'));
      }
    } catch (e) {
      final errorMessage = GlobalErrorHandler.handleBlocError(e);
      emit(AuthError(message: errorMessage));
    }
  }

  Future<void> _onCheckBruteforceProtection(
    CheckBruteforceProtection event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final result =
          await _bruteforceProtection.canAttemptLogin(event.username);
      emit(AuthBruteforceCheckResult(result));
    } catch (e) {
      final errorMessage = GlobalErrorHandler.handleBlocError(e);
      emit(AuthError(message: errorMessage));
    }
  }

  Future<void> _onResetBruteforceProtection(
    ResetBruteforceProtection event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _bruteforceProtection.resetAttempts(event.username);
      emit(AuthUnauthenticated());
    } catch (e) {
      final errorMessage = GlobalErrorHandler.handleBlocError(e);
      emit(AuthError(message: errorMessage));
    }
  }

  void _onClearError(
    ClearError event,
    Emitter<AuthState> emit,
  ) {
    if (state is AuthError) {
      emit(AuthUnauthenticated());
    }
  }

  /// Получение информации о текущей сессии
  Future<SessionInfo?> getCurrentSessionInfo() async {
    return await _sessionManager.getCurrentSessionInfo();
  }

  /// Получение статуса HTTP клиента
  Future<Map<String, dynamic>> getHttpClientStatus() async {
    return await _secureHttpClient.getClientStatus();
  }

  /// Проверка соединения с сервером
  Future<bool> checkConnection() async {
    return await _secureHttpClient.checkConnection();
  }

  /// Подписка на события сессии
  Stream<SessionEvent> get sessionEvents => _sessionManager.sessionEvents;
}
