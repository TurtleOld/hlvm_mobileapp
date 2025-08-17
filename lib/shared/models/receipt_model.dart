import 'base_model.dart';

class Receipt extends BaseModel {
  Receipt({
    required this.id,
    required this.totalSum,
    required this.receiptDate,
    required this.seller,
    required this.products,
  });

  final int id;
  final double totalSum;
  final DateTime receiptDate;
  final String seller;
  final List<ReceiptProduct> products;

  factory Receipt.fromJson(Map<String, dynamic> json) {
    return Receipt(
      id: json['id'] ?? 0,
      totalSum: (json['total_sum'] ?? 0).toDouble(),
      receiptDate: DateTime.parse(
          json['receipt_date'] ?? DateTime.now().toIso8601String()),
      seller: json['seller'] ?? '',
      products: (json['product'] as List<dynamic>?)
              ?.map((product) => ReceiptProduct.fromJson(product))
              .toList() ??
          [],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'total_sum': totalSum,
      'receipt_date': receiptDate.toIso8601String(),
      'seller': seller,
      'product': products.map((product) => product.toJson()).toList(),
    };
  }
}

class ReceiptProduct extends BaseModel {
  ReceiptProduct({
    required this.name,
    required this.price,
    required this.quantity,
  });

  final String name;
  final double price;
  final int quantity;

  factory ReceiptProduct.fromJson(Map<String, dynamic> json) {
    return ReceiptProduct(
      name: json['product_name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      quantity: json['quantity'] ?? 1,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'product_name': name,
      'price': price,
      'quantity': quantity,
    };
  }
}
