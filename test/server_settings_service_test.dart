import 'package:flutter_test/flutter_test.dart';
import 'package:hlvm_mobileapp/core/services/server_settings_service.dart';
import 'package:hlvm_mobileapp/core/services/bruteforce_protection_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  group('ServerSettingsService', () {
    late ServerSettingsService serverSettings;
    late BruteforceProtectionService bruteforceProtection;
    late FlutterSecureStorage secureStorage;

    setUp(() {
      bruteforceProtection = BruteforceProtectionService();
      secureStorage = const FlutterSecureStorage();
      serverSettings = ServerSettingsService(
        secureStorage: secureStorage,
        bruteforceProtection: bruteforceProtection,
      );
    });

    tearDown(() async {
      await serverSettings.clearServerSettings();
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

      await serverSettings.setServerTimeout(testTimeout);
      final retrievedTimeout = await serverSettings.getServerTimeout();

      expect(retrievedTimeout, equals(testTimeout));
    });

    test('should set and get retry attempts', () async {
      const testRetries = 5;

      await serverSettings.setServerRetryAttempts(testRetries);
      final retrievedRetries = await serverSettings.getServerRetryAttempts();

      expect(retrievedRetries, equals(testRetries));
    });

    test('should set and get health check setting', () async {
      const testHealthCheck = false;

      await serverSettings.setServerHealthCheck(testHealthCheck);
      final retrievedHealthCheck = await serverSettings.getServerHealthCheck();

      expect(retrievedHealthCheck, equals(testHealthCheck));
    });

    test('should set and get API version', () async {
      const testApiVersion = 'v2';

      await serverSettings.setServerApiVersion(testApiVersion);
      final retrievedApiVersion = await serverSettings.getServerApiVersion();

      expect(retrievedApiVersion, equals(testApiVersion));
    });

    test('should get full server URL', () async {
      await serverSettings.setServerSettings(
        address: 'example.com',
        port: 8000,
        protocol: 'https',
        apiVersion: 'v1',
      );

      final fullUrl = await serverSettings.getFullServerUrl();
      expect(fullUrl, equals('https://example.com:8000/api/v1'));
    });

    test('should get base server URL without API path', () async {
      await serverSettings.setServerSettings(
        address: 'example.com',
        port: 8000,
        protocol: 'https',
      );

      final baseUrl = await serverSettings.getBaseServerUrl();
      expect(baseUrl, equals('https://example.com:8000'));
    });

    test('should validate server settings', () async {
      await serverSettings.setServerSettings(
        address: 'example.com',
        protocol: 'https',
      );

      final isValid = await serverSettings.validateServerSettings();
      expect(isValid, isTrue);
    });

    test('should check if server is configured', () async {
      expect(await serverSettings.isServerConfigured(), isFalse);

      await serverSettings.setServerAddress('example.com');
      expect(await serverSettings.isServerConfigured(), isTrue);
    });

    test('should reset to defaults', () async {
      await serverSettings.setServerSettings(
        address: 'custom.example.com',
        port: 9000,
        protocol: 'http',
      );

      await serverSettings.resetToDefaults();

      final settings = await serverSettings.getAllServerSettings();
      expect(settings['address'], equals('localhost'));
      expect(settings['port'], equals(8000));
      expect(settings['protocol'], equals('http'));
    });

    test('should create and restore backup', () async {
      await serverSettings.setServerSettings(
        address: 'backup.example.com',
        port: 7000,
        protocol: 'https',
      );

      final backup = await serverSettings.createBackup();
      expect(backup['address'], equals('backup.example.com'));
      expect(backup['port'], equals('7000'));
      expect(backup['protocol'], equals('https'));

      await serverSettings.clearServerSettings();
      expect(await serverSettings.isServerConfigured(), isFalse);

      await serverSettings.restoreFromBackup(backup);
      expect(await serverSettings.isServerConfigured(), isTrue);

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
        () => serverSettings.setServerTimeout(0),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => serverSettings.setServerTimeout(400),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should handle invalid retry attempts', () async {
      expect(
        () => serverSettings.setServerRetryAttempts(-1),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => serverSettings.setServerRetryAttempts(15),
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
        () => serverSettings.setServerApiVersion(''),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
