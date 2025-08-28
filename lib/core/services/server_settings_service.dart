import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/logger.dart';

class ServerSettingsService {
  static const String _serverAddressKey = 'server_address';
  static const String _serverPortKey = 'server_port';
  static const String _serverProtocolKey = 'server_protocol';
  static const String _timeoutKey = 'timeout_seconds';
  static const String _maxRetriesKey = 'max_retries';
  static const String _healthCheckKey = 'health_check_enabled';
  static const String _serverVersionKey = 'server_version';
  static const String _serverSettingsHashKey = 'server_settings_hash';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  ServerSettingsService();

  Future<void> setServerAddress(String address) async {
    try {
      String cleanAddress = address.trim();
      if (cleanAddress.endsWith('/')) {
        cleanAddress = cleanAddress.substring(0, cleanAddress.length - 1);
      }

      if (cleanAddress.isEmpty ||
          cleanAddress.length < 3 ||
          cleanAddress.length > 100 ||
          cleanAddress.contains(' ') ||
          cleanAddress.contains('\n') ||
          cleanAddress.contains('\r') ||
          cleanAddress.contains('0DhwISORbzhVjurLYbxio6Xd') ||
          !_isValidServerAddress(cleanAddress)) {
        throw Exception('Некорректный формат адреса сервера');
      }

      await _secureStorage.write(
        key: _serverAddressKey,
        value: cleanAddress,
      );

      await _updateSettingsHash();
      AppLogger.info('Server address saved: $cleanAddress');
    } catch (e) {
      AppLogger.error('Error saving server address: $e');
      rethrow;
    }
  }

  Future<String?> getServerAddress() async {
    try {
      final address = await _secureStorage.read(key: _serverAddressKey);

      if (address != null && address.isNotEmpty) {
        if (address.length > 50 ||
            address.contains(' ') ||
            address.contains('\n') ||
            address.contains('\r') ||
            address.contains('0DhwISORbzhVjurLYbxio6Xd')) {
          AppLogger.warning('Invalid server address format detected: $address');
          return null;
        }

        if (!_isValidServerAddress(address)) {
          AppLogger.warning(
              'Server address does not match expected format: $address');
          return null;
        }

        AppLogger.info('Server address retrieved: $address');
        return address;
      }

      AppLogger.info('No server address configured');
      return null;
    } catch (e) {
      AppLogger.error('Error retrieving server address: $e');
      return null;
    }
  }

  bool _isValidServerAddress(String address) {
    if (address.contains('0DhwISORbzhVjurLYbxio6Xd') ||
        address.length < 3 ||
        address.length > 100 ||
        address.contains(' ') ||
        address.contains('\n') ||
        address.contains('\r')) {
      return false;
    }

    final validPatterns = [
      RegExp(r'^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'),
      RegExp(r'^(\d{1,3}\.){3}\d{1,3}$'),
      RegExp(r'^localhost$'),
      RegExp(r'^[a-zA-Z0-9.-]+$'),
    ];

    return validPatterns.any((pattern) => pattern.hasMatch(address));
  }

  Future<void> setServerPort(int port) async {
    try {
      if (port < 1 || port > 65535) {
        throw Exception(
            'Некорректный порт. Порт должен быть в диапазоне 1-65535');
      }

      await _secureStorage.write(
        key: _serverPortKey,
        value: port.toString(),
      );

      await _updateSettingsHash();
      AppLogger.info('Server port saved: $port');
    } catch (e) {
      AppLogger.error('Error saving server port: $e');
      rethrow;
    }
  }

  Future<int?> getServerPort() async {
    try {
      final portString = await _secureStorage.read(key: _serverPortKey);
      if (portString == null) return null;

      final port = int.tryParse(portString);
      AppLogger.info('Server port retrieved: $port');
      return port;
    } catch (e) {
      AppLogger.error('Error retrieving server port: $e');
      return null;
    }
  }

  Future<void> setServerProtocol(String protocol) async {
    try {
      final cleanProtocol = protocol.toLowerCase().trim();

      if (cleanProtocol.isEmpty ||
          (cleanProtocol != 'http' && cleanProtocol != 'https')) {
        throw Exception(
            'Некорректный протокол. Поддерживаются только HTTP и HTTPS');
      }

      await _secureStorage.write(
        key: _serverProtocolKey,
        value: cleanProtocol,
      );

      await _updateSettingsHash();
      AppLogger.info('Server protocol saved: $cleanProtocol');
    } catch (e) {
      AppLogger.error('Error saving server protocol: $e');
      rethrow;
    }
  }

