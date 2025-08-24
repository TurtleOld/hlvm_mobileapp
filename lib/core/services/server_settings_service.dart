import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hlvm_mobileapp/core/services/bruteforce_protection_service.dart';

/// Сервис для безопасного хранения настроек сервера
/// Использует Flutter Secure Storage и дополнительное шифрование
class ServerSettingsService {
  static const String _serverAddressKey = 'server_address';
  static const String _serverPortKey = 'server_port';
  static const String _serverProtocolKey = 'server_protocol';
  static const String _serverTimeoutKey = 'server_timeout';
  static const String _serverRetryAttemptsKey = 'server_retry_attempts';
  static const String _serverHealthCheckKey = 'server_health_check';
  static const String _serverApiVersionKey = 'server_api_version';
  static const String _serverSettingsHashKey = 'server_settings_hash';

  final FlutterSecureStorage _secureStorage;
  final BruteforceProtectionService _bruteforceProtection;

  ServerSettingsService({
    FlutterSecureStorage? secureStorage,
    BruteforceProtectionService? bruteforceProtection,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _bruteforceProtection =
            bruteforceProtection ?? BruteforceProtectionService();

  /// Сохраняет адрес сервера
  Future<void> setServerAddress(String address) async {
    try {
      // Валидация адреса сервера
      if (address.isEmpty) {
        throw ArgumentError('Адрес сервера не может быть пустым');
      }

      // Убираем trailing slash если есть
      final cleanAddress = address.endsWith('/')
          ? address.substring(0, address.length - 1)
          : address;

      final encryptedAddress =
          await _bruteforceProtection.encryptData(cleanAddress);

      await _secureStorage.write(
        key: _serverAddressKey,
        value: encryptedAddress,
      );

      // Обновляем хеш настроек
      await _updateSettingsHash();
    } catch (e) {
      throw Exception('Не удалось сохранить адрес сервера: $e');
    }
  }

  /// Получает адрес сервера
  Future<String?> getServerAddress() async {
    try {
      final encryptedAddress =
          await _secureStorage.read(key: _serverAddressKey);
      if (encryptedAddress == null) return null;

      return await _bruteforceProtection.decryptData(encryptedAddress);
    } catch (e) {
      return null;
    }
  }

  /// Сохраняет порт сервера
  Future<void> setServerPort(int port) async {
    try {
      if (port < 1 || port > 65535) {
        throw ArgumentError('Порт должен быть в диапазоне 1-65535');
      }

      final encryptedPort =
          await _bruteforceProtection.encryptData(port.toString());

      await _secureStorage.write(
        key: _serverPortKey,
        value: encryptedPort,
      );

      await _updateSettingsHash();
    } catch (e) {
      throw Exception('Не удалось сохранить порт сервера: $e');
    }
  }

  /// Получает порт сервера
  Future<int?> getServerPort() async {
    try {
      final encryptedPort = await _secureStorage.read(key: _serverPortKey);
      if (encryptedPort == null) return null;

      final portString = await _bruteforceProtection.decryptData(encryptedPort);
      return int.tryParse(portString);
    } catch (e) {
      return null;
    }
  }

  /// Сохраняет протокол сервера (http/https)
  Future<void> setServerProtocol(String protocol) async {
    try {
      final validProtocols = ['http', 'https'];
      if (!validProtocols.contains(protocol.toLowerCase())) {
        throw ArgumentError(
            'Поддерживаются только протоколы: ${validProtocols.join(', ')}');
      }

      final encryptedProtocol =
          await _bruteforceProtection.encryptData(protocol.toLowerCase());

      await _secureStorage.write(
        key: _serverProtocolKey,
        value: encryptedProtocol,
      );

      await _updateSettingsHash();
    } catch (e) {
      throw Exception('Не удалось сохранить протокол сервера: $e');
    }
  }

  /// Получает протокол сервера
  Future<String?> getServerProtocol() async {
    try {
      final encryptedProtocol =
          await _secureStorage.read(key: _serverProtocolKey);
      if (encryptedProtocol == null) return null;

      return await _bruteforceProtection.decryptData(encryptedProtocol);
    } catch (e) {
      return null;
    }
  }

  /// Сохраняет таймаут соединения в секундах
  Future<void> setServerTimeout(int timeoutSeconds) async {
    try {
      if (timeoutSeconds < 1 || timeoutSeconds > 300) {
        throw ArgumentError('Таймаут должен быть в диапазоне 1-300 секунд');
      }

      final encryptedTimeout =
          await _bruteforceProtection.encryptData(timeoutSeconds.toString());

      await _secureStorage.write(
        key: _serverTimeoutKey,
        value: encryptedTimeout,
      );

      await _updateSettingsHash();
    } catch (e) {
      throw Exception('Не удалось сохранить таймаут сервера: $e');
    }
  }

  /// Получает таймаут соединения
  Future<int?> getServerTimeout() async {
    try {
      final encryptedTimeout =
          await _secureStorage.read(key: _serverTimeoutKey);
      if (encryptedTimeout == null) return null;

      final timeoutString =
          await _bruteforceProtection.decryptData(encryptedTimeout);
      return int.tryParse(timeoutString);
    } catch (e) {
      return null;
    }
  }

  /// Сохраняет количество попыток повторного подключения
  Future<void> setServerRetryAttempts(int attempts) async {
    try {
      if (attempts < 0 || attempts > 10) {
        throw ArgumentError('Количество попыток должно быть в диапазоне 0-10');
      }

      final encryptedAttempts =
          await _bruteforceProtection.encryptData(attempts.toString());

      await _secureStorage.write(
        key: _serverRetryAttemptsKey,
        value: encryptedAttempts,
      );

      await _updateSettingsHash();
    } catch (e) {
      throw Exception('Не удалось сохранить количество попыток: $e');
    }
  }

  /// Получает количество попыток повторного подключения
  Future<int?> getServerRetryAttempts() async {
    try {
      final encryptedAttempts =
          await _secureStorage.read(key: _serverRetryAttemptsKey);
      if (encryptedAttempts == null) return null;

      final attemptsString =
          await _bruteforceProtection.decryptData(encryptedAttempts);
      return int.tryParse(attemptsString);
    } catch (e) {
      return null;
    }
  }

  /// Сохраняет настройки проверки здоровья сервера
  Future<void> setServerHealthCheck(bool enabled) async {
    try {
      final encryptedHealthCheck =
          await _bruteforceProtection.encryptData(enabled.toString());

      await _secureStorage.write(
        key: _serverHealthCheckKey,
        value: encryptedHealthCheck,
      );

      await _updateSettingsHash();
    } catch (e) {
      throw Exception('Не удалось сохранить настройки проверки здоровья: $e');
    }
  }

  /// Получает настройки проверки здоровья сервера
  Future<bool?> getServerHealthCheck() async {
    try {
      final encryptedHealthCheck =
          await _secureStorage.read(key: _serverHealthCheckKey);
      if (encryptedHealthCheck == null) return null;

      final healthCheckString =
          await _bruteforceProtection.decryptData(encryptedHealthCheck);
      return bool.tryParse(healthCheckString);
    } catch (e) {
      return null;
    }
  }

  /// Сохраняет версию API сервера
  Future<void> setServerApiVersion(String version) async {
    try {
      if (version.isEmpty) {
        throw ArgumentError('Версия API не может быть пустой');
      }

      final encryptedVersion = await _bruteforceProtection.encryptData(version);

      await _secureStorage.write(
        key: _serverApiVersionKey,
        value: encryptedVersion,
      );

      await _updateSettingsHash();
    } catch (e) {
      throw Exception('Не удалось сохранить версию API: $e');
    }
  }

  /// Получает версию API сервера
  Future<String?> getServerApiVersion() async {
    try {
      final encryptedVersion =
          await _secureStorage.read(key: _serverApiVersionKey);
      if (encryptedVersion == null) return null;

      return await _bruteforceProtection.decryptData(encryptedVersion);
    } catch (e) {
      return null;
    }
  }

  /// Получает полный URL сервера
  Future<String?> getFullServerUrl() async {
    try {
      final protocol = await getServerProtocol() ?? 'https';
      final address = await getServerAddress();
      final port = await getServerPort();
      final apiVersion = await getServerApiVersion() ?? 'v1';

      if (address == null) return null;

      String url = '$protocol://$address';

      if (port != null && port != 80 && port != 443) {
        url += ':$port';
      }

      url += '/api/$apiVersion';

      return url;
    } catch (e) {
      return null;
    }
  }

  /// Получает базовый URL сервера (без /api/version)
  Future<String?> getBaseServerUrl() async {
    try {
      final protocol = await getServerProtocol() ?? 'https';
      final address = await getServerAddress();
      final port = await getServerPort();

      if (address == null) return null;

      String url = '$protocol://$address';

      if (port != null && port != 80 && port != 443) {
        url += ':$port';
      }

      return url;
    } catch (e) {
      return null;
    }
  }

  /// Сохраняет все настройки сервера сразу
  Future<void> setServerSettings({
    required String address,
    int? port,
    String? protocol,
    int? timeout,
    int? retryAttempts,
    bool? healthCheck,
    String? apiVersion,
  }) async {
    try {
      await setServerAddress(address);

      if (port != null) await setServerPort(port);
      if (protocol != null) await setServerProtocol(protocol);
      if (timeout != null) await setServerTimeout(timeout);
      if (retryAttempts != null) await setServerRetryAttempts(retryAttempts);
      if (healthCheck != null) await setServerHealthCheck(healthCheck);
      if (apiVersion != null) await setServerApiVersion(apiVersion);

      await _updateSettingsHash();
    } catch (e) {
      throw Exception('Не удалось сохранить настройки сервера: $e');
    }
  }

  /// Получает все настройки сервера
  Future<Map<String, dynamic>> getAllServerSettings() async {
    try {
      return {
        'address': await getServerAddress(),
        'port': await getServerPort(),
        'protocol': await getServerProtocol(),
        'timeout': await getServerTimeout(),
        'retryAttempts': await getServerRetryAttempts(),
        'healthCheck': await getServerHealthCheck(),
        'apiVersion': await getServerApiVersion(),
        'fullUrl': await getFullServerUrl(),
        'baseUrl': await getBaseServerUrl(),
      };
    } catch (e) {
      return {
        'error': e.toString(),
      };
    }
  }

  /// Проверяет, настроен ли сервер
  Future<bool> isServerConfigured() async {
    try {
      final address = await getServerAddress();
      return address != null && address.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Проверяет целостность настроек сервера
  Future<bool> validateServerSettings() async {
    try {
      final address = await getServerAddress();
      if (address == null || address.isEmpty) return false;

      final protocol = await getServerProtocol();
      if (protocol == null) return false;

      final port = await getServerPort();
      if (port != null && (port < 1 || port > 65535)) return false;

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Сбрасывает настройки сервера к значениям по умолчанию
  Future<void> resetToDefaults() async {
    try {
      await setServerSettings(
        address: 'localhost',
        port: 8000,
        protocol: 'http',
        timeout: 30,
        retryAttempts: 3,
        healthCheck: true,
        apiVersion: 'v1',
      );
    } catch (e) {
      throw Exception('Не удалось сбросить настройки: $e');
    }
  }

  /// Очищает все настройки сервера
  Future<void> clearServerSettings() async {
    try {
      await _secureStorage.delete(key: _serverAddressKey);
      await _secureStorage.delete(key: _serverPortKey);
      await _secureStorage.delete(key: _serverProtocolKey);
      await _secureStorage.delete(key: _serverTimeoutKey);
      await _secureStorage.delete(key: _serverRetryAttemptsKey);
      await _secureStorage.delete(key: _serverHealthCheckKey);
      await _secureStorage.delete(key: _serverApiVersionKey);
      await _secureStorage.delete(key: _serverSettingsHashKey);
    } catch (e) {
      // Игнорируем ошибки очистки
    }
  }

  /// Создает резервную копию настроек сервера
  Future<Map<String, String>> createBackup() async {
    try {
      final settings = await getAllServerSettings();
      final backup = <String, String>{};

      for (final entry in settings.entries) {
        if (entry.value != null && entry.key != 'error') {
          backup[entry.key] = entry.value.toString();
        }
      }

      return backup;
    } catch (e) {
      throw Exception('Не удалось создать резервную копию: $e');
    }
  }

  /// Восстанавливает настройки сервера из резервной копии
  Future<void> restoreFromBackup(Map<String, String> backup) async {
    try {
      // Очищаем текущие настройки
      await clearServerSettings();

      // Восстанавливаем настройки
      if (backup.containsKey('address')) {
        await setServerAddress(backup['address']!);
      }

      if (backup.containsKey('port')) {
        final port = int.tryParse(backup['port']!);
        if (port != null) await setServerPort(port);
      }

      if (backup.containsKey('protocol')) {
        await setServerProtocol(backup['protocol']!);
      }

      if (backup.containsKey('timeout')) {
        final timeout = int.tryParse(backup['timeout']!);
        if (timeout != null) await setServerTimeout(timeout);
      }

      if (backup.containsKey('retryAttempts')) {
        final retryAttempts = int.tryParse(backup['retryAttempts']!);
        if (retryAttempts != null) await setServerRetryAttempts(retryAttempts);
      }

      if (backup.containsKey('healthCheck')) {
        final healthCheck = bool.tryParse(backup['healthCheck']!);
        if (healthCheck != null) await setServerHealthCheck(healthCheck);
      }

      if (backup.containsKey('apiVersion')) {
        await setServerApiVersion(backup['apiVersion']!);
      }

      await _updateSettingsHash();
    } catch (e) {
      throw Exception('Не удалось восстановить из резервной копии: $e');
    }
  }

  /// Обновляет хеш настроек для проверки целостности
  Future<void> _updateSettingsHash() async {
    try {
      final settings = await getAllServerSettings();
      final settingsJson = jsonEncode(settings);

      // Простой хеш для проверки изменений
      final hash = settingsJson.hashCode.toString();

      await _secureStorage.write(
        key: _serverSettingsHashKey,
        value: hash,
      );
    } catch (e) {
      // Игнорируем ошибки обновления хеша
    }
  }

  /// Проверяет, изменились ли настройки с момента последнего сохранения
  Future<bool> hasSettingsChanged() async {
    try {
      final currentSettings = await getAllServerSettings();
      final currentHash = currentSettings.hashCode.toString();

      final storedHash = await _secureStorage.read(key: _serverSettingsHashKey);

      return storedHash != currentHash;
    } catch (e) {
      return true; // При ошибке считаем, что настройки изменились
    }
  }
}
