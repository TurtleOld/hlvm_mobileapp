import 'package:flutter/material.dart';
import 'package:hlvm_mobileapp/core/services/cache_service.dart';
import 'package:hlvm_mobileapp/core/theme/app_theme.dart';

class CacheInfoWidget extends StatefulWidget {
  const CacheInfoWidget({super.key});

  @override
  State<CacheInfoWidget> createState() => _CacheInfoWidgetState();
}

class _CacheInfoWidgetState extends State<CacheInfoWidget> {
  final CacheService _cacheService = CacheService();
  Map<String, dynamic> _cacheInfo = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCacheInfo();
  }

  Future<void> _loadCacheInfo() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final info = await _cacheService.getCacheInfo();
      if (mounted) {
        setState(() {
          _cacheInfo = info;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _clearCache() async {
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить кеш'),
        content: const Text(
            'Вы уверены, что хотите очистить весь кеш? Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorRed,
            ),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _cacheService.clearAllCache();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Кеш успешно очищен'),
              backgroundColor: AppTheme.primaryGreen,
            ),
          );
          _loadCacheInfo();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка при очистке кеша: $e'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.storage,
                  color: AppTheme.primaryGreen,
                  size: 24,
                ),
                SizedBox(width: 12),
                Text(
                  'Информация о кеше',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              )
            else
              Column(
                children: [
                  _buildInfoRow(
                      'Размер кеша:', '${_cacheInfo['size_mb'] ?? '0.00'} MB'),
                  _buildInfoRow('Максимальный размер:',
                      '${_cacheInfo['max_size_mb'] ?? '500'} MB'),
                  _buildInfoRow('Время жизни:',
                      '${_cacheInfo['expiration_hours'] ?? '24'} часов'),
                  _buildInfoRow('Кешированные чеки:',
                      _cacheInfo['has_cached_receipts'] == true ? 'Да' : 'Нет'),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _clearCache,
                      icon: const Icon(Icons.delete_sweep),
                      label: const Text('Очистить кеш'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _loadCacheInfo,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Обновить'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryGreen,
                        side: const BorderSide(color: AppTheme.primaryGreen),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
