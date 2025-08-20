import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../services/talker_service.dart';

// События
abstract class TalkerEvent extends Equatable {
  const TalkerEvent();

  @override
  List<Object?> get props => [];
}

class ShowErrorEvent extends TalkerEvent {
  final String message;
  final dynamic error;
  final StackTrace? stackTrace;

  const ShowErrorEvent({
    required this.message,
    this.error,
    this.stackTrace,
  });

  @override
  List<Object?> get props => [message, error, stackTrace];
}

class ShowSuccessEvent extends TalkerEvent {
  final String message;

  const ShowSuccessEvent({required this.message});

  @override
  List<Object?> get props => [message];
}

class ShowWarningEvent extends TalkerEvent {
  final String message;

  const ShowWarningEvent({required this.message});

  @override
  List<Object?> get props => [message];
}

class LogInfoEvent extends TalkerEvent {
  final String message;

  const LogInfoEvent({required this.message});

  @override
  List<Object?> get props => [message];
}

// Состояния
abstract class TalkerState extends Equatable {
  const TalkerState();

  @override
  List<Object?> get props => [];
}

class TalkerInitial extends TalkerState {}

class TalkerNotification extends TalkerState {
  final String message;
  final NotificationType type;

  const TalkerNotification({
    required this.message,
    required this.type,
  });

  @override
  List<Object?> get props => [message, type];
}

enum NotificationType {
  error,
  success,
  warning,
  info,
}

class TalkerBloc extends Bloc<TalkerEvent, TalkerState> {
  final TalkerService _talkerService;

  TalkerBloc({required TalkerService talkerService})
      : _talkerService = talkerService,
        super(TalkerInitial()) {
    on<ShowErrorEvent>(_onShowError);
    on<ShowSuccessEvent>(_onShowSuccess);
    on<ShowWarningEvent>(_onShowWarning);
    on<LogInfoEvent>(_onLogInfo);
  }

  void _onShowError(ShowErrorEvent event, Emitter<TalkerState> emit) {
    _talkerService.error(event.message, event.error, event.stackTrace);
    emit(TalkerNotification(
      message: _talkerService.getFriendlyErrorMessage(event.error ?? event.message),
      type: NotificationType.error,
    ));
  }

  void _onShowSuccess(ShowSuccessEvent event, Emitter<TalkerState> emit) {
    _talkerService.info(event.message);
    emit(TalkerNotification(
      message: event.message,
      type: NotificationType.success,
    ));
  }

  void _onShowWarning(ShowWarningEvent event, Emitter<TalkerState> emit) {
    _talkerService.warning(event.message);
    emit(TalkerNotification(
      message: event.message,
      type: NotificationType.warning,
    ));
  }

  void _onLogInfo(LogInfoEvent event, Emitter<TalkerState> emit) {
    _talkerService.info(event.message);
    emit(TalkerNotification(
      message: event.message,
      type: NotificationType.info,
    ));
  }
}
