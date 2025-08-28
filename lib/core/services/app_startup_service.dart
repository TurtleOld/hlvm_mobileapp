import 'package:talker/talker.dart';
import 'cache_service.dart';

class AppStartupService {
  final CacheService _cacheService;
  final Talker _talker = Talker();

  AppStartupService({required CacheService cacheService})
      : _cacheService = cacheService;

  Future<void> initializeApp() async {
    try {
      _talker.log('Starting app initialization...');

      await _initializeCache();

      _talker.log('App initialization completed successfully');
    } catch (e) {
      _talker.error('Failed to initialize app', e);
    }
  }

  Future<void> _initializeCache() async {
    try {
      _talker.log('Initializing cache...');

      final cacheInfo = await _cacheService.getCacheInfo();
      _talker.log(
          'Cache info: ${cacheInfo['size_mb']} MB used, max: ${cacheInfo['max_size_mb']} MB');

      final hasCachedReceipts = await _cacheService.hasCachedReceipts();
      if (hasCachedReceipts) {
        _talker.log('Found cached receipts data');
      } else {
        _talker.log('No cached receipts data found');
      }

      _talker.log('Cache initialization completed');
    } catch (e) {
      _talker.error('Failed to initialize cache', e);
    }
  }

  Future<void> clearAllCache() async {
    try {
      _talker.log('Clearing all cache...');
      await _cacheService.clearAllCache();
      _talker.log('All cache cleared successfully');
    } catch (e) {
      _talker.error('Failed to clear cache', e);
    }
  }

  Future<Map<String, dynamic>> getCacheInfo() async {
    try {
      return await _cacheService.getCacheInfo();
    } catch (e) {
      _talker.error('Failed to get cache info', e);
      return {};
    }
  }
}
