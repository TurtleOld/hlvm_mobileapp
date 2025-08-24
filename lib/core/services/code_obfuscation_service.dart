import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import '../utils/logger.dart';

class CodeObfuscationService {
  static final CodeObfuscationService _instance =
      CodeObfuscationService._internal();

  factory CodeObfuscationService() => _instance;

  CodeObfuscationService._internal();

  final Random _random = Random.secure();

  /// Генерирует случайную строку для обфускации
  String _generateRandomString(int length) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return String.fromCharCodes(Iterable.generate(
        length, (_) => chars.codeUnitAt(_random.nextInt(chars.length))));
  }

  /// Обфусцирует строки в коде
  String obfuscateString(String input) {
    try {
      if (input.isEmpty) return input;

      // Создаем случайный ключ
      final key = _generateRandomString(16);

      // Кодируем строку в base64
      final encoded = base64.encode(utf8.encode(input));

      // Создаем обфусцированную версию
      final obfuscated = _xorEncrypt(encoded, key);

      // Возвращаем обфусцированную строку с ключом
      return base64.encode(utf8.encode('$key:$obfuscated'));
    } catch (e) {
      AppLogger.error('Error obfuscating string: $e');
      return input;
    }
  }

  /// Деобфусцирует строки
  String deobfuscateString(String obfuscated) {
    try {
      if (obfuscated.isEmpty) return obfuscated;

      // Декодируем base64
      final decoded = utf8.decode(base64.decode(obfuscated));

      // Разделяем ключ и данные
      final parts = decoded.split(':');
      if (parts.length != 2) return obfuscated;

      final key = parts[0];
      final data = parts[1];

      // Дешифруем
      final decrypted = _xorDecrypt(data, key);

      // Декодируем из base64
      return utf8.decode(base64.decode(decrypted));
    } catch (e) {
      AppLogger.error('Error deobfuscating string: $e');
      return obfuscated;
    }
  }

  /// XOR шифрование
  String _xorEncrypt(String data, String key) {
    final dataBytes = utf8.encode(data);
    final keyBytes = utf8.encode(key);
    final result = <int>[];

    for (int i = 0; i < dataBytes.length; i++) {
      result.add(dataBytes[i] ^ keyBytes[i % keyBytes.length]);
    }

    return base64.encode(result);
  }

  /// XOR дешифрование
  String _xorDecrypt(String encrypted, String key) {
    final encryptedBytes = base64.decode(encrypted);
    final keyBytes = utf8.encode(key);
    final result = <int>[];

    for (int i = 0; i < encryptedBytes.length; i++) {
      result.add(encryptedBytes[i] ^ keyBytes[i % keyBytes.length]);
    }

    return base64.encode(result);
  }

  /// Создает обфусцированные константы
  Map<String, String> createObfuscatedConstants() {
    return {
      'API_BASE_URL': obfuscateString('https://api.example.com'),
      'API_KEY': obfuscateString('your_api_key_here'),
      'SECRET_TOKEN': obfuscateString('your_secret_token_here'),
      'ENCRYPTION_KEY': obfuscateString('your_encryption_key_here'),
    };
  }

  /// Проверяет целостность обфусцированных данных
  bool verifyObfuscatedIntegrity(String obfuscated, String expected) {
    try {
      final deobfuscated = deobfuscateString(obfuscated);
      return deobfuscated == expected;
    } catch (e) {
      AppLogger.error('Error verifying obfuscated integrity: $e');
      return false;
    }
  }

  /// Создает динамический ключ на основе времени
  String generateTimeBasedKey() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch;
    final dayOfYear = now.difference(DateTime(now.year)).inDays;

    final base = '$timestamp:$dayOfYear:${now.hour}:${now.minute}';
    return md5.convert(utf8.encode(base)).toString().substring(0, 16);
  }

  /// Обфусцирует числовые значения
  int obfuscateNumber(int number) {
    final key = _random.nextInt(1000) + 1;
    return (number * key) + _random.nextInt(100);
  }

  /// Деобфусцирует числовые значения
  int deobfuscateNumber(int obfuscated, int key) {
    return (obfuscated - _random.nextInt(100)) ~/ key;
  }

  /// Создает обфусцированный хеш
  String createObfuscatedHash(String input) {
    final hash = md5.convert(utf8.encode(input)).toString();
    return obfuscateString(hash);
  }

  /// Проверяет обфусцированный хеш
  bool verifyObfuscatedHash(String input, String obfuscatedHash) {
    try {
      final expectedHash = md5.convert(utf8.encode(input)).toString();
      final actualHash = deobfuscateString(obfuscatedHash);
      return expectedHash == actualHash;
    } catch (e) {
      AppLogger.error('Error verifying obfuscated hash: $e');
      return false;
    }
  }
}
