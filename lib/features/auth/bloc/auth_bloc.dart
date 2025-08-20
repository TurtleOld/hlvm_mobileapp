import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:hlvm_mobileapp/services/authentication.dart';
import 'package:hlvm_mobileapp/core/bloc/talker_bloc.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;
  final TalkerBloc _talkerBloc;

  AuthBloc({
    required AuthService authService,
    required TalkerBloc talkerBloc,
  })  : _authService = authService,
        _talkerBloc = talkerBloc,
        super(AuthInitial()) {
    on<LoginRequested>(_onLoginRequested, transformer: droppable());
    on<LogoutRequested>(_onLogoutRequested);
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<ClearError>(_onClearError);
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      final result = await _authService.login(
        event.username,
        event.password,
      );

      if (result['success']) {
        _talkerBloc.add(ShowSuccessEvent(message: 'Авторизация успешна'));
        emit(AuthAuthenticated(username: event.username));
      } else {
        final errorMessage = result['message'] ?? 'Ошибка авторизации';
        _talkerBloc.add(ShowErrorEvent(message: errorMessage));
        emit(AuthError(message: errorMessage));
      }
    } catch (e) {
      _talkerBloc.add(ShowErrorEvent(message: 'Ошибка авторизации', error: e));
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      await _authService.logout();
      _talkerBloc
          .add(ShowSuccessEvent(message: 'Вы успешно вышли из аккаунта'));
      emit(AuthUnauthenticated());
    } catch (e) {
      _talkerBloc.add(ShowErrorEvent(message: 'Ошибка при выходе', error: e));
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onCheckAuthStatus(
    CheckAuthStatus event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      final isLoggedIn = await _authService.isLoggedIn();
      if (isLoggedIn) {
        // Получаем имя пользователя из токена или хранилища
        final username = await _authService.getCurrentUsername();
        emit(AuthAuthenticated(username: username ?? 'Пользователь'));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      // При ошибках проверки статуса не выходим из аккаунта автоматически
      // Пользователь может быть в офлайн режиме
      _talkerBloc.add(
          ShowWarningEvent(message: 'Ошибка проверки статуса авторизации'));
      emit(AuthUnauthenticated());
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
}
