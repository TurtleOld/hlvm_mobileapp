import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../theme/app_theme.dart';

class ErrorHandler {
  static String handleApiError(dynamic error) {
    if (error is DioException) {
      switch (error.response?.statusCode) {
        case 401:
          return AppConstants.sessionExpired;
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

    // Проверяем на ошибки сессии в тексте ошибки
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('сессия истекла') ||
        errorString.contains('session expired') ||
        errorString.contains('token expired') ||
        errorString.contains('unauthorized')) {
      return AppConstants.sessionExpired;
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
          backgroundColor: AppTheme.errorRed,
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
          backgroundColor: AppTheme.primaryGreen,
          duration: AppConstants.snackBarDuration,
        ),
      );
    }
  }

  static void showSessionExpiredDialog(BuildContext context) {
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppConstants.sessionExpiredTitle),
          content: Text(AppConstants.sessionExpired),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login',
                  (route) => false,
                );
              },
              child: Text(AppConstants.sessionExpiredAction),
            ),
          ],
        );
      },
    );
  }

  static void showSessionExpiredSnackBar(BuildContext context) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppConstants.sessionExpired),
        backgroundColor: AppTheme.errorRed,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: AppConstants.sessionExpiredAction,
          onPressed: () {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/login',
              (route) => false,
            );
          },
        ),
      ),
    );
  }
}
