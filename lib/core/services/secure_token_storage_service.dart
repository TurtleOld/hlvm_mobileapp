import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hlvm_mobileapp/core/services/bruteforce_protection_service.dart';

/// Сервис для безопасного хранения токенов аутентификации
/// Использует Flutter Secure Storage и дополнительное шифрование
class SecureTokenStorageService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _tokenExpiryKey = 'token_expiry';
  static const String _userDataKey = 'user_data';
  static const String _sessionIdKey = 'session_id';

  final FlutterSecureStorage _secureStorage;
  final BruteforceProtectionService _bruteforceProtection;

  SecureTokenStorageService({
    FlutterSecureStorage? secureStorage,
    BruteforceProtectionService? bruteforceProtection,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _bruteforceProtection =
            bruteforceProtection ?? BruteforceProtectionService();

  /// Сохраняет токен доступа с шифрованием
  Future<void> storeAccessToken(String token, {Duration? expiry}) async {
    try {
      // Шифруем токен перед сохранением
      final encryptedToken = await _bruteforceProtection.encryptData(token);

      await _secureStorage.write(
        key: _accessTokenKey,
        value: encryptedToken,
      );

      // Сохраняем время истечения токена
      if (expiry != null) {
        final expiryTime = DateTime.now().add(expiry);
        await _secureStorage.write(
          key: _tokenExpiryKey,
          value: expiryTime.toIso8601String(),
        );
      }

      // Генерируем уникальный ID сессии
      await _generateSessionId();
    } catch (e) {
      throw Exception('Не удалось сохранить токен доступа: $e');
    }
  }

  /// Получает токен доступа с расшифровкой
  Future<String?> getAccessToken() async {
    try {
      final encryptedToken = await _secureStorage.read(key: _accessTokenKey);
      if (encryptedToken == null) return null;

      // Проверяем, не истек ли токен
      if (await _isTokenExpired()) {
        await clearTokens();
        return null;
      }

      // Расшифровываем токен
      return await _bruteforceProtection.decryptData(encryptedToken);
    } catch (e) {
      // При ошибке расшифровки очищаем токены
      await clearTokens();
      return null;
    }
  }

  /// Сохраняет refresh токен
  Future<void> storeRefreshToken(String token) async {
    try {
      final encryptedToken = await _bruteforceProtection.encryptData(token);
      await _secureStorage.write(
        key: _refreshTokenKey,
        value: encryptedToken,
      );
    } catch (e) {
      throw Exception('Не удалось сохранить refresh токен: $e');
    }
  }

  /// Получает refresh токен
  Future<String?> getRefreshToken() async {
    try {
      final encryptedToken = await _secureStorage.read(key: _refreshTokenKey);
      if (encryptedToken == null) return null;

      return await _bruteforceProtection.decryptData(encryptedToken);
    } catch (e) {
      return null;
    }
  }

  /// Сохраняет данные пользователя
  Future<void> storeUserData(Map<String, dynamic> userData) async {
    try {
      final jsonData = jsonEncode(userData);
      final encryptedData = await _bruteforceProtection.encryptData(jsonData);

      await _secureStorage.write(
        key: _userDataKey,
        value: encryptedData,
      );
    } catch (e) {
      throw Exception('Не удалось сохранить данные пользователя: $e');
    }
  }

  /// Получает данные пользователя
  Future<Map<String, dynamic>?> getUserData() async {
    try {
      final encryptedData = await _secureStorage.read(key: _userDataKey);
      if (encryptedData == null) return null;

      final jsonData = await _bruteforceProtection.decryptData(encryptedData);
      return jsonDecode(jsonData) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// Проверяет, истек ли токен
  Future<bool> _isTokenExpired() async {
    try {
      final expiryString = await _secureStorage.read(key: _tokenExpiryKey);
      if (expiryString == null) return false;

      final expiryTime = DateTime.parse(expiryString);
      return DateTime.now().isAfter(expiryTime);
    } catch (e) {
      return true; // При ошибке считаем токен истекшим
    }
  }

  /// Проверяет, есть ли действительный токен
  Future<bool> hasValidToken() async {
    try {
      final token = await getAccessToken();
      return token != null && !await _isTokenExpired();
    } catch (e) {
      return false;
    }
  }

  /// Обновляет токены
  Future<void> updateTokens({
    required String accessToken,
    String? refreshToken,
    Duration? expiry,
  }) async {
    try {
      await storeAccessToken(accessToken, expiry: expiry);
      if (refreshToken != null) {
        await storeRefreshToken(refreshToken);
      }

      // Обновляем ID сессии
      await _generateSessionId();
    } catch (e) {
      throw Exception('Не удалось обновить токены: $e');
    }
  }

  /// Генерирует уникальный ID сессии
  Future<void> _generateSessionId() async {
    try {
      final random = Random.secure();
      final sessionId = base64Url.encode(
        List<int>.generate(32, (i) => random.nextInt(256)),
      );

      await _secureStorage.write(
        key: _sessionIdKey,
        value: sessionId,
      );
    } catch (e) {
      // Игнорируем ошибки генерации ID сессии
    }
  }

  /// Получает ID текущей сессии
  Future<String?> getSessionId() async {
    try {
      return await _secureStorage.read(key: _sessionIdKey);
    } catch (e) {
      return null;
    }
  }

  /// Очищает все токены и данные сессии
  Future<void> clearTokens() async {
    try {
      await _secureStorage.delete(key: _accessTokenKey);
      await _secureStorage.delete(key: _refreshTokenKey);
      await _secureStorage.delete(key: _tokenExpiryKey);
      await _secureStorage.delete(key: _userDataKey);
      await _secureStorage.delete(key: _sessionIdKey);
    } catch (e) {
      // Игнорируем ошибки очистки
    }
  }

  /// Получает информацию о токенах (для отладки)
  Future<Map<String, dynamic>> getTokenInfo() async {
    try {
      final hasAccessToken = await getAccessToken() != null;
      final hasRefreshToken = await getRefreshToken() != null;
      final isValidToken = await hasValidToken();
      final sessionId = await getSessionId();
      final userData = await getUserData();

      return {
        'hasAccessToken': hasAccessToken,
        'hasRefreshToken': hasRefreshToken,
        'hasValidToken': isValidToken,
        'sessionId': sessionId,
        'hasUserData': userData != null,
        'userDataKeys': userData?.keys.toList() ?? [],
      };
    } catch (e) {
      return {
        'error': e.toString(),
      };
    }
  }

  /// Проверяет целостность сохраненных данных
  Future<bool> validateStoredData() async {
    try {
      final accessToken = await getAccessToken();
      final refreshToken = await getRefreshToken();
      final userData = await getUserData();
      final sessionId = await getSessionId();

      // Проверяем, что хотя бы основные данные доступны
      return accessToken != null && sessionId != null;
    } catch (e) {
      return false;
    }
  }

  /// Создает резервную копию токенов (для миграции)
  Future<Map<String, String>> createBackup() async {
    try {
      final backup = <String, String>{};

      final accessToken = await getAccessToken();
      if (accessToken != null) {
        backup['access_token'] = accessToken;
      }

      final refreshToken = await getRefreshToken();
      if (refreshToken != null) {
        backup['refresh_token'] = refreshToken;
      }

      final userData = await getUserData();
      if (userData != null) {
        backup['user_data'] = jsonEncode(userData);
      }

      return backup;
    } catch (e) {
      throw Exception('Не удалось создать резервную копию: $e');
    }
  }

  /// Восстанавливает токены из резервной копии
  Future<void> restoreFromBackup(Map<String, String> backup) async {
    try {
      // Очищаем текущие данные
      await clearTokens();

      // Восстанавливаем токены
      if (backup.containsKey('access_token')) {
        await storeAccessToken(backup['access_token']!);
      }

      if (backup.containsKey('refresh_token')) {
        await storeRefreshToken(backup['refresh_token']!);
      }

      if (backup.containsKey('user_data')) {
        final userData =
            jsonDecode(backup['user_data']!) as Map<String, dynamic>;
        await storeUserData(userData);
      }

      // Генерируем новый ID сессии
      await _generateSessionId();
    } catch (e) {
      throw Exception('Не удалось восстановить из резервной копии: $e');
    }
  }
}
