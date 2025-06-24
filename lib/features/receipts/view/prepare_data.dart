import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'parser_json.dart';

class PrepareData {
  double _convertSum(dynamic number) {
    if (number is String) {
      return int.parse(number) / 100;
    } else if (number is int || number is double) {
      return number / 100;
    } else {
      throw ArgumentError('Unsupported type for conversion: $number');
    }
  }

  Future<Map<String, dynamic>> prepareData(
      Map<String, dynamic> jsonData) async {
    final storage = const FlutterSecureStorage();
    final accessToken = await storage.read(key: 'access_token');
    final prefs = await SharedPreferences.getInstance();
    final selectedAccount = prefs.getInt('selectedAccountId');
    final Map<String, dynamic> decodedToken = JwtDecoder.decode(accessToken!);
    final int userId = decodedToken['user_id'];
    // Get seller information
    final nameSeller = ParserJson.searchKey(jsonData, 'user');
    final retailPlaceAddress =
        ParserJson.searchKey(jsonData, 'retailPlaceAddress');
    final retailPlace = ParserJson.searchKey(jsonData, 'retailPlace');
    final seller = {
      'user': userId,
      'name_seller': nameSeller,
      'retail_place_address': retailPlaceAddress,
      'retail_place': retailPlace,
    };
    // Get products information
    final items = ParserJson.searchKey(jsonData, 'items', defaultValue: []);
    final List<Map<String, dynamic>> products = [];

    for (var item in items) {
      final name = ParserJson.searchKey(item, 'name');
      final amount =
          _convertSum(ParserJson.searchKey(item, 'sum', defaultValue: 0));
      final quantity = ParserJson.searchKey(item, 'quantity', defaultValue: 0);
      final price =
          _convertSum(ParserJson.searchKey(item, 'price', defaultValue: 0));
      final ndsType = ParserJson.searchKey(item, 'nds', defaultValue: 0);
      final ndsNum =
          _convertSum(ParserJson.searchKey(item, 'ndsSum', defaultValue: 0));
      products.add({
        'user': userId,
        'product_name': name,
        'amount': amount,
        'quantity': quantity,
        'price': price,
        'nds_type': ndsType,
        'nds_sum': ndsNum,
      });
    }

    final receiptDate = ParserJson.searchKey(jsonData, 'dateTime');
    final numberReceipt =
        ParserJson.searchKey(jsonData, 'fiscalDocumentNumber', defaultValue: 0);
    final nds10 =
        _convertSum(ParserJson.searchKey(jsonData, 'nds10', defaultValue: 0));
    final nds20 =
        _convertSum(ParserJson.searchKey(jsonData, 'nds20', defaultValue: 0));
    final totalSum = _convertSum(
        ParserJson.searchKey(jsonData, 'totalSum', defaultValue: 0));
    final operationType =
        ParserJson.searchKey(jsonData, 'operationType', defaultValue: 0);
    return {
      'user': userId,
      'finance_account': selectedAccount,
      'receipt_date': receiptDate,
      'number_receipt': numberReceipt,
      'nds10': nds10,
      'nds20': nds20,
      'operation_type': operationType,
      'total_sum': totalSum,
      'seller': seller,
      'product': products,
    };
  }
}
