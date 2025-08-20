import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../services/api.dart';
import '../../../core/bloc/talker_bloc.dart';
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
    on<LoadFinanceAccounts>(_onLoadFinanceAccounts);
    on<RefreshFinanceAccounts>(_onRefreshFinanceAccounts);
    on<AddFinanceAccount>(_onAddFinanceAccount);
    on<UpdateFinanceAccount>(_onUpdateFinanceAccount);
    on<DeleteFinanceAccount>(_onDeleteFinanceAccount);
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
      _talkerBloc
          .add(ShowErrorEvent(message: 'Ошибка загрузки счетов', error: e));
      emit(FinanceAccountError(message: e.toString()));
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
      _talkerBloc
          .add(ShowErrorEvent(message: 'Ошибка обновления счетов', error: e));
      emit(FinanceAccountError(message: e.toString()));
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

      _talkerBloc.add(ShowSuccessEvent(message: 'Счет успешно создан'));
      emit(FinanceAccountOperationSuccess(
        message: 'Счет успешно создан',
        accounts: accounts,
      ));
    } catch (e) {
      _talkerBloc
          .add(ShowErrorEvent(message: 'Ошибка создания счета', error: e));
      emit(FinanceAccountError(message: e.toString()));
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

      _talkerBloc.add(ShowSuccessEvent(message: 'Счет успешно обновлен'));
      emit(FinanceAccountOperationSuccess(
        message: 'Счет успешно обновлен',
        accounts: accounts,
      ));
    } catch (e) {
      _talkerBloc
          .add(ShowErrorEvent(message: 'Ошибка обновления счета', error: e));
      emit(FinanceAccountError(message: e.toString()));
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

      _talkerBloc.add(ShowSuccessEvent(message: 'Счет успешно удален'));
      emit(FinanceAccountOperationSuccess(
        message: 'Счет успешно удален',
        accounts: accounts,
      ));
    } catch (e) {
      _talkerBloc
          .add(ShowErrorEvent(message: 'Ошибка удаления счета', error: e));
      emit(FinanceAccountError(message: e.toString()));
    }
  }
}
