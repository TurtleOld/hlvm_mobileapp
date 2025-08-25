import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Сервис для безопасного хранения токенов аутентификации
/// Использует Flutter Secure Storage
class SecureTokenStorageService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _tokenExpiryKey = 'token_expiry';
  static const String _userDataKey = 'user_data';
  static const String _sessionIdKey = 'session_id';
  static const String _githubTokenKey = 'github_token';

  final FlutterSecureStorage _secureStorage;

  SecureTokenStorageService({
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Сохраняет токен доступа
  Future<void> storeAccessToken(String token, {Duration? expiry}) async {
    try {
      await _secureStorage.write(
        key: _accessTokenKey,
        value: token,
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

  /// Получает токен доступа
  Future<String?> getAccessToken() async {
    try {
      final token = await _secureStorage.read(key: _accessTokenKey);
      if (token == null) return null;

      // Проверяем, не истек ли токен
      if (await _isTokenExpired()) {
        await clearTokens();
        return null;
      }

      return token;
    } catch (e) {
      // При ошибке очищаем токены
      await clearTokens();
      return null;
    }
  }

  /// Сохраняет refresh токен
  Future<void> storeRefreshToken(String token) async {
    try {
      await _secureStorage.write(
        key: _refreshTokenKey,
        value: token,
      );
    } catch (e) {
      throw Exception('Не удалось сохранить refresh токен: $e');
    }
  }

  /// Получает refresh токен
  Future<String?> getRefreshToken() async {
    try {
      final token = await _secureStorage.read(key: _refreshTokenKey);
      if (token == null) return null;

      return token;
    } catch (e) {
      return null;
    }
  }

  /// Сохраняет данные пользователя
  Future<void> storeUserData(Map<String, dynamic> userData) async {
    try {
      final jsonData = jsonEncode(userData);
      await _secureStorage.write(
        key: _userDataKey,
        value: jsonData,
      );
    } catch (e) {
      throw Exception('Не удалось сохранить данные пользователя: $e');
    }
  }

  /// Получает данные пользователя
  Future<Map<String, dynamic>?> getUserData() async {
    try {
      final jsonData = await _secureStorage.read(key: _userDataKey);
      if (jsonData == null) return null;

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

  /// Сохраняет GitHub токен
  Future<void> storeGithubToken(String token) async {
    try {
      await _secureStorage.write(
        key: _githubTokenKey,
        value: token,
      );
    } catch (e) {
      throw Exception('Не удалось сохранить GitHub токен: $e');
    }
  }

  /// Получает GitHub токен
  Future<String?> getGithubToken() async {
    try {
      return await _secureStorage.read(key: _githubTokenKey);
    } catch (e) {
      return null;
    }
  }

  /// Удаляет GitHub токен
  Future<void> removeGithubToken() async {
    try {
      await _secureStorage.delete(key: _githubTokenKey);
    } catch (e) {
      // Игнорируем ошибки при удалении
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
      // НЕ удаляем GitHub токен при очистке, так как он не связан с сессией
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
      final hasGithubToken = await getGithubToken() != null;

      return {
        'hasAccessToken': hasAccessToken,
        'hasRefreshToken': hasRefreshToken,
        'hasValidToken': isValidToken,
        'sessionId': sessionId,
        'hasUserData': userData != null,
        'userDataKeys': userData?.keys.toList() ?? [],
        'hasGithubToken': hasGithubToken,
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
