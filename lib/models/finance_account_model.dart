import '../shared/models/base_model.dart';

class FinanceAccount extends BaseModel {
  FinanceAccount({
    required this.id,
    required this.name,
    required this.balance,
    required this.currency,
  });

  final int id;
  final String name;
  final String balance;
  final String currency;

  factory FinanceAccount.fromJson(Map<String, dynamic> json) {
    return FinanceAccount(
      id: json['id'] ?? 0,
      name: json['name_account'] ?? '',
      balance: json['balance'] ?? '0',
      currency: json['currency'] ?? '',
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name_account': name,
      'balance': balance,
      'currency': currency,
    };
  }
}
