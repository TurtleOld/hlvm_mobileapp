import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    print('DEBUG: === PREPARE DATA START ===');
    print('DEBUG: Input jsonData: $jsonData');
    print('DEBUG: Input keys: ${jsonData.keys.toList()}');
    
    const storage = FlutterSecureStorage();
    final accessToken = await storage.read(key: 'access_token');
    final prefs = await SharedPreferences.getInstance();
    final selectedAccount = prefs.getInt('selectedAccountId');
    final Map<String, dynamic> decodedToken = JwtDecoder.decode(accessToken!);
    final int userId = _ensureInt(decodedToken['user_id']);
    
    print('DEBUG: userId: $userId');
    print('DEBUG: selectedAccount: $selectedAccount');

    // Get seller information from AI response
    final nameSeller = jsonData['name_seller']?.toString() ?? '';
    final retailPlaceAddress =
        jsonData['retail_place_address']?.toString() ?? '';
    final retailPlace = jsonData['retail_place']?.toString() ?? '';
    final seller = {
      'user': userId,
      'name_seller': nameSeller,
      'retail_place_address': retailPlaceAddress,
      'retail_place': retailPlace,
    };
    
    // Get products information from AI response
    final items =
        jsonData['product'] ?? []; // Changed from 'items' to 'product'
    final List<Map<String, dynamic>> products = [];

    print('DEBUG: Processing ${items.length} items from AI response');

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final name = item['name']?.toString() ?? '';
      final price = _ensureDouble(item['price'] ?? 0);
      final quantity = _ensureDouble(item['quantity'] ?? 1);
      final category = item['category']?.toString() ?? '';

      // Calculate amount if not provided
      final amount = price * quantity;

      print(
          'DEBUG: Item $i: name="$name", price=$price, quantity=$quantity, amount=$amount');

      // Валидация данных
      if (price <= 0) {
        print('DEBUG: WARNING - Item $i has invalid price: $price');
      }
      if (quantity <= 0) {
        print('DEBUG: WARNING - Item $i has invalid quantity: $quantity');
      }
      if (amount <= 0) {
        print('DEBUG: WARNING - Item $i has invalid amount: $amount');
      }
      
      products.add({
        'user': userId,
        'product_name': name,
        'amount': amount,
        'quantity': quantity,
        'price': price,
        'category': category,
        'nds_type': 0, // Default NDS type
        'nds_sum': 0, // Default NDS sum
      });
    }

    // Преобразуем дату из DD.MM.YYYY HH:MM в YYYY-MM-DDTHH:MM:SS
    String receiptDate = jsonData['receipt_date']?.toString() ?? '';
    print('DEBUG: Original receipt_date: "$receiptDate"');

    if (receiptDate.isNotEmpty && receiptDate != 'Не указано') {
      try {
        // Парсим дату из формата DD.MM.YYYY HH:MM
        final parts = receiptDate.split(' ');
        if (parts.length == 2) {
          final dateParts = parts[0].split('.');
          final timeParts = parts[1].split(':');

          if (dateParts.length == 3 && timeParts.length >= 2) {
            final day = dateParts[0].padLeft(2, '0');
            final month = dateParts[1].padLeft(2, '0');
            final year = dateParts[2];
            final hour = timeParts[0].padLeft(2, '0');
            final minute = timeParts[1].padLeft(2, '0');
            final second =
                timeParts.length > 2 ? timeParts[2].padLeft(2, '0') : '00';

            // Преобразуем в YYYY-MM-DDTHH:MM:SS
            receiptDate = '$year-$month-${day}T$hour:$minute:$second';
            print('DEBUG: Converted date to ISO format: $receiptDate');
          }
        } else if (receiptDate.contains('.')) {
          // Парсим только дату DD.MM.YYYY
          final dateParts = receiptDate.split('.');
          if (dateParts.length == 3) {
            final day = dateParts[0].padLeft(2, '0');
            final month = dateParts[1].padLeft(2, '0');
            final year = dateParts[2];
            receiptDate = '$year-$month-${day}T00:00:00';
            print('DEBUG: Converted date-only to ISO format: $receiptDate');
          }
        }
      } catch (e) {
        print('DEBUG: Error converting date format: $e');
        // Если не удалось преобразовать, используем текущую дату
        receiptDate = DateTime.now().toIso8601String();
        print('DEBUG: Using current date: $receiptDate');
      }
    } else {
      // Если дата пустая или "Не указано", используем текущую дату
      receiptDate = DateTime.now().toIso8601String();
      print(
          'DEBUG: Date is empty or "Не указано", using current date: $receiptDate');
    }

    final numberReceipt = _ensureInt(jsonData['number_receipt'] ?? 0);
    final nds10 = _ensureDouble(jsonData['nds10'] ?? 0);
    final nds20 = _ensureDouble(jsonData['nds20'] ?? 0);
    final totalSum = _ensureDouble(jsonData['total_sum'] ?? 0);
    final operationType = _ensureInt(jsonData['operation_type'] ?? 1);

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

    print('DEBUG: === PREPARE DATA RESULT ===');
    print('DEBUG: Final result: $result');
    print('DEBUG: Result keys: ${result.keys.toList()}');
    print('DEBUG: seller: ${result['seller']}');
    print('DEBUG: product count: ${(result['product'] as List).length}');
    print('DEBUG: === END PREPARE DATA ===');

    return result;
  }
}
