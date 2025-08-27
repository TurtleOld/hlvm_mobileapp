import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../theme/app_theme.dart';

class ErrorHandler {
  static String handleApiError(dynamic error) {
    // Проверяем на ошибки о не настроенном сервере
    if (error.toString().contains('Необходимо указать адрес сервера') ||
        error.toString().contains(AppConstants.serverAddressRequired)) {
      return AppConstants.serverAddressRequired;
    }

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
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.errorRed,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                AppConstants.sessionExpiredTitle,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(AppConstants.sessionExpired),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.errorRed.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppTheme.errorRed,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Для продолжения работы необходимо войти в систему',
                        style: TextStyle(
                          color: AppTheme.errorRed,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login',
                  (route) => false,
                );
              },
              style: TextButton.styleFrom(
                backgroundColor: AppTheme.errorRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                AppConstants.sessionExpiredAction,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
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
        content: const Text(AppConstants.sessionExpired),
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
