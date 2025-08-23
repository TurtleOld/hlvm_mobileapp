import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:hlvm_mobileapp/core/utils/error_handler.dart';
import 'package:hlvm_mobileapp/core/utils/global_error_handler.dart';
import 'package:hlvm_mobileapp/core/constants/app_constants.dart';

void main() {
  group('ErrorHandler Tests', () {
    test('should return session expired message for 401 status code', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          statusCode: 401,
          requestOptions: RequestOptions(path: '/test'),
        ),
      );

      final result = ErrorHandler.handleApiError(dioException);
      expect(result, equals(AppConstants.sessionExpired));
    });

    test('should return session expired message for session expired text', () {
      final error = 'Сессия истекла, войдите заново';
      final result = ErrorHandler.handleApiError(error);
      expect(result, equals(AppConstants.sessionExpired));
    });

    test('should return session expired message for unauthorized text', () {
      final error = 'Unauthorized access';
      final result = ErrorHandler.handleApiError(error);
      expect(result, equals(AppConstants.sessionExpired));
    });
  });

  group('GlobalErrorHandler Tests', () {
    test('should detect session expired error from DioException', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          statusCode: 401,
          requestOptions: RequestOptions(path: '/test'),
        ),
      );

      final result = GlobalErrorHandler.isSessionExpiredError(dioException);
      expect(result, isTrue);
    });

    test('should detect session expired error from text', () {
      final error = Exception('Сессия истекла');
      final result = GlobalErrorHandler.isSessionExpiredError(error);
      expect(result, isTrue);
    });

    test('should not detect session expired error for other errors', () {
      final error = Exception('Network error');
      final result = GlobalErrorHandler.isSessionExpiredError(error);
      expect(result, isFalse);
    });

    test('should return friendly message for session expired error', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          statusCode: 401,
          requestOptions: RequestOptions(path: '/test'),
        ),
      );

      final result = GlobalErrorHandler.handleBlocError(dioException);
      expect(result, equals(AppConstants.sessionExpired));
    });
  });
}
