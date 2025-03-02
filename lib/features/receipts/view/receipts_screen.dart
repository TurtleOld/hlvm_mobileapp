import 'package:flutter/material.dart';
import 'package:hlvm_mobileapp/features/receipts/view/view.dart';
import 'package:hlvm_mobileapp/services/api.dart';

class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final ApiService _apiService = ApiService();
  List _receipts = [];
  Map<String, dynamic> _seller = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReceipt();
  }

  Future<void> _fetchReceipt() async {
    try {
      final receipts = await _apiService.listReceipt();
      final seller = await _apiService.getSeller();

      setState(() {
        _receipts = receipts;
        _seller = seller;
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
        title: const Text(
          'Чеки',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
        centerTitle: true,
        actions: [
          IconButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => const FileReaderScreen()));
              },
              icon: Icon(
                Icons.upload_file_rounded,
                color: Colors.white,
              ))
        ],
      ),
      body: RefreshIndicator(
          onRefresh: _fetchReceipt,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _receipts.length,
                  itemBuilder: (context, index) {
                    final receipt = _receipts[index];
                    final seller = _seller;
                    final totalSum = receipt['total_sum'];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: InkWell(
                        // onTap: () => _onAccountTap(receipt.id),
                        child: Stack(
                          children: [
                            ListTile(
                              textColor: Colors.green,
                              title: Text(
                                seller['name_seller'],
                                textAlign: TextAlign.center,
                              ),
                              subtitle: Text(
                                "Сумма чека: $totalSum",
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  })),
    );
  }
}
