class FinanceAccount {
  FinanceAccount(
      {required this.id,
      required this.name,
      required this.balance,
      required this.currency});

  final int id;
  final String name;
  final String balance;
  final String currency;

  factory FinanceAccount.fromJson(Map<String, dynamic> json) {
    return FinanceAccount(
        id: json['id'],
        name: json['name_account'],
        balance: json['balance'],
        currency: json['currency']);
  }
}
