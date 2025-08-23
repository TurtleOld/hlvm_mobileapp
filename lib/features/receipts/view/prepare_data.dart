import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'parser_json.dart';

class PrepareData {
  int _ensureInt(dynamic value) {
    if (value is int) {
      return value;
    } else if (value is String) {
      return double.parse(value).toInt();
    } else if (value is double) {
      return value.toInt();
    } else {
      throw ArgumentError('Cannot convert $value to int');
    }
  }

  double _ensureDouble(dynamic value) {
    if (value is double) {
      return value;
    } else if (value is int) {
      return value.toDouble();
    } else if (value is String) {
      return double.parse(value);
    } else {
      throw ArgumentError('Cannot convert $value to double');
    }
  }

  Future<Map<String, dynamic>> prepareData(
      Map<String, dynamic> jsonData) async {
    final storage = const FlutterSecureStorage();
    final accessToken = await storage.read(key: 'access_token');
    final prefs = await SharedPreferences.getInstance();
    final selectedAccount = prefs.getInt('selectedAccountId');
    final Map<String, dynamic> decodedToken = JwtDecoder.decode(accessToken!);
    final int userId = _ensureInt(decodedToken['user_id']);
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
          _ensureDouble(ParserJson.searchKey(item, 'sum', defaultValue: 0));
      final quantity = _ensureDouble(
          ParserJson.searchKey(item, 'quantity', defaultValue: 0));
      final price =
          _ensureDouble(ParserJson.searchKey(item, 'price', defaultValue: 0));
      final ndsType =
          _ensureInt(ParserJson.searchKey(item, 'nds', defaultValue: 0));
      final ndsNum =
          _ensureDouble(ParserJson.searchKey(item, 'ndsSum', defaultValue: 0));
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
    final numberReceipt = _ensureInt(ParserJson.searchKey(
        jsonData, 'fiscalDocumentNumber',
        defaultValue: 0));
    final nds10 =
        _ensureDouble(ParserJson.searchKey(jsonData, 'nds10', defaultValue: 0));
    final nds20 =
        _ensureDouble(ParserJson.searchKey(jsonData, 'nds20', defaultValue: 0));
    final totalSum = _ensureDouble(
        ParserJson.searchKey(jsonData, 'totalSum', defaultValue: 0));
    final operationType = _ensureInt(
        ParserJson.searchKey(jsonData, 'operationType', defaultValue: 0));

    final result = {
      'user': userId,
      'finance_account': selectedAccount ?? 0,
      'receipt_date': receiptDate,
      'number_receipt': numberReceipt,
      'nds10': nds10,
      'nds20': nds20,
      'operation_type': operationType,
      'total_sum': totalSum,
      'seller': seller,
      'product': products,
    };

    return result;
  }
}
