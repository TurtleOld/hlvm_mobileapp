import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import '../../../services/api.dart';
import '../../../core/bloc/talker_bloc.dart';
import '../../../core/utils/global_error_handler.dart';
import 'finance_account_event.dart';
import 'finance_account_state.dart';

class FinanceAccountBloc
    extends Bloc<FinanceAccountEvent, FinanceAccountState> {
  final ApiService _apiService;
  final TalkerBloc _talkerBloc;

  FinanceAccountBloc({
    required ApiService apiService,
    required TalkerBloc talkerBloc,
  })  : _apiService = apiService,
        _talkerBloc = talkerBloc,
        super(FinanceAccountInitial()) {
    on<LoadFinanceAccounts>(_onLoadFinanceAccounts, transformer: droppable());
    on<RefreshFinanceAccounts>(_onRefreshFinanceAccounts,
        transformer: droppable());
    on<AddFinanceAccount>(_onAddFinanceAccount, transformer: droppable());
    on<UpdateFinanceAccount>(_onUpdateFinanceAccount, transformer: droppable());
    on<DeleteFinanceAccount>(_onDeleteFinanceAccount, transformer: droppable());
  }

  Future<void> _onLoadFinanceAccounts(
    LoadFinanceAccounts event,
    Emitter<FinanceAccountState> emit,
  ) async {
    emit(FinanceAccountLoading());

    try {
      final accounts = await _apiService.fetchFinanceAccount();
      emit(FinanceAccountLoaded(accounts: accounts));
    } catch (e) {
      final errorMessage = GlobalErrorHandler.handleBlocError(e);

      // Если это ошибка сессии, показываем специальное сообщение
      if (GlobalErrorHandler.isSessionExpiredError(e)) {
        _talkerBloc.add(ShowErrorEvent(
          message: 'Сессия истекла. Пожалуйста, войдите снова.',
          error: e,
        ));
        emit(FinanceAccountSessionExpired());
      } else {
        _talkerBloc.add(ShowErrorEvent(
          message: 'Ошибка загрузки счетов: $errorMessage',
          error: e,
        ));
        emit(FinanceAccountError(message: errorMessage));
      }
    }
  }

  Future<void> _onRefreshFinanceAccounts(
    RefreshFinanceAccounts event,
    Emitter<FinanceAccountState> emit,
  ) async {
    try {
      final accounts = await _apiService.fetchFinanceAccount();
      emit(FinanceAccountLoaded(accounts: accounts));
    } catch (e) {
      final errorMessage = GlobalErrorHandler.handleBlocError(e);

      if (GlobalErrorHandler.isSessionExpiredError(e)) {
        _talkerBloc.add(ShowErrorEvent(
          message: 'Сессия истекла. Пожалуйста, войдите снова.',
          error: e,
        ));
        emit(FinanceAccountSessionExpired());
      } else {
        _talkerBloc.add(ShowErrorEvent(
          message: 'Ошибка обновления счетов: $errorMessage',
          error: e,
        ));
        emit(FinanceAccountError(message: errorMessage));
      }
    }
  }

  Future<void> _onAddFinanceAccount(
    AddFinanceAccount event,
    Emitter<FinanceAccountState> emit,
  ) async {
    emit(FinanceAccountLoading());

    try {
      // TODO: Добавить метод createFinanceAccount в ApiService
      // final accountData = {
      //   'name_account': event.name,
      //   'balance': event.balance.toString(),
      //   'currency': event.currency,
      // };
      // await _apiService.createFinanceAccount(accountData);

      // Пока просто обновляем список
      final accounts = await _apiService.fetchFinanceAccount();

      _talkerBloc.add(const ShowSuccessEvent(message: 'Счет успешно создан'));
      emit(FinanceAccountOperationSuccess(
        message: 'Счет успешно создан',
        accounts: accounts,
      ));
    } catch (e) {
      final errorMessage = GlobalErrorHandler.handleBlocError(e);

      if (GlobalErrorHandler.isSessionExpiredError(e)) {
        _talkerBloc.add(ShowErrorEvent(
          message: 'Сессия истекла. Пожалуйста, войдите снова.',
          error: e,
        ));
        emit(FinanceAccountSessionExpired());
      } else {
        _talkerBloc.add(ShowErrorEvent(
          message: 'Ошибка создания счета: $errorMessage',
          error: e,
        ));
        emit(FinanceAccountError(message: errorMessage));
      }
    }
  }

  Future<void> _onUpdateFinanceAccount(
    UpdateFinanceAccount event,
    Emitter<FinanceAccountState> emit,
  ) async {
    emit(FinanceAccountLoading());

    try {
      // TODO: Добавить метод updateFinanceAccount в ApiService
      // await _apiService.updateFinanceAccount(event.id, accountData);

      final accounts = await _apiService.fetchFinanceAccount();

      _talkerBloc.add(const ShowSuccessEvent(message: 'Счет успешно обновлен'));
      emit(FinanceAccountOperationSuccess(
        message: 'Счет успешно обновлен',
        accounts: accounts,
      ));
    } catch (e) {
      final errorMessage = GlobalErrorHandler.handleBlocError(e);

      if (GlobalErrorHandler.isSessionExpiredError(e)) {
        _talkerBloc.add(ShowErrorEvent(
          message: 'Сессия истекла. Пожалуйста, войдите снова.',
          error: e,
        ));
        emit(FinanceAccountSessionExpired());
      } else {
        _talkerBloc.add(ShowErrorEvent(
          message: 'Ошибка обновления счета: $errorMessage',
          error: e,
        ));
        emit(FinanceAccountError(message: errorMessage));
      }
    }
  }

  Future<void> _onDeleteFinanceAccount(
    DeleteFinanceAccount event,
    Emitter<FinanceAccountState> emit,
  ) async {
    emit(FinanceAccountLoading());

    try {
      // TODO: Добавить метод deleteFinanceAccount в ApiService
      // await _apiService.deleteFinanceAccount(event.id);

      final accounts = await _apiService.fetchFinanceAccount();

      _talkerBloc.add(const ShowSuccessEvent(message: 'Счет успешно удален'));
      emit(FinanceAccountOperationSuccess(
        message: 'Счет успешно удален',
        accounts: accounts,
      ));
    } catch (e) {
      final errorMessage = GlobalErrorHandler.handleBlocError(e);

      if (GlobalErrorHandler.isSessionExpiredError(e)) {
        _talkerBloc.add(ShowErrorEvent(
          message: 'Сессия истекла. Пожалуйста, войдите снова.',
          error: e,
        ));
        emit(FinanceAccountSessionExpired());
      } else {
        _talkerBloc.add(ShowErrorEvent(
          message: 'Ошибка удаления счета: $errorMessage',
          error: e,
        ));
        emit(FinanceAccountError(message: errorMessage));
      }
    }
  }
}
