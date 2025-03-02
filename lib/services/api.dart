import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:hlvm_mobileapp/models/finance_account_model.dart';

import 'authentication.dart';

class ApiService {
  final Dio _dio = Dio();
  final AuthService _authService = AuthService();
  final String _baseUrl = 'https://hlvm.pavlovteam.ru/api';

  ApiService() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final accessToken = await _authService.getAccessToken();
        if (accessToken != null) {
          options.headers['Authorization'] = 'Bearer $accessToken';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          try {
            await _authService.refreshToken();
            final newAccessToken = await _authService.getAccessToken();
            error.requestOptions.headers['Authorization'] =
                'Bearer $newAccessToken';
            final response = await _dio.fetch(error.requestOptions);
            return handler.resolve(response);
          } catch (e) {
            return handler.reject(error);
          }
        }
        return handler.next(error);
      },
    ));
  }

  Future<List> listReceipt() async {
    try {
      final accessToken = await _authService.getAccessToken();
      final response = await _dio.get('$_baseUrl/receipts/list/',
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}));
      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception("Failed to load receipts");
      }
    } catch (e) {
      throw Exception("Error: $e");
    }
  }

  Future<Map<String, dynamic>> getSeller() async {
    try {
      final accessToken = await _authService.getAccessToken();
      final receipt = await listReceipt();
      final sellerId = receipt[0]['seller'];
      final response = await _dio.get('$_baseUrl/receipts/seller/$sellerId',
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}));
      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception("Failed to load receipts");
      }
    } catch (e) {
      throw Exception("Error: $e");
    }
  }

  Future<String> createReceipt(Map<String, dynamic> data) async {
    try {
      final accessToken = await _authService.getAccessToken();
      final response = await _dio.post('$_baseUrl/receipts/create-receipt/',
          data: jsonEncode(data),
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}));

      if (response.statusCode == 200) {
        return 'Чек успешно добавлен!';
      } else {
        return 'Чек не был добавлен, повторите попытку!';
      }
    } catch (e) {
      throw Exception("Error: $e");
    }
  }

  Future<List<FinanceAccount>> fetchFinanceAccount() async {
    try {
      final accessToken = await _authService.getAccessToken();
      final response = await _dio.get('$_baseUrl/finaccount/list/',
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}));
      if (response.statusCode == 200) {
        List<dynamic> data = response.data;
        return data.map((json) => FinanceAccount.fromJson(json)).toList();
      } else {
        throw Exception("Failed to load accounts");
      }
    } catch (e) {
      throw Exception("Error: $e");
    }
  }
}
