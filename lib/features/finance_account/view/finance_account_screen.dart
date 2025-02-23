import 'package:flutter/material.dart';
import 'package:hlvm_mobileapp/models/finance_account_model.dart';
import 'package:hlvm_mobileapp/services/api.dart';

class FinanceAccountScreen extends StatefulWidget {
  const FinanceAccountScreen({super.key});

  @override
  State<FinanceAccountScreen> createState() => _FinanceAccountScreenState();
}

class _FinanceAccountScreenState extends State<FinanceAccountScreen> {
  final ApiService _apiService = ApiService();
  List<FinanceAccount> _financeAccounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFinanceAccount();
  }

  Future<void> _fetchFinanceAccount() async {
    try {
      final accounts = await _apiService.fetchFinanceAccount();
      setState(() {
        _financeAccounts = accounts;
        _isLoading = false;
      });
    } catch (e) {
      print(e);
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка загрузки данных: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Список счетов',
              style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.green,
          centerTitle: true,
          actions: [
            IconButton(
                onPressed: _fetchFinanceAccount,
                icon: const Icon(
                  Icons.refresh,
                  color: Colors.white,
                ))
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _fetchFinanceAccount,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _financeAccounts.length,
                  itemBuilder: (context, index) {
                    final account = _financeAccounts[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: ListTile(
                        textColor: Colors.green,
                        title: Text(
                          account.name,
                          textAlign: TextAlign.center,
                        ),
                        subtitle: Text(
                          'Баланс: ${account.balance} ${account.currency}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }),
        ));
  }
}
