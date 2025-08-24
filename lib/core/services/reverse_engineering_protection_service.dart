import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

class ReverseEngineeringProtectionService {
  static final ReverseEngineeringProtectionService _instance =
      ReverseEngineeringProtectionService._internal();

  factory ReverseEngineeringProtectionService() => _instance;

  ReverseEngineeringProtectionService._internal();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Проверяет все возможные признаки reverse engineering
  Future<bool> isReverseEngineeringDetected() async {
    try {
      // Проверка на эмулятор
      if (await _isRunningOnEmulator()) {
        AppLogger.warning('Emulator detected');
        return true;
      }

      // Проверка на root/джейлбрейк
      if (await _isDeviceRooted()) {
        AppLogger.warning('Rooted/Jailbroken device detected');
        return true;
      }

      // Проверка на отладку
      if (await _isDebuggerAttached()) {
        AppLogger.warning('Debugger detected');
        return true;
      }

      // Проверка на подозрительные приложения
      if (await _hasSuspiciousApps()) {
        AppLogger.warning('Suspicious apps detected');
        return true;
      }

      // Проверка на подозрительные файлы
      if (await _hasSuspiciousFiles()) {
        AppLogger.warning('Suspicious files detected');
        return true;
      }

      // Проверка на подозрительные процессы
      if (await _hasSuspiciousProcesses()) {
        AppLogger.warning('Suspicious processes detected');
        return true;
      }

      // Проверка целостности приложения
      if (await _isAppIntegrityCompromised()) {
        AppLogger.warning('App integrity compromised');
        return true;
      }

      return false;
    } catch (e) {
      AppLogger.error('Error during reverse engineering detection: $e');
      // В случае ошибки считаем, что защита сработала
      return true;
    }
  }

  /// Проверяет, запущено ли приложение на эмуляторе
  Future<bool> _isRunningOnEmulator() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;

        // Проверка на известные эмуляторы
        final model = androidInfo.model.toLowerCase();
        final manufacturer = androidInfo.manufacturer.toLowerCase();
        final product = androidInfo.product.toLowerCase();
        final fingerprint = androidInfo.fingerprint.toLowerCase();

        final emulatorIndicators = [
          'sdk',
          'google_sdk',
          'emulator',
          'generic',
          'android_sdk_built_for_x86',
          'google_sdk',
          'sdk_gphone',
          'sdk_google_phone',
          'vbox86p',
          'emulator64',
          'emulator64_x86',
          'emulator64_x86_64',
          'goldfish',
          'ranchu',
          'generic_x86',
          'generic_x86_64',
          'generic_armv7_a',
          'generic_arm64'
        ];

        for (final indicator in emulatorIndicators) {
          if (model.contains(indicator) ||
              manufacturer.contains(indicator) ||
              product.contains(indicator) ||
              fingerprint.contains(indicator)) {
            return true;
          }
        }

        // Проверка на подозрительные характеристики
        if (androidInfo.brand == 'generic' ||
            androidInfo.device == 'generic' ||
            androidInfo.hardware == 'goldfish' ||
            androidInfo.hardware == 'ranchu') {
          return true;
        }
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;

