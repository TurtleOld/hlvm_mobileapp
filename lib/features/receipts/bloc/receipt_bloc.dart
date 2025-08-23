import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import '../../../services/api.dart';
import '../../../core/bloc/talker_bloc.dart';
import '../../../core/utils/global_error_handler.dart';
import 'receipt_event.dart';
import 'receipt_state.dart';

class ReceiptBloc extends Bloc<ReceiptEvent, ReceiptState> {
  final ApiService _apiService;
  final TalkerBloc _talkerBloc;

  ReceiptBloc({
    required ApiService apiService,
    required TalkerBloc talkerBloc,
  })  : _apiService = apiService,
        _talkerBloc = talkerBloc,
        super(ReceiptInitial()) {
    on<LoadReceipts>(_onLoadReceipts, transformer: droppable());
    on<RefreshReceipts>(_onRefreshReceipts, transformer: droppable());
    on<UploadReceiptFromJson>(_onUploadReceiptFromJson,
        transformer: droppable());
    on<UploadReceiptFromImage>(_onUploadReceiptFromImage,
        transformer: droppable());
    on<GetSellerInfo>(_onGetSellerInfo, transformer: droppable());
  }

  Future<void> _onLoadReceipts(
    LoadReceipts event,
    Emitter<ReceiptState> emit,
  ) async {
    emit(ReceiptLoading());

    try {
      final receipts = await _apiService.listReceipt();
      emit(ReceiptsLoaded(receipts: receipts));
    } catch (e) {
      final errorMessage = GlobalErrorHandler.handleBlocError(e);

      if (GlobalErrorHandler.isSessionExpiredError(e)) {
        _talkerBloc.add(ShowErrorEvent(
          message: 'Сессия истекла. Пожалуйста, войдите снова.',
          error: e,
        ));
        emit(ReceiptSessionExpired());
      } else {
        _talkerBloc.add(ShowErrorEvent(
          message: 'Ошибка загрузки чеков: $errorMessage',
          error: e,
        ));
        emit(ReceiptError(message: errorMessage));
      }
    }
  }

  Future<void> _onRefreshReceipts(
    RefreshReceipts event,
    Emitter<ReceiptState> emit,
  ) async {
    try {
      final receipts = await _apiService.listReceipt();
      emit(ReceiptsLoaded(receipts: receipts));
    } catch (e) {
      final errorMessage = GlobalErrorHandler.handleBlocError(e);

      if (GlobalErrorHandler.isSessionExpiredError(e)) {
        _talkerBloc.add(ShowErrorEvent(
          message: 'Сессия истекла. Пожалуйста, войдите снова.',
          error: e,
        ));
        emit(ReceiptSessionExpired());
      } else {
        _talkerBloc.add(ShowErrorEvent(
          message: 'Ошибка обновления чеков: $errorMessage',
          error: e,
        ));
        emit(ReceiptError(message: errorMessage));
      }
    }
  }

  Future<void> _onUploadReceiptFromJson(
    UploadReceiptFromJson event,
    Emitter<ReceiptState> emit,
  ) async {
    emit(ReceiptLoading());

    try {
      final result = await _apiService.createReceipt(event.jsonData);
      if (result.contains('успешно')) {
        _talkerBloc.add(ShowSuccessEvent(message: result));
        emit(ReceiptUploadSuccess(message: result));
      } else if (result.contains('авторизации')) {
        // Для ошибок авторизации показываем предупреждение, а не ошибку
        _talkerBloc.add(ShowWarningEvent(message: result));
        emit(ReceiptError(message: result));
      } else {
        _talkerBloc.add(ShowErrorEvent(message: result));
        emit(ReceiptUploadSuccess(message: result));
      }
    } catch (e) {
      final errorMessage = GlobalErrorHandler.handleBlocError(e);

      if (GlobalErrorHandler.isSessionExpiredError(e)) {
        _talkerBloc.add(ShowErrorEvent(
          message: 'Сессия истекла. Пожалуйста, войдите снова.',
          error: e,
        ));
        emit(ReceiptSessionExpired());
      } else {
        _talkerBloc.add(ShowErrorEvent(
          message: 'Ошибка загрузки чека: $errorMessage',
          error: e,
        ));
        emit(ReceiptError(message: errorMessage));
      }
    }
  }

  Future<void> _onUploadReceiptFromImage(
    UploadReceiptFromImage event,
    Emitter<ReceiptState> emit,
  ) async {
    emit(ReceiptLoading());

    try {
      // TODO: Добавить обработку изображения
      // Пока просто эмулируем успешную загрузку
      _talkerBloc
          .add(ShowSuccessEvent(message: 'Изображение успешно обработано'));
      emit(ReceiptUploadSuccess(message: 'Изображение успешно обработано'));
    } catch (e) {
      final errorMessage = GlobalErrorHandler.handleBlocError(e);

      if (GlobalErrorHandler.isSessionExpiredError(e)) {
        _talkerBloc.add(ShowErrorEvent(
          message: 'Сессия истекла. Пожалуйста, войдите снова.',
          error: e,
        ));
        emit(ReceiptSessionExpired());
      } else {
        _talkerBloc.add(ShowErrorEvent(
          message: 'Ошибка обработки изображения: $errorMessage',
          error: e,
        ));
        emit(ReceiptError(message: errorMessage));
      }
    }
  }

  Future<void> _onGetSellerInfo(
    GetSellerInfo event,
    Emitter<ReceiptState> emit,
  ) async {
    emit(ReceiptLoading());

    try {
      final sellerInfo = await _apiService.getSeller(event.sellerId);
      emit(SellerInfoLoaded(sellerInfo: sellerInfo));
    } catch (e) {
      final errorMessage = GlobalErrorHandler.handleBlocError(e);

      if (GlobalErrorHandler.isSessionExpiredError(e)) {
        _talkerBloc.add(ShowErrorEvent(
          message: 'Сессия истекла. Пожалуйста, войдите снова.',
          error: e,
        ));
        emit(ReceiptSessionExpired());
      } else {
        _talkerBloc.add(ShowErrorEvent(
          message: 'Ошибка получения информации о продавце: $errorMessage',
          error: e,
        ));
        emit(ReceiptError(message: errorMessage));
      }
    }
  }
}