  Future<String?> getServerProtocol() async {
    try {
      final protocol = await _secureStorage.read(key: _serverProtocolKey);
      AppLogger.info('Server protocol retrieved: $protocol');

      if (protocol == null) {
        await setServerProtocol('https');
        AppLogger.info('Default protocol (https) set');
        return 'https';
      }

      return protocol;
    } catch (e) {
      AppLogger.error('Error retrieving server protocol: $e');
      return 'https';
    }
  }

  Future<void> setTimeout(int timeoutSeconds) async {
    try {
      if (timeoutSeconds < 1 ||
          timeoutSeconds > 300) {
        throw Exception(
            'Некорректный таймаут. Таймаут должен быть в диапазоне 1-300 секунд');
      }

      await _secureStorage.write(
        key: _timeoutKey,
        value: timeoutSeconds.toString(),
      );

      await _updateSettingsHash();
      AppLogger.info('Timeout saved: ${timeoutSeconds}s');
    } catch (e) {
      AppLogger.error('Error saving timeout: $e');
      rethrow;
    }
  }

  Future<int?> getTimeout() async {
    try {
      final timeoutString = await _secureStorage.read(key: _timeoutKey);
      if (timeoutString == null) return null;

      final timeout = int.tryParse(timeoutString);
      AppLogger.info('Timeout retrieved: ${timeout}s');
      return timeout;
    } catch (e) {
      AppLogger.error('Error retrieving timeout: $e');
      return null;
    }
  }

  Future<void> setMaxRetries(int attempts) async {
    try {
      if (attempts < 1 || attempts > 10) {
        throw Exception(
            'Некорректное количество попыток. Должно быть в диапазоне 1-10');
      }

      await _secureStorage.write(
        key: _maxRetriesKey,
        value: attempts.toString(),
      );

      await _updateSettingsHash();
      AppLogger.info('Max retries saved: $attempts');
    } catch (e) {
      AppLogger.error('Error saving max retries: $e');
      rethrow;
    }
  }

  Future<int?> getMaxRetries() async {
    try {
      final attemptsString = await _secureStorage.read(key: _maxRetriesKey);
      if (attemptsString == null) return null;

      final attempts = int.tryParse(attemptsString);
      AppLogger.info('Max retries retrieved: $attempts');
      return attempts;
    } catch (e) {
      AppLogger.error('Error retrieving max retries: $e');
      return null;
    }
  }

  Future<void> setHealthCheckEnabled(bool enabled) async {
    try {
      await _secureStorage.write(
        key: _healthCheckKey,
        value: enabled.toString(),
      );

      await _updateSettingsHash();
      AppLogger.info('Health check enabled: $enabled');
    } catch (e) {
      AppLogger.error('Error saving health check setting: $e');
      rethrow;
    }
  }

  Future<bool?> getHealthCheckEnabled() async {
    try {
      final healthCheckString = await _secureStorage.read(key: _healthCheckKey);
      if (healthCheckString == null) return null;

      final healthCheck = healthCheckString.toLowerCase() == 'true';
      AppLogger.info('Health check enabled: $healthCheck');
      return healthCheck;
    } catch (e) {
      AppLogger.error('Error retrieving health check setting: $e');
      return null;
    }
  }

  Future<void> setServerVersion(String version) async {
    try {
      final cleanVersion = version.trim();

      if (cleanVersion.isEmpty ||
          cleanVersion.length > 50 ||
          cleanVersion.contains(' ') ||
          cleanVersion.contains('\n') ||
          cleanVersion.contains('\r')) {
        throw Exception('Некорректная версия сервера');
      }

      await _secureStorage.write(
        key: _serverVersionKey,
        value: cleanVersion,
      );

      await _updateSettingsHash();
      AppLogger.info('Server version saved: $cleanVersion');
    } catch (e) {
      AppLogger.error('Error saving server version: $e');
      rethrow;
    }
  }

  Future<String?> getServerVersion() async {
    try {
      final version = await _secureStorage.read(key: _serverVersionKey);
      AppLogger.info('Server version retrieved: $version');
      return version;
    } catch (e) {
      AppLogger.error('Error retrieving server version: $e');
      return null;
    }
  }

  Future<void> clearAllSettings() async {
    try {
      await _secureStorage.delete(key: _serverAddressKey);
      await _secureStorage.delete(key: _serverPortKey);
      await _secureStorage.delete(key: _serverProtocolKey);
      await _secureStorage.delete(key: _timeoutKey);
      await _secureStorage.delete(key: _maxRetriesKey);
      await _secureStorage.delete(key: _healthCheckKey);
      await _secureStorage.delete(key: _serverVersionKey);
      await _secureStorage.delete(key: _serverSettingsHashKey);

      AppLogger.info('All server settings cleared');
    } catch (e) {
      AppLogger.error('Error clearing server settings: $e');
      rethrow;
    }
  }

