import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Сервис защиты от брутфорс-атак
/// Реализует прогрессивные задержки, блокировку и биометрическую аутентификацию
class BruteforceProtectionService {
  static const String _attemptsKey = 'login_attempts';
  static const String _blockedUntilKey = 'blocked_until';
  static const String _lastAttemptKey = 'last_attempt';
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _encryptionKey = 'encryption_key';

  final FlutterSecureStorage _secureStorage;
  final LocalAuthentication _localAuth;

  // Конфигурация защиты
  static const int _maxAttempts = 5;
  static const int _initialDelaySeconds = 30;
  static const int _maxDelaySeconds = 3600; // 1 час
  static const int _blockDurationSeconds = 7200; // 2 часа

  BruteforceProtectionService({
    FlutterSecureStorage? secureStorage,
    LocalAuthentication? localAuth,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _localAuth = localAuth ?? LocalAuthentication();

  /// Проверяет, можно ли выполнить попытку входа
  Future<BruteforceCheckResult> canAttemptLogin(String username) async {
    try {
      final attempts = await _getLoginAttempts(username);
      final blockedUntil = await _getBlockedUntil(username);

      // Проверяем блокировку
      if (blockedUntil != null && DateTime.now().isBefore(blockedUntil)) {
        final remainingTime = blockedUntil.difference(DateTime.now());
        return BruteforceCheckResult.blocked(
          remainingTime: remainingTime,
          reason: 'Слишком много неудачных попыток входа',
        );
      }

      // Проверяем количество попыток
      if (attempts >= _maxAttempts) {
        // Блокируем на определенное время
        final blockUntil =
            DateTime.now().add(Duration(seconds: _blockDurationSeconds));
        await _setBlockedUntil(username, blockUntil);
        await _setLoginAttempts(username, 0);

        return BruteforceCheckResult.blocked(
          remainingTime: Duration(seconds: _blockDurationSeconds),
          reason: 'Превышен лимит попыток входа',
        );
      }

      return BruteforceCheckResult.allowed(
        remainingAttempts: _maxAttempts - attempts,
        delaySeconds: _calculateDelay(attempts),
      );
    } catch (e) {
      // В случае ошибки разрешаем вход для предотвращения блокировки пользователей
      return BruteforceCheckResult.allowed(
          remainingAttempts: _maxAttempts, delaySeconds: 0);
    }
  }

  /// Регистрирует неудачную попытку входа
  Future<void> recordFailedAttempt(String username) async {
    try {
      final attempts = await _getLoginAttempts(username);
      final newAttempts = attempts + 1;

      await _setLoginAttempts(username, newAttempts);
      await _setLastAttempt(username, DateTime.now());

      // Если достигнут лимит попыток, блокируем
      if (newAttempts >= _maxAttempts) {
        final blockUntil =
            DateTime.now().add(Duration(seconds: _blockDurationSeconds));
        await _setBlockedUntil(username, blockUntil);
      }
    } catch (e) {
      // Логируем ошибку, но не блокируем пользователя
      print('Ошибка записи неудачной попытки: $e');
    }
  }

  /// Сбрасывает счетчик попыток после успешного входа
  Future<void> resetAttempts(String username) async {
    try {
      await _setLoginAttempts(username, 0);
      await _setBlockedUntil(username, null);
      await _setLastAttempt(username, null);
    } catch (e) {
      print('Ошибка сброса попыток: $e');
    }
  }

  /// Вычисляет задержку на основе количества попыток
  int _calculateDelay(int attempts) {
    if (attempts == 0) return 0;

    // Экспоненциальная задержка: 2^attempts * initialDelay
    final delay = _initialDelaySeconds * pow(2, attempts - 1);
    return delay.clamp(0, _maxDelaySeconds).toInt();
  }

  /// Проверяет, нужно ли ждать перед следующей попыткой
  Future<bool> shouldWait(String username) async {
    try {
      final lastAttempt = await _getLastAttempt(username);
      if (lastAttempt == null) return false;

      final attempts = await _getLoginAttempts(username);
      final delay = _calculateDelay(attempts);

      if (delay == 0) return false;

      final timeSinceLastAttempt = DateTime.now().difference(lastAttempt);
      return timeSinceLastAttempt.inSeconds < delay;
    } catch (e) {
      return false;
    }
  }

  /// Получает оставшееся время ожидания
  Future<Duration?> getRemainingWaitTime(String username) async {
    try {
      final lastAttempt = await _getLastAttempt(username);
      if (lastAttempt == null) return null;

      final attempts = await _getLoginAttempts(username);
      final delay = _calculateDelay(attempts);

      if (delay == 0) return null;

      final timeSinceLastAttempt = DateTime.now().difference(lastAttempt);
      final remaining = delay - timeSinceLastAttempt.inSeconds;

      return remaining > 0 ? Duration(seconds: remaining) : null;
    } catch (e) {
      return null;
    }
  }

  /// Проверяет доступность биометрической аутентификации
  Future<bool> isBiometricAvailable() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } catch (e) {
      return false;
    }
  }

