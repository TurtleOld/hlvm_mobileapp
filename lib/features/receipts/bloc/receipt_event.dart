import 'package:equatable/equatable.dart';

abstract class ReceiptEvent extends Equatable {
  const ReceiptEvent();

  @override
  List<Object?> get props => [];
}

class LoadReceipts extends ReceiptEvent {}

class RefreshReceipts extends ReceiptEvent {}

class UploadReceiptFromJson extends ReceiptEvent {
  final Map<String, dynamic> jsonData;

  const UploadReceiptFromJson({required this.jsonData});

  @override
  List<Object?> get props => [jsonData];
}

class UploadReceiptFromImage extends ReceiptEvent {
  final String imagePath;

  const UploadReceiptFromImage({required this.imagePath});

  @override
  List<Object?> get props => [imagePath];
}

class GetSellerInfo extends ReceiptEvent {
  final int sellerId;

  const GetSellerInfo({required this.sellerId});

  @override
  List<Object?> get props => [sellerId];
}
