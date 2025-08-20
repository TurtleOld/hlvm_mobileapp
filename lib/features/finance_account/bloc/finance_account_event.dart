import 'package:equatable/equatable.dart';

abstract class FinanceAccountEvent extends Equatable {
  const FinanceAccountEvent();

  @override
  List<Object?> get props => [];
}

class LoadFinanceAccounts extends FinanceAccountEvent {}

class RefreshFinanceAccounts extends FinanceAccountEvent {}

class AddFinanceAccount extends FinanceAccountEvent {
  final String name;
  final double balance;
  final String currency;

  const AddFinanceAccount({
    required this.name,
    required this.balance,
    required this.currency,
  });

  @override
  List<Object?> get props => [name, balance, currency];
}

class UpdateFinanceAccount extends FinanceAccountEvent {
  final String id;
  final String name;
  final double balance;
  final String currency;

  const UpdateFinanceAccount({
    required this.id,
    required this.name,
    required this.balance,
    required this.currency,
  });

  @override
  List<Object?> get props => [id, name, balance, currency];
}

class DeleteFinanceAccount extends FinanceAccountEvent {
  final String id;

  const DeleteFinanceAccount({required this.id});

  @override
  List<Object?> get props => [id];
}
