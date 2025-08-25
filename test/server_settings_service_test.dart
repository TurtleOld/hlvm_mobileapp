import 'package:flutter_test/flutter_test.dart';
import 'package:hlvm_mobileapp/core/services/server_settings_service.dart';

void main() {
  group('ServerSettingsService', () {
    late ServerSettingsService serverSettings;

    setUp(() {
      serverSettings = ServerSettingsService();
    });

    tearDown(() async {
      await serverSettings.clearAllSettings();
    });

    test('should set and get server address', () async {
      const testAddress = 'test.example.com';

      await serverSettings.setServerAddress(testAddress);
      final retrievedAddress = await serverSettings.getServerAddress();

      expect(retrievedAddress, equals(testAddress));
    });

    test('should set and get server port', () async {
      const testPort = 8080;

      await serverSettings.setServerPort(testPort);
      final retrievedPort = await serverSettings.getServerPort();

      expect(retrievedPort, equals(testPort));
    });

    test('should set and get server protocol', () async {
      const testProtocol = 'https';

      await serverSettings.setServerProtocol(testProtocol);
      final retrievedProtocol = await serverSettings.getServerProtocol();

      expect(retrievedProtocol, equals(testProtocol));
    });

    test('should set and get server timeout', () async {
      const testTimeout = 60;

      await serverSettings.setTimeout(testTimeout);
      final retrievedTimeout = await serverSettings.getTimeout();

      expect(retrievedTimeout, equals(testTimeout));
    });

    test('should set and get retry attempts', () async {
      const testRetries = 5;

      await serverSettings.setMaxRetries(testRetries);
      final retrievedRetries = await serverSettings.getMaxRetries();

      expect(retrievedRetries, equals(testRetries));
    });

    test('should set and get health check setting', () async {
      const testHealthCheck = false;

      await serverSettings.setHealthCheckEnabled(testHealthCheck);
      final retrievedHealthCheck = await serverSettings.getHealthCheckEnabled();

      expect(retrievedHealthCheck, equals(testHealthCheck));
    });

    test('should set and get API version', () async {
      const testApiVersion = 'v2';

      await serverSettings.setServerVersion(testApiVersion);
      final retrievedApiVersion = await serverSettings.getServerVersion();

      expect(retrievedApiVersion, equals(testApiVersion));
    });

    test('should get full server URL', () async {
      await serverSettings.setServerAddress('example.com');
      await serverSettings.setServerPort(8000);
      await serverSettings.setServerProtocol('https');
      await serverSettings.setServerVersion('v1');

      final fullUrl = await serverSettings.getFullServerUrl();
      expect(fullUrl, equals('https://example.com:8000'));
    });

    test('should get base server URL without API path', () async {
      await serverSettings.setServerAddress('example.com');
      await serverSettings.setServerPort(8000);
      await serverSettings.setServerProtocol('https');

      final baseUrl = await serverSettings.getFullServerUrl();
      expect(baseUrl, equals('https://example.com:8000'));
    });

    test('should validate server settings', () async {
      await serverSettings.setServerAddress('example.com');
      await serverSettings.setServerProtocol('https');

      final address = await serverSettings.getServerAddress();
      final protocol = await serverSettings.getServerProtocol();
      final isValid = address != null && address.isNotEmpty && protocol != null;
      expect(isValid, isTrue);
    });

    test('should check if server is configured', () async {
      final address = await serverSettings.getServerAddress();
      expect(address == null || address.isEmpty, isTrue);

      await serverSettings.setServerAddress('example.com');
      final newAddress = await serverSettings.getServerAddress();
      expect(newAddress != null && newAddress.isNotEmpty, isTrue);
    });

    test('should reset to defaults', () async {
      await serverSettings.setServerAddress('custom.example.com');
      await serverSettings.setServerPort(9000);
      await serverSettings.setServerProtocol('http');

      await serverSettings.clearAllSettings();

      final address = await serverSettings.getServerAddress();
      final port = await serverSettings.getServerPort();
      final protocol = await serverSettings.getServerProtocol();
      expect(address, isNull);
      expect(port, isNull);
      expect(protocol, isNull);
    });

    test('should create and restore backup', () async {
      await serverSettings.setServerAddress('backup.example.com');
      await serverSettings.setServerPort(7000);
      await serverSettings.setServerProtocol('https');

      final backupAddress = await serverSettings.getServerAddress();
      final backupPort = await serverSettings.getServerPort();
      final backupProtocol = await serverSettings.getServerProtocol();
      expect(backupAddress, equals('backup.example.com'));
      expect(backupPort, equals(7000));
      expect(backupProtocol, equals('https'));

      await serverSettings.clearAllSettings();
      final clearedAddress = await serverSettings.getServerAddress();
      expect(clearedAddress == null || clearedAddress.isEmpty, isTrue);

      await serverSettings.setServerAddress('backup.example.com');
      await serverSettings.setServerPort(7000);
      await serverSettings.setServerProtocol('https');

      final restoredAddress = await serverSettings.getServerAddress();
      expect(restoredAddress, equals('backup.example.com'));
    });

    test('should handle invalid port values', () async {
      expect(
        () => serverSettings.setServerPort(0),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => serverSettings.setServerPort(70000),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should handle invalid timeout values', () async {
      expect(
        () => serverSettings.setTimeout(0),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => serverSettings.setTimeout(400),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should handle invalid retry attempts', () async {
      expect(
        () => serverSettings.setMaxRetries(-1),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => serverSettings.setMaxRetries(15),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should handle invalid protocols', () async {
      expect(
        () => serverSettings.setServerProtocol('ftp'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should clean address with trailing slash', () async {
      await serverSettings.setServerAddress('example.com/');
      final address = await serverSettings.getServerAddress();
      expect(address, equals('example.com'));
    });

    test('should handle empty address', () async {
      expect(
        () => serverSettings.setServerAddress(''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should handle empty API version', () async {
      expect(
        () => serverSettings.setServerVersion(''),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
