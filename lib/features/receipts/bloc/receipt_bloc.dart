import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import '../../../services/api.dart';
import '../../../core/bloc/talker_bloc.dart';
import '../../../core/utils/global_error_handler.dart';
import '../../../core/services/cache_service.dart';
import '../../../core/services/receipt_storage_service.dart';
import 'receipt_event.dart';
import 'receipt_state.dart';

class ReceiptBloc extends Bloc<ReceiptEvent, ReceiptState> {
  final ApiService _apiService;
  final TalkerBloc _talkerBloc;
  final CacheService _cacheService;
  final ReceiptStorageService _receiptStorageService;

  ReceiptBloc({
    required ApiService apiService,
    required TalkerBloc talkerBloc,
    required CacheService cacheService,
  })  : _apiService = apiService,
        _talkerBloc = talkerBloc,
        _cacheService = cacheService,
        _receiptStorageService = ReceiptStorageService(),
        super(ReceiptInitial()) {
    on<LoadReceipts>(_onLoadReceipts, transformer: droppable());
    on<RefreshReceipts>(_onRefreshReceipts, transformer: droppable());
    on<UploadReceiptFromJson>(_onUploadReceiptFromJson,
        transformer: droppable());
    on<UploadReceiptFromImage>(_onUploadReceiptFromImage,
        transformer: droppable());
    on<GetSellerInfo>(_onGetSellerInfo, transformer: droppable());
    on<DeleteReceipt>(_onDeleteReceipt, transformer: droppable());
  }

  Future<void> _onLoadReceipts(
    LoadReceipts event,
    Emitter<ReceiptState> emit,
  ) async {
    emit(ReceiptLoading());

    try {
      // Сначала пытаемся загрузить из кеша
      final cachedReceipts = await _cacheService.getCachedReceipts();
      if (cachedReceipts != null) {
        emit(ReceiptsLoaded(receipts: cachedReceipts));
        _talkerBloc.add(const ShowSuccessEvent(message: 'Данные загружены из кеша'));
      }

      // Затем загружаем свежие данные с сервера
      final receipts = await _apiService.listReceipt();

      // Кешируем новые данные
      await _cacheService.cacheReceipts(receipts);

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

      // Обновляем кеш при принудительном обновлении
      await _cacheService.cacheReceipts(receipts);

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
      
      if (result['success'] == true) {
        // Сохраняем ID чека локально, если он есть
        final receiptId = result['receipt_id'];
        if (receiptId != null) {
          await _receiptStorageService.saveReceiptId(receiptId, event.jsonData);
        }

        _talkerBloc.add(ShowSuccessEvent(message: result['message']));
        emit(ReceiptUploadSuccess(message: result['message']));
      } else if (result['message'].contains('авторизации')) {
        // Для ошибок авторизации показываем предупреждение, а не ошибку
        _talkerBloc.add(ShowWarningEvent(message: result['message']));
        emit(ReceiptError(message: result['message']));
      } else {
        _talkerBloc.add(ShowErrorEvent(message: result['message']));
        emit(ReceiptError(message: result['message']));
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
          .add(const ShowSuccessEvent(message: 'Изображение успешно обработано'));
      emit(const ReceiptUploadSuccess(message: 'Изображение успешно обработано'));
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
      // Сначала пытаемся загрузить из кеша
      final cachedSellerInfo =
          await _cacheService.getCachedSellerInfo(event.sellerId);
      if (cachedSellerInfo != null) {
        emit(SellerInfoLoaded(sellerInfo: cachedSellerInfo));
        _talkerBloc.add(const ShowSuccessEvent(
            message: 'Информация о продавце загружена из кеша'));
      }

      // Затем загружаем свежие данные с сервера
      final sellerInfo = await _apiService.getSeller(event.sellerId);

      // Кешируем новые данные
      await _cacheService.cacheSellerInfo(event.sellerId, sellerInfo);

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

  Future<void> _onDeleteReceipt(
    DeleteReceipt event,
    Emitter<ReceiptState> emit,
  ) async {
    emit(ReceiptLoading());

    try {
      final result = await _apiService.deleteReceipt(event.receiptId);

      if (result['success'] == true) {
        // Удаляем ID чека из локального хранилища
        await _receiptStorageService.removeReceiptId(event.receiptId);

        _talkerBloc.add(ShowSuccessEvent(message: result['message']));
        emit(ReceiptDeleteSuccess(message: result['message']));

        // Обновляем список чеков после удаления
        add(RefreshReceipts());
      } else {
        _talkerBloc.add(ShowErrorEvent(message: result['message']));
        emit(ReceiptError(message: result['message']));
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
          message: 'Ошибка удаления чека: $errorMessage',
          error: e,
        ));
        emit(ReceiptError(message: errorMessage));
      }
    }
  }
}
