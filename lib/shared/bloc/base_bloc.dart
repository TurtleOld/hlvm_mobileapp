import 'package:equatable/equatable.dart';

/// Базовое состояние для всех BLoC
abstract class BaseState extends Equatable {
  final bool isLoading;
  final String? error;

  const BaseState({
    this.isLoading = false,
    this.error,
  });

  @override
  List<Object?> get props => [isLoading, error];
}

/// Базовое событие для всех BLoC
abstract class BaseEvent extends Equatable {
  const BaseEvent();

  @override
  List<Object?> get props => [];
}

/// Состояние загрузки
class LoadingState extends BaseState {
  const LoadingState() : super(isLoading: true);
}

/// Состояние ошибки
class ErrorState extends BaseState {
  const ErrorState(String error) : super(error: error);
}

/// Состояние успеха
class SuccessState extends BaseState {
  const SuccessState();
}
