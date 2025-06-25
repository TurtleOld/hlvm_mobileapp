import 'dart:async';
import 'package:dio/dio.dart';
import 'package:hlvm_mobileapp/models/finance_account_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'authentication.dart';

class ApiService {
  final Dio _dio = Dio();
  final AuthService _authService = AuthService();

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

  Future<String> get _baseUrl async {
    final prefs = await SharedPreferences.getInstance();
    final server = prefs.getString('server_address');
    if (server != null && server.isNotEmpty) {
      return server.endsWith('/api') ? server : '$server/api';
    }
    throw Exception('Необходимо указать адрес сервера в настройках');
  }

  Future<List> listReceipt() async {
    try {
      final accessToken = await _authService.getAccessToken();
      final baseUrl = await _baseUrl;
      final response = await _dio.get('$baseUrl/receipts/list/',
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

  Future<Map<String, dynamic>> getSeller(int sellerId) async {
    try {
      final accessToken = await _authService.getAccessToken();
      final baseUrl = await _baseUrl;
      final response = await _dio.get('$baseUrl/receipts/seller/$sellerId',
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

  Future<String> createReceipt(Map<String, dynamic> jsonData) async {
    try {
      final accessToken = await _authService.getAccessToken();
      final baseUrl = await _baseUrl;
      final response = await _dio.post('$baseUrl/receipts/create-receipt/',
          data: jsonData,
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}));
      if (response.statusCode == 200) {
        return 'Чек успешно добавлен!';
      } else {
        if (response.data != null) {
          if (response.data is Map && response.data['detail'] != null) {
            return response.data['detail'].toString();
          }
          return response.data.toString();
        }
        return 'Чек не был добавлен, повторите попытку!';
      }
    } catch (e) {
      if (e is DioException && e.response?.data != null) {
        final data = e.response?.data;
        if (data is Map && data['detail'] != null) {
          return data['detail'].toString();
        }
        return data.toString();
      }
      return 'Ошибка: $e';
    }
  }

  Future<List<FinanceAccount>> fetchFinanceAccount() async {
    try {
      final accessToken = await _authService.getAccessToken();
      final baseUrl = await _baseUrl;
      final response = await _dio.get('$baseUrl/finaccount/list/',
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