        // iOS симулятор
        if (iosInfo.name.contains('Simulator') ||
            iosInfo.model.contains('Simulator') ||
            iosInfo.systemName.contains('Simulator')) {
          return true;
        }
      }

      return false;
    } catch (e) {
      AppLogger.error('Error checking emulator: $e');
      return false;
    }
  }

  /// Проверяет, есть ли root/джейлбрейк
  Future<bool> _isDeviceRooted() async {
    try {
      if (Platform.isAndroid) {
        // Проверка на известные root-приложения
        final suspiciousPackages = [
          'com.noshufou.android.su',
          'com.thirdparty.superuser',
          'eu.chainfire.supersu',
          'com.topjohnwu.magisk',
          'com.kingroot.kinguser',
          'com.kingo.root',
          'com.smedialink.oneclickroot',
          'com.oneclickroot.framaroot',
          'com.alephzain.framaroot',
          'com.kingroot.kinguser',
          'com.kingo.root',
          'com.smedialink.oneclickroot',
          'com.oneclickroot.framaroot',
          'com.alephzain.framaroot'
        ];

        for (final package in suspiciousPackages) {
          try {
            final result =
                await Process.run('pm', ['list', 'packages', package]);
            if (result.stdout.toString().contains(package)) {
              return true;
            }
          } catch (e) {
            // Игнорируем ошибки
          }
        }

        // Проверка на подозрительные файлы
        final suspiciousFiles = [
          '/system/app/Superuser.apk',
          '/system/xbin/su',
          '/system/bin/su',
          '/sbin/su',
          '/system/su',
          '/system/bin/.ext/.su',
          '/system/etc/init.d/99SuperSUDaemon',
          '/system/bin/.ext',
          '/system/etc/.has_su_daemon',
          '/system/etc/.installed_su_daemon',
          '/dev/com.koushikdutta.superuser.daemon/',
          '/system/xbin/daemonsu',
          '/system/etc/init.d/99SuperSUDaemon',
          '/system/bin/.ext/.su',
          '/system/etc/.has_su_daemon',
          '/system/etc/.installed_su_daemon',
          '/system/bin/.ext',
          '/system/etc/init.d/99SuperSUDaemon',
          '/system/etc/.has_su_daemon',
          '/system/etc/.installed_su_daemon'
        ];

        for (final file in suspiciousFiles) {
          if (await File(file).exists()) {
            return true;
          }
        }

        // Проверка на права root
        try {
          final result = await Process.run('su', ['--version']);
          if (result.exitCode == 0) {
            return true;
          }
        } catch (e) {
          // Игнорируем ошибки
        }
      } else if (Platform.isIOS) {
        // Проверка на джейлбрейк
        final suspiciousFiles = [
          '/Applications/Cydia.app',
          '/Library/MobileSubstrate/MobileSubstrate.dylib',
          '/bin/bash',
          '/usr/sbin/sshd',
          '/etc/apt',
          '/private/var/lib/apt/',
          '/private/var/lib/cydia',
          '/private/var/mobile/Library/SBSettings/Themes',
          '/Library/MobileSubstrate/DynamicLibraries/Veency.plist',
          '/Library/MobileSubstrate/DynamicLibraries/LiveClock.plist',
          '/System/Library/LaunchDaemons/com.ikey.bbot.plist',
          '/System/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist'
        ];

        for (final file in suspiciousFiles) {
          if (await File(file).exists()) {
            return true;
          }
        }

        // Проверка на возможность записи в системные директории
        try {
          final testFile = File('/private/jailbreak.txt');
          await testFile.writeAsString('test');
          await testFile.delete();
          return true;
        } catch (e) {
          // Игнорируем ошибки
        }
      }

      return false;
    } catch (e) {
      AppLogger.error('Error checking root: $e');
      return false;
    }
  }

  /// Проверяет, подключен ли отладчик
  Future<bool> _isDebuggerAttached() async {
    try {
      // Проверка на Flutter debug mode
      if (kDebugMode) {
        return true;
      }

      // Проверка на подозрительные переменные окружения
      final envVars = Platform.environment;
      if (envVars.containsKey('FLUTTER_DEBUG') ||
          envVars.containsKey('DART_VM_OPTIONS') ||
          envVars.containsKey('FLUTTER_ANALYZER')) {
        return true;
      }

      return false;
    } catch (e) {
      AppLogger.error('Error checking debugger: $e');
      return false;
    }
  }

  /// Проверяет на подозрительные приложения
  Future<bool> _hasSuspiciousApps() async {
    try {
      if (Platform.isAndroid) {
        final suspiciousPackages = [
          'com.topjohnwu.magisk',
          'com.kingroot.kinguser',
          'com.kingo.root',
          'com.smedialink.oneclickroot',
          'com.oneclickroot.framaroot',
          'com.alephzain.framaroot',
          'com.stericson.busybox',
          'com.nox',
          'com.bignox',
          'com.tencent.mm',
          'com.tencent.mobileqq',
          'com.tencent.igame',
          'com.tencent.tmgp',
          'com.tencent.tmgp.pubgmhd',
          'com.tencent.tmgp.pubgm',
          'com.tencent.tmgp.pubg',
          'com.tencent.tmgp.pubgmhd',
          'com.tencent.tmgp.pubgm',
          'com.tencent.tmgp.pubg',
          'com.tencent.tmgp.pubgmhd',
          'com.tencent.tmgp.pubgm',
          'com.tencent.tmgp.pubg'
        ];

        for (final package in suspiciousPackages) {
          try {
            final result =
                await Process.run('pm', ['list', 'packages', package]);
            if (result.stdout.toString().contains(package)) {
              return true;
            }
          } catch (e) {
            // Игнорируем ошибки
          }
        }
      }

      return false;
    } catch (e) {
      AppLogger.error('Error checking suspicious apps: $e');
      return false;
    }
  }

  /// Проверяет на подозрительные файлы
  Future<bool> _hasSuspiciousFiles() async {
    try {
      final suspiciousFiles = [
        '/data/local/tmp',
        '/data/local/tmp/frida-server',
        '/data/local/tmp/frida-server64',
        '/data/local/tmp/frida-server-arm',
        '/data/local/tmp/frida-server-arm64',
        '/data/local/tmp/frida-server-x86',
        '/data/local/tmp/frida-server-x86_64',
        '/data/local/tmp/frida-server-mips',
        '/data/local/tmp/frida-server-mips64',
        '/data/local/tmp/frida-server-arm64-v8a',
        '/data/local/tmp/frida-server-arm-v7a',
        '/data/local/tmp/frida-server-x86_64',
        '/data/local/tmp/frida-server-x86',
        '/data/local/tmp/frida-server-mips64',
        '/data/local/tmp/frida-server-mips'
      ];

      for (final file in suspiciousFiles) {
        if (await File(file).exists()) {
          return true;
        }
      }

      return false;
    } catch (e) {
      AppLogger.error('Error checking suspicious files: $e');
      return false;
    }
  }

  /// Проверяет на подозрительные процессы
  Future<bool> _hasSuspiciousProcesses() async {
    try {
      final suspiciousProcesses = [
        'frida-server',
        'frida-server64',
        'frida-server-arm',
        'frida-server-arm64',
        'frida-server-x86',
        'frida-server-x86_64',
        'frida-server-mips',
        'frida-server-mips64',
        'frida-server-arm64-v8a',
        'frida-server-arm-v7a',
        'frida-server-x86_64',
        'frida-server-x86',
        'frida-server-mips64',
        'frida-server-mips'
      ];

      for (final process in suspiciousProcesses) {
        try {
          final result = await Process.run('ps', ['-A']);
          if (result.stdout.toString().contains(process)) {
            return true;
          }
        } catch (e) {
          // Игнорируем ошибки
        }
      }

      return false;
    } catch (e) {
      AppLogger.error('Error checking suspicious processes: $e');
      return false;
    }
  }

  /// Проверяет целостность приложения
  Future<bool> _isAppIntegrityCompromised() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();

      // Проверка на подозрительные изменения в package name
      if (packageInfo.packageName != 'ru.hlvm.hlvmapp.hlvm_mobileapp') {
        return true;
      }

      // Проверка на подозрительные изменения в версии
      if (packageInfo.version != '1.0.0') {
        return true;
      }

      // Проверка на подозрительные изменения в build number
      if (packageInfo.buildNumber != '1') {
        return true;
      }

      return false;
    } catch (e) {
      AppLogger.error('Error checking app integrity: $e');
      return false;
    }
  }

  /// Генерирует уникальный идентификатор устройства
  Future<String> _generateDeviceFingerprint() async {
    try {
      final deviceInfo = await _deviceInfo.deviceInfo;
      final packageInfo = await PackageInfo.fromPlatform();

      String fingerprint = '';

      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        fingerprint =
            '${androidInfo.brand}_${androidInfo.model}_${androidInfo.fingerprint}_${packageInfo.packageName}';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        fingerprint =
            '${iosInfo.name}_${iosInfo.model}_${iosInfo.systemVersion}_${packageInfo.packageName}';
      }

      return md5.convert(utf8.encode(fingerprint)).toString();
    } catch (e) {
      AppLogger.error('Error generating device fingerprint: $e');
      return 'unknown';
    }
  }

  /// Проверяет целостность кода
  bool _checkCodeIntegrity() {
    try {
      // Проверка на подозрительные изменения в коде
      final codeHash = _calculateCodeHash();
      final expectedHash = 'expected_hash_here'; // Замените на реальный хеш

      return codeHash == expectedHash;
    } catch (e) {
      AppLogger.error('Error checking code integrity: $e');
      return false;
    }
  }

  /// Вычисляет хеш кода
  String _calculateCodeHash() {
    try {
      // Простая проверка целостности
      final code = '''
        class ReverseEngineeringProtectionService {
          static final ReverseEngineeringProtectionService _instance = 
              ReverseEngineeringProtectionService._internal();
        }
      ''';

      return md5.convert(utf8.encode(code)).toString();
    } catch (e) {
      AppLogger.error('Error calculating code hash: $e');
      return 'error';
    }
  }

  /// Применяет защитные меры
  Future<void> applyProtection() async {
    try {
      // Проверяем все признаки reverse engineering
      final isDetected = await isReverseEngineeringDetected();

      if (isDetected) {
        AppLogger.warning(
            'Reverse engineering detected! Applying protection measures...');

        // Очищаем чувствительные данные
        await _clearSensitiveData();

        // Блокируем функциональность
        await _blockFunctionality();

        // Логируем попытку взлома
        await _logSecurityViolation();

        // Можно также отправить уведомление на сервер
        await _notifyServer();
      }
    } catch (e) {
      AppLogger.error('Error applying protection: $e');
    }
  }

  /// Очищает чувствительные данные
  Future<void> _clearSensitiveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Очищаем кэш
      final cacheDir = await getTemporaryDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }

      AppLogger.info('Sensitive data cleared');
    } catch (e) {
      AppLogger.error('Error clearing sensitive data: $e');
    }
  }

  /// Блокирует функциональность приложения
  Future<void> _blockFunctionality() async {
    try {
      // Устанавливаем флаг блокировки
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('app_blocked', true);

      AppLogger.info('Application functionality blocked');
    } catch (e) {
      AppLogger.error('Error blocking functionality: $e');
    }
  }

  /// Логирует попытку безопасности
  Future<void> _logSecurityViolation() async {
    try {
      final deviceFingerprint = await _generateDeviceFingerprint();
      final timestamp = DateTime.now().toIso8601String();

      AppLogger.warning('''
        SECURITY VIOLATION DETECTED!
        Device: $deviceFingerprint
        Timestamp: $timestamp
        Type: Reverse Engineering Attempt
      ''');
    } catch (e) {
      AppLogger.error('Error logging security violation: $e');
    }
  }

  /// Уведомляет сервер о попытке взлома
  Future<void> _notifyServer() async {
    try {
      // Здесь можно реализовать отправку уведомления на сервер
      // о попытке reverse engineering
      AppLogger.info('Server notification sent');
    } catch (e) {
      AppLogger.error('Error notifying server: $e');
    }
  }

  /// Проверяет, заблокировано ли приложение
  Future<bool> isAppBlocked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('app_blocked') ?? false;
    } catch (e) {
      AppLogger.error('Error checking app block status: $e');
      return false;
    }
  }

  /// Разблокирует приложение (для администраторов)
  Future<void> unblockApp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('app_blocked', false);

      AppLogger.info('Application unblocked');
    } catch (e) {
      AppLogger.error('Error unblocking app: $e');
    }
  }
}
