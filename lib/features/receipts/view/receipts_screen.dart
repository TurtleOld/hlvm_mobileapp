import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hlvm_mobileapp/features/receipts/view/view.dart';
import 'package:hlvm_mobileapp/services/api.dart';
import 'package:intl/intl.dart';

class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _receiptsWithSellers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReceipt();
  }

  Future<void> _fetchReceipt() async {
    try {
      final receipts = await _apiService.listReceipt();
      List<Map<String, dynamic>> receiptsData = [];

      for (var receipt in receipts) {
        final seller = await _apiService.getSeller(receipt['seller']);
        receiptsData.add({
          'receipt': receipt,
          'seller': seller,
        });
      }

      setState(() {
        _receiptsWithSellers = receiptsData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка загрузки данных: $e')));
    }
  }

  void _showReceiptDetailsDialog(
      BuildContext context, Map<String, dynamic> receipt, String seller) {
    final totalSum = receipt['total_sum'];
    final dateString = receipt['receipt_date'];
    DateTime dateTime = DateTime.parse(dateString);
    String formattedDate = DateFormat('dd.MM.yyyy HH:mm').format(dateTime);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            seller,
            style: GoogleFonts.montserrat(fontSize: 13),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Дата: $formattedDate",
                  style: GoogleFonts.montserrat(fontSize: 11),
                ),
                Text(
                  "Сумма чека: $totalSum",
                  style: GoogleFonts.montserrat(fontSize: 11),
                ),
                const SizedBox(height: 10),
                Text(
                  "Товары:",
                  style: GoogleFonts.montserrat(
                      fontSize: 11, fontWeight: FontWeight.bold),
                ),
                ..._buildItemList(receipt['product']),
                // Добавляем список товаров
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                "Закрыть",
                style:
                    GoogleFonts.montserrat(color: Colors.green, fontSize: 14),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildItemList(List<dynamic> items) {
    return items.map((item) {
      return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item['product_name'],
                  style: GoogleFonts.montserrat(fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              Text(
                "${item['quantity']} x ${item['price']}",
                style: GoogleFonts.montserrat(fontSize: 11),
              ),
            ],
          ));
    }).toList();
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
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const ImageCaptureScreen()));
            },
            icon: Icon(
              Icons.photo_camera_back,
              color: Colors.white,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchReceipt,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: _receiptsWithSellers.length,
                itemBuilder: (context, index) {
                  final receiptData = _receiptsWithSellers[index];
                  final receipt = receiptData['receipt'];
                  final seller = receiptData['seller']['name_seller'];
                  final totalSum = receipt['total_sum'];
                  final dateString = receipt['receipt_date'];
                  DateTime dateTime = DateTime.parse(dateString);
                  String formattedDate =
                      DateFormat('dd.MM.yyyy HH:mm').format(dateTime);

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: InkWell(
                      onTap: () {
                        _showReceiptDetailsDialog(context, receipt, seller);
                      },
                      child: ListTile(
                        textColor: Colors.green,
                        title: Text(
                          seller,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                              fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          "Дата: $formattedDate Сумма чека: $totalSum",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                              fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
