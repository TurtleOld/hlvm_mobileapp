import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:hlvm_mobileapp/core/utils/request_deduplicator.dart';

void main() {
  group('RequestDeduplicator Tests', () {
    setUp(() {
      // Очищаем pending запросы перед каждым тестом
      RequestDeduplicator.clearPendingRequests();
    });

    test('should generate different keys for different requests', () {
      final options1 = RequestOptions(
        method: 'GET',
        path: '/test',
        baseUrl: 'https://api.example.com',
        queryParameters: {'param1': 'value1'},
      );

      final options2 = RequestOptions(
        method: 'GET',
        path: '/test',
        baseUrl: 'https://api.example.com',
        queryParameters: {'param2': 'value2'},
      );

      final key1 = RequestDeduplicator.generateRequestKey(options1);
      final key2 = RequestDeduplicator.generateRequestKey(options2);

      expect(key1, isNot(equals(key2)));
    });

    test('should generate same keys for identical requests', () {
      final options1 = RequestOptions(
        method: 'GET',
        path: '/test',
        baseUrl: 'https://api.example.com',
        queryParameters: {'param1': 'value1'},
      );

      final options2 = RequestOptions(
        method: 'GET',
        path: '/test',
        baseUrl: 'https://api.example.com',
        queryParameters: {'param1': 'value1'},
      );

      final key1 = RequestDeduplicator.generateRequestKey(options1);
      final key2 = RequestDeduplicator.generateRequestKey(options2);

      expect(key1, equals(key2));
    });

    test('should clear pending requests', () {
      // Проверяем, что pending запросы очищены
      expect(RequestDeduplicator.hasPendingRequests, isFalse);
      expect(RequestDeduplicator.pendingRequestsCount, equals(0));
    });

    test('should handle different HTTP methods', () {
      final getOptions = RequestOptions(
        method: 'GET',
        path: '/test',
        baseUrl: 'https://api.example.com',
      );

      final postOptions = RequestOptions(
        method: 'POST',
        path: '/test',
        baseUrl: 'https://api.example.com',
      );

      final getKey = RequestDeduplicator.generateRequestKey(getOptions);
      final postKey = RequestDeduplicator.generateRequestKey(postOptions);

      expect(getKey, isNot(equals(postKey)));
    });
  });
}