  Future<void> clearInvalidSettings() async {
    try {
      final address = await getServerAddress();
      if (address != null && !_isValidServerAddress(address)) {
        AppLogger.warning('Clearing invalid server address: $address');
        await _secureStorage.delete(key: _serverAddressKey);
      }

      final port = await getServerPort();
      if (port != null && (port < 1 || port > 65535)) {
        AppLogger.warning('Clearing invalid server port: $port');
        await _secureStorage.delete(key: _serverPortKey);
      }

      final protocol = await getServerProtocol();
      if (protocol != null && protocol != 'http' && protocol != 'https') {
        AppLogger.warning('Clearing invalid server protocol: $protocol');
        await _secureStorage.delete(key: _serverProtocolKey);
      }

      final timeout = await getTimeout();
      if (timeout != null && (timeout < 1 || timeout > 300)) {
        AppLogger.warning('Clearing invalid timeout: $timeout');
        await _secureStorage.delete(key: _timeoutKey);
      }

      final maxRetries = await getMaxRetries();
      if (maxRetries != null && (maxRetries < 1 || maxRetries > 10)) {
        AppLogger.warning('Clearing invalid max retries: $maxRetries');
        await _secureStorage.delete(key: _maxRetriesKey);
      }

      AppLogger.info('Invalid server settings cleared');
    } catch (e) {
      AppLogger.error('Error clearing invalid server settings: $e');
    }
  }

  Future<bool> validateAllSettings() async {
    try {
      final address = await getServerAddress();
      if (address != null && !_isValidServerAddress(address)) {
        return false;
      }

      final port = await getServerPort();
      if (port != null && (port < 1 || port > 65535)) {
        return false;
      }

      final protocol = await getServerProtocol();
      if (protocol != null && protocol != 'http' && protocol != 'https') {
        return false;
      }

      final timeout = await getTimeout();
      if (timeout != null && (timeout < 1 || timeout > 300)) {
        return false;
      }

      final maxRetries = await getMaxRetries();
      if (maxRetries != null && (maxRetries < 1 || maxRetries > 10)) {
        return false;
      }

      return true;
    } catch (e) {
      AppLogger.error('Error validating server settings: $e');
      return false;
    }
  }

  Future<String> getConfigurationStatusMessage() async {
    try {
      final address = await getServerAddress();
      if (address == null) {
        return 'Адрес сервера не настроен';
      }

      if (!_isValidServerAddress(address)) {
        return 'Некорректный адрес сервера: $address';
      }

      final protocol = await getServerProtocol() ?? 'https';
      final port = await getServerPort();

      String url = '$protocol://$address';
      if (port != null && port != 80 && port != 443) {
        url += ':$port';
      }

      return 'Сервер настроен: $url';
    } catch (e) {
      AppLogger.error('Error getting configuration status: $e');
      return 'Ошибка проверки настроек сервера';
    }
  }

  Future<String?> getFullServerUrl() async {
    try {
      final protocol = await getServerProtocol() ?? 'https';
      final address = await getServerAddress();
      final port = await getServerPort();

      if (address == null) return null;

      String url = '$protocol://$address';
      if (port != null && port != 80 && port != 443) {
        url += ':$port';
      }

      if (url.length > 200 || url.contains(' ') || url.contains('\n')) {
        AppLogger.warning('Invalid server URL format: $url');
        return null;
      }

      AppLogger.info('Full server URL: $url');
      return url;
    } catch (e) {
      AppLogger.error('Error building full server URL: $e');
      return null;
    }
  }

  Future<bool> hasSettingsChanged() async {
    try {
      final currentSettings = await _getCurrentSettingsAsJson();
      final storedHash = await _secureStorage.read(key: _serverSettingsHashKey);

      return storedHash != currentSettings.hashCode.toString();
    } catch (e) {
      AppLogger.error('Error checking settings changes: $e');
      return false;
    }
  }

  Future<void> _updateSettingsHash() async {
    try {
      final settingsJson = await _getCurrentSettingsAsJson();
      final hash = settingsJson.hashCode.toString();

      await _secureStorage.write(
        key: _serverSettingsHashKey,
        value: hash,
      );
    } catch (e) {
      AppLogger.error('Error updating settings hash: $e');
    }
  }

  Future<String> _getCurrentSettingsAsJson() async {
    final address = await getServerAddress();

    if (address != null && !_isValidServerAddress(address)) {
      AppLogger.warning('Invalid address detected in settings: $address');
    }

    final settings = {
      'address': address,
      'port': await getServerPort(),
      'protocol': await getServerProtocol(),
      'timeout': await getTimeout(),
      'maxRetries': await getMaxRetries(),
      'healthCheck': await getHealthCheckEnabled(),
      'version': await getServerVersion(),
    };

    return json.encode(settings);
  }
}
