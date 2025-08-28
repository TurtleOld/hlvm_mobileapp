import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ReceiptStorageService {
  static const String _receiptIdsKey = 'created_receipt_ids';
  static const String _receiptDataKey = 'receipt_data_';

  Future<void> saveReceiptId(int receiptId, Map<String, dynamic> receiptData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final existingIdsJson = prefs.getString(_receiptIdsKey);
      List<int> existingIds = [];
      
      if (existingIdsJson != null) {
        final List<dynamic> decoded = jsonDecode(existingIdsJson);
        existingIds = decoded.cast<int>();
      }
      
      if (!existingIds.contains(receiptId)) {
        existingIds.add(receiptId);
        
        await prefs.setString(_receiptIdsKey, jsonEncode(existingIds));
        
        await prefs.setString('$_receiptDataKey$receiptId', jsonEncode(receiptData));
        
        print('DEBUG: Saved receipt ID: $receiptId');
      }
    } catch (e) {
      print('DEBUG: Error saving receipt ID: $e');
    }
  }

  Future<List<int>> getReceiptIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingIdsJson = prefs.getString(_receiptIdsKey);
      
      if (existingIdsJson != null) {
        final List<dynamic> decoded = jsonDecode(existingIdsJson);
        return decoded.cast<int>();
      }
    } catch (e) {
      print('DEBUG: Error getting receipt IDs: $e');
    }
    
    return [];
  }

  Future<Map<String, dynamic>?> getReceiptData(int receiptId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final receiptDataJson = prefs.getString('$_receiptDataKey$receiptId');
      
      if (receiptDataJson != null) {
        return jsonDecode(receiptDataJson) as Map<String, dynamic>;
      }
    } catch (e) {
      print('DEBUG: Error getting receipt data: $e');
    }
    
    return null;
  }

  Future<void> removeReceiptId(int receiptId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final existingIdsJson = prefs.getString(_receiptIdsKey);
      if (existingIdsJson != null) {
        final List<dynamic> decoded = jsonDecode(existingIdsJson);
        List<int> existingIds = decoded.cast<int>();
        
        existingIds.remove(receiptId);
        
        await prefs.setString(_receiptIdsKey, jsonEncode(existingIds));
        
        await prefs.remove('$_receiptDataKey$receiptId');
        
        print('DEBUG: Removed receipt ID: $receiptId');
      }
    } catch (e) {
      print('DEBUG: Error removing receipt ID: $e');
    }
  }

  Future<void> clearAllReceiptIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final existingIdsJson = prefs.getString(_receiptIdsKey);
      if (existingIdsJson != null) {
        final List<dynamic> decoded = jsonDecode(existingIdsJson);
        List<int> existingIds = decoded.cast<int>();
        
        for (int id in existingIds) {
          await prefs.remove('$_receiptDataKey$id');
        }
      }
      
      await prefs.remove(_receiptIdsKey);
      
      print('DEBUG: Cleared all receipt IDs');
    } catch (e) {
      print('DEBUG: Error clearing receipt IDs: $e');
    }
  }

  Future<bool> hasReceiptId(int receiptId) async {
    final ids = await getReceiptIds();
    return ids.contains(receiptId);
  }
}
