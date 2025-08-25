import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:talker/talker.dart';

class CacheService {
  static const String _receiptsCacheKey = 'receipts_cache';
  static const String _sellersCacheKey = 'sellers_cache';
  static const int _maxCacheSizeMB = 500;
  static const Duration _cacheExpiration = Duration(hours: 24);

  final Talker _talker = Talker();
  late final DefaultCacheManager _cacheManager;

  CacheService() {
    _cacheManager = DefaultCacheManager();
    _initializeCache();
  }

  Future<void> _initializeCache() async {
    try {
      await _cleanupOldCache();
      _talker.log('Cache service initialized');
    } catch (e) {
      _talker.error('Failed to initialize cache service', e);
    }
  }

  Future<void> cacheReceipts(List<dynamic> receipts) async {
    try {
      final cacheData = {
        'data': receipts,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'expires_at':
            DateTime.now().add(_cacheExpiration).millisecondsSinceEpoch,
      };

      await _cacheManager.putFile(
        _receiptsCacheKey,
        Uint8List.fromList(utf8.encode(json.encode(cacheData))),
        key: _receiptsCacheKey,
      );

      _talker.log('Receipts cached successfully (${receipts.length} items)');
    } catch (e) {
      _talker.error('Failed to cache receipts', e);
    }
  }

  Future<List<dynamic>?> getCachedReceipts() async {
    try {
      final fileInfo = await _cacheManager.getFileFromCache(_receiptsCacheKey);
      if (fileInfo == null) return null;

      final file = fileInfo.file;
      if (!await file.exists()) return null;

      final content = await file.readAsString();
      final cacheData = json.decode(content) as Map<String, dynamic>;

      final expiresAt =
          DateTime.fromMillisecondsSinceEpoch(cacheData['expires_at']);
      if (DateTime.now().isAfter(expiresAt)) {
        await _cacheManager.removeFile(_receiptsCacheKey);
        return null;
      }

      _talker.log(
          'Receipts retrieved from cache (${cacheData['data'].length} items)');
      return cacheData['data'] as List<dynamic>;
    } catch (e) {
      _talker.error('Failed to get cached receipts', e);
      return null;
    }
  }

  Future<void> cacheSellerInfo(
      int sellerId, Map<String, dynamic> sellerData) async {
    try {
      final cacheKey = '${_sellersCacheKey}_$sellerId';
      final cacheData = {
        'data': sellerData,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'expires_at':
            DateTime.now().add(_cacheExpiration).millisecondsSinceEpoch,
      };

      await _cacheManager.putFile(
        cacheKey,
        Uint8List.fromList(utf8.encode(json.encode(cacheData))),
        key: cacheKey,
      );

      _talker.log('Seller info cached successfully for ID: $sellerId');
    } catch (e) {
      _talker.error('Failed to cache seller info', e);
    }
  }

  /// Получает кешированную информацию о продавце
  Future<Map<String, dynamic>?> getCachedSellerInfo(int sellerId) async {
    try {
      final cacheKey = '${_sellersCacheKey}_$sellerId';
      final fileInfo = await _cacheManager.getFileFromCache(cacheKey);
      if (fileInfo == null) return null;

      final file = fileInfo.file;
      if (!await file.exists()) return null;

      final content = await file.readAsString();
      final cacheData = json.decode(content) as Map<String, dynamic>;

      final expiresAt =
          DateTime.fromMillisecondsSinceEpoch(cacheData['expires_at']);
      if (DateTime.now().isAfter(expiresAt)) {
        await _cacheManager.removeFile(cacheKey);
        return null;
      }

      _talker.log('Seller info retrieved from cache for ID: $sellerId');
      return cacheData['data'] as Map<String, dynamic>;
    } catch (e) {
      _talker.error('Failed to get cached seller info', e);
      return null;
    }
  }

  /// Очищает весь кеш
  Future<void> clearAllCache() async {
    try {
      await _cacheManager.emptyCache();
      _talker.log('All cache cleared');
    } catch (e) {
      _talker.error('Failed to clear cache', e);
    }
  }

  /// Получает размер кеша в байтах
  Future<int> getCacheSize() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final cachePath = cacheDir.path;

      int totalSize = 0;
      await _calculateDirectorySize(Directory(cachePath), totalSize);

      return totalSize;
    } catch (e) {
      _talker.error('Failed to calculate cache size', e);
      return 0;
    }
  }

  Future<void> _calculateDirectorySize(Directory dir, int totalSize) async {
    try {
      final entities = dir.listSync();
      for (final entity in entities) {
        if (entity is File) {
          totalSize += await entity.length();
        } else if (entity is Directory) {
          await _calculateDirectorySize(entity, totalSize);
        }
      }
    } catch (e) {
      _talker.error('Error calculating directory size', e);
    }
  }

  /// Очищает старый кеш при превышении лимита
  Future<void> _cleanupOldCache() async {
    try {
      final currentSize = await getCacheSize();
      const maxSizeBytes = _maxCacheSizeMB * 1024 * 1024;

      if (currentSize > maxSizeBytes) {
        _talker.log(
            'Cache size ($currentSize bytes) exceeds limit ($maxSizeBytes bytes). Cleaning up...');

        // Получаем все файлы кеша с их метаданными
        final cacheDir = await getTemporaryDirectory();
        final cachePath = cacheDir.path;

        final files = <File>[];
        await _collectCacheFiles(Directory(cachePath), files);

        // Сортируем по времени последнего доступа (старые сначала)
        files.sort(
            (a, b) => a.lastAccessedSync().compareTo(b.lastAccessedSync()));

        // Удаляем старые файлы до достижения лимита
        int deletedSize = 0;
        for (final file in files) {
          if (currentSize - deletedSize <= maxSizeBytes) break;

          final fileSize = await file.length();
          await file.delete();
          deletedSize += fileSize;

          _talker.log('Deleted old cache file: ${file.path}');
        }

        _talker.log('Cache cleanup completed. Freed $deletedSize bytes');
      }
    } catch (e) {
      _talker.error('Failed to cleanup old cache', e);
    }
  }

  Future<void> _collectCacheFiles(Directory dir, List<File> files) async {
    try {
      final entities = dir.listSync();
      for (final entity in entities) {
        if (entity is File) {
          files.add(entity);
        } else if (entity is Directory) {
          await _collectCacheFiles(entity, files);
        }
      }
    } catch (e) {
      _talker.error('Error collecting cache files', e);
    }
  }

  /// Проверяет, есть ли кешированные данные
  Future<bool> hasCachedReceipts() async {
    try {
      final fileInfo = await _cacheManager.getFileFromCache(_receiptsCacheKey);
      if (fileInfo == null) return false;

      final file = fileInfo.file;
      if (!await file.exists()) return false;

      final content = await file.readAsString();
      final cacheData = json.decode(content) as Map<String, dynamic>;

      final expiresAt =
          DateTime.fromMillisecondsSinceEpoch(cacheData['expires_at']);
      return !DateTime.now().isAfter(expiresAt);
    } catch (e) {
      return false;
    }
  }

  /// Получает информацию о кеше
  Future<Map<String, dynamic>> getCacheInfo() async {
    try {
      final size = await getCacheSize();
      final hasReceipts = await hasCachedReceipts();

      return {
        'size_bytes': size,
        'size_mb': (size / (1024 * 1024)).toStringAsFixed(2),
        'max_size_mb': _maxCacheSizeMB,
        'has_cached_receipts': hasReceipts,
        'expiration_hours': _cacheExpiration.inHours,
      };
    } catch (e) {
      _talker.error('Failed to get cache info', e);
      return {};
    }
  }
}
