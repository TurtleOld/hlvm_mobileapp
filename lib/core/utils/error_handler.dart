import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../theme/app_theme.dart';

class ErrorHandler {
  static String handleApiError(dynamic error) {
    if (error is DioException) {
      switch (error.response?.statusCode) {
        case 401:
          return AppConstants.unauthorized;
        case 400:
          final data = error.response?.data;
          if (data is Map && data['detail'] != null) {
            return data['detail'].toString();
          }
          return data?.toString() ?? AppConstants.unknownError;
        case 404:
          return 'Ресурс не найден';
        case 500:
          return 'Ошибка сервера';
        default:
          return error.message ?? AppConstants.networkError;
      }
    }

    if (error.toString().contains('Необходимо указать адрес сервера')) {
      return AppConstants.serverAddressRequired;
    }

    return error.toString();
  }

  static void showErrorSnackBar(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.errorColor,
          duration: AppConstants.snackBarDuration,
        ),
      );
    }
  }

  static void showSuccessSnackBar(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.primaryColor,
          duration: AppConstants.snackBarDuration,
        ),
      );
    }
  }
}