  /// Выполняет биометрическую аутентификацию
  Future<bool> authenticateWithBiometrics() async {
    try {
      final result = await _localAuth.authenticate(
        localizedReason: 'Подтвердите вашу личность для входа в приложение',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      return result;
    } catch (e) {
      return false;
    }
  }

  /// Включает/выключает биометрическую аутентификацию
  Future<void> setBiometricEnabled(bool enabled) async {
    try {
      await _secureStorage.write(
        key: _biometricEnabledKey,
        value: enabled.toString(),
      );
    } catch (e) {
      print('Ошибка настройки биометрии: $e');
    }
  }

  /// Проверяет, включена ли биометрическая аутентификация
  Future<bool> isBiometricEnabled() async {
    try {
      final value = await _secureStorage.read(key: _biometricEnabledKey);
      return value == 'true';
    } catch (e) {
      return false;
    }
  }

  /// Генерирует и сохраняет ключ шифрования
  Future<String> generateEncryptionKey() async {
    try {
      final random = Random.secure();
      final bytes = List<int>.generate(32, (i) => random.nextInt(256));
      final key = base64Url.encode(bytes);

      await _secureStorage.write(
        key: _encryptionKey,
        value: key,
      );

      return key;
    } catch (e) {
      throw Exception('Не удалось сгенерировать ключ шифрования: $e');
    }
  }

  /// Получает ключ шифрования
  Future<String> getEncryptionKey() async {
    try {
      String? key = await _secureStorage.read(key: _encryptionKey);
      if (key == null) {
        key = await generateEncryptionKey();
      }
      return key;
    } catch (e) {
      throw Exception('Не удалось получить ключ шифрования: $e');
    }
  }

  /// Шифрует данные
  Future<String> encryptData(String data) async {
    try {
      final key = await getEncryptionKey();
      final keyBytes = base64Url.decode(key);
      final dataBytes = utf8.encode(data);

      // Простое XOR шифрование для демонстрации
      // В production используйте более надежные алгоритмы
      final encrypted = <int>[];
      for (int i = 0; i < dataBytes.length; i++) {
        encrypted.add(dataBytes[i] ^ keyBytes[i % keyBytes.length]);
      }

      return base64Url.encode(encrypted);
    } catch (e) {
      throw Exception('Ошибка шифрования: $e');
    }
  }

  /// Расшифровывает данные
  Future<String> decryptData(String encryptedData) async {
    try {
      final key = await getEncryptionKey();
      final keyBytes = base64Url.decode(key);
      final encryptedBytes = base64Url.decode(encryptedData);

      final decrypted = <int>[];
      for (int i = 0; i < encryptedBytes.length; i++) {
        decrypted.add(encryptedBytes[i] ^ keyBytes[i % keyBytes.length]);
      }

      return utf8.decode(decrypted);
    } catch (e) {
      throw Exception('Ошибка расшифровки: $e');
    }
  }

  /// Очищает все данные защиты
  Future<void> clearAllData() async {
    try {
      await _secureStorage.deleteAll();
    } catch (e) {
      print('Ошибка очистки данных: $e');
    }
  }

  // Приватные методы для работы с безопасным хранилищем

  Future<int> _getLoginAttempts(String username) async {
    try {
      final key = '${_attemptsKey}_$username';
      final value = await _secureStorage.read(key: key);
      return value != null ? int.tryParse(value) ?? 0 : 0;
    } catch (e) {
      return 0;
    }
  }

  Future<void> _setLoginAttempts(String username, int attempts) async {
    try {
      final key = '${_attemptsKey}_$username';
      await _secureStorage.write(key: key, value: attempts.toString());
    } catch (e) {
      print('Ошибка записи попыток: $e');
    }
  }

  Future<DateTime?> _getBlockedUntil(String username) async {
    try {
      final key = '${_blockedUntilKey}_$username';
      final value = await _secureStorage.read(key: key);
      return value != null ? DateTime.parse(value) : null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _setBlockedUntil(String username, DateTime? blockedUntil) async {
    try {
      final key = '${_blockedUntilKey}_$username';
      if (blockedUntil != null) {
        await _secureStorage.write(
            key: key, value: blockedUntil.toIso8601String());
      } else {
        await _secureStorage.delete(key: key);
      }
    } catch (e) {
      print('Ошибка записи блокировки: $e');
    }
  }

  Future<DateTime?> _getLastAttempt(String username) async {
    try {
      final key = '${_lastAttemptKey}_$username';
      final value = await _secureStorage.read(key: key);
      return value != null ? DateTime.parse(value) : null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _setLastAttempt(String username, DateTime? lastAttempt) async {
    try {
      final key = '${_lastAttemptKey}_$username';
      if (lastAttempt != null) {
        await _secureStorage.write(
            key: key, value: lastAttempt.toIso8601String());
      } else {
        await _secureStorage.delete(key: key);
      }
    } catch (e) {
      print('Ошибка записи времени попытки: $e');
    }
  }
}

/// Результат проверки возможности входа
class BruteforceCheckResult {
  final bool isAllowed;
  final String? reason;
  final Duration? remainingTime;
  final int? remainingAttempts;
  final int? delaySeconds;

  const BruteforceCheckResult._({
    required this.isAllowed,
    this.reason,
    this.remainingTime,
    this.remainingAttempts,
    this.delaySeconds,
  });

  factory BruteforceCheckResult.allowed({
    int? remainingAttempts,
    int? delaySeconds,
  }) {
    return BruteforceCheckResult._(
      isAllowed: true,
      remainingAttempts: remainingAttempts,
      delaySeconds: delaySeconds,
    );
  }

  factory BruteforceCheckResult.blocked({
    required Duration remainingTime,
    required String reason,
  }) {
    return BruteforceCheckResult._(
      isAllowed: false,
      reason: reason,
      remainingTime: remainingTime,
    );
  }
}
