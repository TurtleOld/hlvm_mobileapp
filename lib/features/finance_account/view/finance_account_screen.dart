import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hlvm_mobileapp/features/finance_account/bloc/bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FinanceAccountScreen extends StatefulWidget {
  const FinanceAccountScreen({super.key});

  @override
  State<FinanceAccountScreen> createState() => _FinanceAccountScreenState();
}

class _FinanceAccountScreenState extends State<FinanceAccountScreen> {
  int? _selectedAccountId;

  @override
  void initState() {
    super.initState();
    _loadSelectedAccountId();
    context.read<FinanceAccountBloc>().add(LoadFinanceAccounts());
  }

  Future<void> _loadSelectedAccountId() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getInt('selectedAccountId');
    setState(() {
      _selectedAccountId = savedId;
    });
  }

  Future<void> _saveSelectedAccountId(int accountId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selectedAccountId', accountId);
  }

  void _onAccountTap(int accountId) {
    setState(() {
      _selectedAccountId = accountId;
    });
    _saveSelectedAccountId(accountId);
  }

  void _refreshAccounts() {
    context.read<FinanceAccountBloc>().add(RefreshFinanceAccounts());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Список счетов', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _refreshAccounts,
            icon: const Icon(
              Icons.refresh,
              color: Colors.white,
            ),
          ),
        ],
      ),
      body: BlocBuilder<FinanceAccountBloc, FinanceAccountState>(
        builder: (context, state) {
          if (state is FinanceAccountLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is FinanceAccountLoaded) {
            return RefreshIndicator(
              onRefresh: () async {
                context
                    .read<FinanceAccountBloc>()
                    .add(RefreshFinanceAccounts());
              },
              child: ListView.builder(
                itemCount: state.accounts.length,
                itemBuilder: (context, index) {
                  final account = state.accounts[index];
                  final isSelected = account.id == _selectedAccountId;
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: InkWell(
                      onTap: () => _onAccountTap(account.id),
                      child: Stack(
                        children: [
                          ListTile(
                            textColor: Colors.green,
                            title: Text(
                              account.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'Баланс: ${account.balance} ${account.currency}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                          if (isSelected)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          } else if (state is FinanceAccountError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Ошибка загрузки данных',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshAccounts,
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            );
          }
          return const Center(child: Text('Нет данных'));
        },
      ),
    );
  }
}
