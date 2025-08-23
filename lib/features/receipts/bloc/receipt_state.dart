import 'package:equatable/equatable.dart';

abstract class ReceiptState extends Equatable {
  const ReceiptState();

  @override
  List<Object?> get props => [];
}

class ReceiptInitial extends ReceiptState {}

class ReceiptLoading extends ReceiptState {}

class ReceiptsLoaded extends ReceiptState {
  final List<dynamic> receipts;

  const ReceiptsLoaded({required this.receipts});

  @override
  List<Object?> get props => [receipts];
}

class ReceiptUploadSuccess extends ReceiptState {
  final String message;

  const ReceiptUploadSuccess({required this.message});

  @override
  List<Object?> get props => [message];
}

class SellerInfoLoaded extends ReceiptState {
  final Map<String, dynamic> sellerInfo;

  const SellerInfoLoaded({required this.sellerInfo});

  @override
  List<Object?> get props => [sellerInfo];
}

class ReceiptSessionExpired extends ReceiptState {}

class ReceiptError extends ReceiptState {
  final String message;

  const ReceiptError({required this.message});

  @override
  List<Object?> get props => [message];
}
