import 'package:equatable/equatable.dart';
import '../../../models/finance_account_model.dart';

abstract class FinanceAccountState extends Equatable {
  const FinanceAccountState();

  @override
  List<Object?> get props => [];
}

class FinanceAccountInitial extends FinanceAccountState {}

class FinanceAccountLoading extends FinanceAccountState {}

class FinanceAccountLoaded extends FinanceAccountState {
  final List<FinanceAccount> accounts;

  const FinanceAccountLoaded({required this.accounts});

  @override
  List<Object?> get props => [accounts];
}

class FinanceAccountError extends FinanceAccountState {
  final String message;

  const FinanceAccountError({required this.message});

  @override
  List<Object?> get props => [message];
}

class FinanceAccountSessionExpired extends FinanceAccountState {}

class FinanceAccountOperationSuccess extends FinanceAccountState {
  final String message;
  final List<FinanceAccount> accounts;

  const FinanceAccountOperationSuccess({
    required this.message,
    required this.accounts,
  });

  @override
  List<Object?> get props => [message, accounts];
}
