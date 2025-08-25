import 'package:flutter/material.dart';
import '../../../core/services/security_manager_service.dart';
import '../../../core/widgets/loading_widget.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final SecurityManagerService _securityManager = SecurityManagerService();

  bool _isLoading = false;
  bool _isSecurityActive = false;
  bool _isAppBlocked = false;
  Map<String, bool> _securityTestResults = {};

  @override
  void initState() {
    super.initState();
    _loadSecurityStatus();
  }

  Future<void> _loadSecurityStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _isSecurityActive = _securityManager.isSecurityActive;
      _isAppBlocked = _securityManager.isAppBlocked;
    } catch (e) {
      // Обработка ошибок
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _runSecurityTest() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await _securityManager.runSecurityTest();
      setState(() {
        _securityTestResults = results;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Тест безопасности завершен'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при выполнении теста: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleSecurity() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_isSecurityActive) {
        _securityManager.clearSecurityData();
      } else {
        await _securityManager.initializeSecurity();
      }

      await _loadSecurityStatus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isSecurityActive
                ? 'Система безопасности отключена'
                : 'Система безопасности активирована'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _unblockApp() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _securityManager.unblockApplication();
      await _loadSecurityStatus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Приложение разблокировано'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при разблокировке: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _restartSecurity() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _securityManager.restartSecurity();
      await _loadSecurityStatus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Система безопасности перезапущена'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при перезапуске: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: LoadingWidget(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки безопасности'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSecurityStatusCard(),
            const SizedBox(height: 16),
            _buildSecurityControlsCard(),
            const SizedBox(height: 16),
            _buildSecurityTestCard(),
            const SizedBox(height: 16),
            _buildProtectionDetailsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityStatusCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isSecurityActive ? Icons.security : Icons.security_outlined,
                  color: _isSecurityActive ? Colors.green : Colors.red,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Статус безопасности',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        _isSecurityActive
                            ? 'Система безопасности активна'
                            : 'Система безопасности неактивна',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color:
                                  _isSecurityActive ? Colors.green : Colors.red,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_isAppBlocked) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.block, color: Colors.red.shade600),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Приложение заблокировано из-за нарушения безопасности',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityControlsCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Управление безопасностью',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isAppBlocked ? null : _toggleSecurity,
                    icon:
                        Icon(_isSecurityActive ? Icons.stop : Icons.play_arrow),
                    label:
                        Text(_isSecurityActive ? 'Отключить' : 'Активировать'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isSecurityActive ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isAppBlocked ? _unblockApp : null,
                    icon: const Icon(Icons.lock_open),
                    label: const Text('Разблокировать'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _restartSecurity,
                icon: const Icon(Icons.refresh),
                label: const Text('Перезапустить систему безопасности'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityTestCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Тест безопасности',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _runSecurityTest,
                icon: const Icon(Icons.security),
                label: const Text('Запустить тест безопасности'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            if (_securityTestResults.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Результаты теста:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...(_securityTestResults.entries.map((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          entry.value ? Icons.check_circle : Icons.error,
                          color: entry.value ? Colors.green : Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _getTestName(entry.key),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        Text(
                          entry.value ? 'Пройден' : 'Не пройден',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: entry.value ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                  ))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProtectionDetailsCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Детали защиты',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            // Все защиты отключены
          ],
        ),
      ),
    );
  }


  String _getTestName(String key) {
    switch (key) {
      default:
        return key;
    }
  }
}
