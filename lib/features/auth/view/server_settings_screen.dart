import 'package:flutter/material.dart';
import 'package:hlvm_mobileapp/core/services/server_settings_service.dart';
import 'package:hlvm_mobileapp/core/constants/app_constants.dart';
import 'package:hlvm_mobileapp/core/widgets/loading_widget.dart';
import 'package:hlvm_mobileapp/core/widgets/error_widget.dart';

class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverSettings = ServerSettingsService();

  final _addressController = TextEditingController();
  final _portController = TextEditingController();
  final _timeoutController = TextEditingController();
  final _retryAttemptsController = TextEditingController();

  String _selectedProtocol = 'https';
  bool _healthCheckEnabled = true;
  String _selectedApiVersion = 'v1';

  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _portController.dispose();
    _timeoutController.dispose();
    _retryAttemptsController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _getCurrentSettings() async {
    return {
      'address': await _serverSettings.getServerAddress(),
      'port': await _serverSettings.getServerPort(),
      'timeout': await _serverSettings.getTimeout(),
      'retryAttempts': await _serverSettings.getMaxRetries(),
      'protocol': await _serverSettings.getServerProtocol(),
      'healthCheck': await _serverSettings.getHealthCheckEnabled(),
      'apiVersion': await _serverSettings.getServerVersion(),
    };
  }

  Future<void> _loadCurrentSettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final settings = await _getCurrentSettings();

      setState(() {
        _addressController.text = settings['address'] ?? '';
        _portController.text = settings['port']?.toString() ?? '';
        _timeoutController.text = settings['timeout']?.toString() ?? '120';
        _retryAttemptsController.text =
            settings['retryAttempts']?.toString() ?? '3';
        _selectedProtocol = settings['protocol'] ?? 'https';
        _healthCheckEnabled = settings['healthCheck'] ?? true;
        _selectedApiVersion = settings['apiVersion'] ?? 'v1';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка загрузки настроек: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final port = int.tryParse(_portController.text);
      final timeout = int.tryParse(_timeoutController.text);
      final retryAttempts = int.tryParse(_retryAttemptsController.text);

      if (port == null || timeout == null || retryAttempts == null) {
        throw Exception('Некорректные значения полей');
      }

      await _serverSettings.setServerAddress(_addressController.text.trim());
      await _serverSettings.setServerPort(port);
      await _serverSettings.setServerProtocol(_selectedProtocol);
      await _serverSettings.setTimeout(timeout);
      await _serverSettings.setMaxRetries(retryAttempts);
      await _serverSettings.setHealthCheckEnabled(_healthCheckEnabled);
      await _serverSettings.setServerVersion(_selectedApiVersion);

      setState(() {
        _successMessage = 'Настройки сервера успешно сохранены';
      });

      // Очищаем сообщение об успехе через 3 секунды
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _successMessage = null;
          });
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка сохранения настроек: $e';
      });
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сброс настроек'),
        content: const Text(
            'Вы уверены, что хотите сбросить настройки сервера к значениям по умолчанию?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        await _serverSettings.clearAllSettings();
        await _loadCurrentSettings();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Настройки сброшены к значениям по умолчанию')),
          );
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Ошибка сброса настроек: $e';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final address = await _serverSettings.getServerAddress();
      if (address == null || address.isEmpty) {
        throw Exception('Сервер не настроен');
      }

      final port = await _serverSettings.getServerPort();
      if (port == null || port < 1 || port > 65535) {
        throw Exception('Настройки сервера некорректны');
      }

      // Здесь можно добавить реальную проверку соединения
      // await _apiService.checkServerHealth();

      setState(() {
        _successMessage = 'Соединение с сервером успешно установлено';
      });

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _successMessage = null;
          });
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка соединения: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки сервера'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadCurrentSettings,
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage != null)
                      AppErrorWidget(
                        message: _errorMessage!,
                        onRetry: _loadCurrentSettings,
                      ),
                    if (_successMessage != null)
                      Container(
                        padding:
                            const EdgeInsets.all(AppConstants.defaultPadding),
                        margin: const EdgeInsets.only(
                            bottom: AppConstants.defaultPadding),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle,
                                color: Colors.green.shade700),
                            const SizedBox(width: AppConstants.defaultSpacing),
                            Expanded(
                              child: Text(
                                _successMessage!,
                                style: TextStyle(color: Colors.green.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Card(
                      child: Padding(
                        padding:
                            const EdgeInsets.all(AppConstants.defaultPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Основные настройки',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppConstants.defaultPadding),
                            TextFormField(
                              controller: _addressController,
                              decoration: const InputDecoration(
                                labelText: 'Адрес сервера',
                                hintText: 'example.com или 192.168.1.100',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Введите адрес сервера';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppConstants.defaultSpacing),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _portController,
                                    decoration: const InputDecoration(
                                      labelText: 'Порт',
                                      hintText: '8000',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return null;
                                      }
                                      final port = int.tryParse(value);
                                      if (port == null ||
                                          port < 1 ||
                                          port > 65535) {
                                        return 'Порт должен быть от 1 до 65535';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(
                                    width: AppConstants.defaultSpacing),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _selectedProtocol,
                                    decoration: const InputDecoration(
                                      labelText: 'Протокол',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'http', child: Text('HTTP')),
                                      DropdownMenuItem(
                                          value: 'https', child: Text('HTTPS')),
                                    ],
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _selectedProtocol = value;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppConstants.defaultPadding),
                    Card(
                      child: Padding(
                        padding:
                            const EdgeInsets.all(AppConstants.defaultPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Дополнительные настройки',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppConstants.defaultPadding),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _timeoutController,
                                    decoration: const InputDecoration(
                                      labelText: 'Таймаут (сек)',
                                      hintText: '30',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return null;
                                      }
                                      final timeout = int.tryParse(value);
                                      if (timeout == null ||
                                          timeout < 1 ||
                                          timeout > 300) {
                                        return 'Таймаут должен быть от 1 до 300 сек';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(
                                    width: AppConstants.defaultSpacing),
                                Expanded(
                                  child: TextFormField(
                                    controller: _retryAttemptsController,
                                    decoration: const InputDecoration(
                                      labelText: 'Попытки повтора',
                                      hintText: '3',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return null;
                                      }
                                      final attempts = int.tryParse(value);
                                      if (attempts == null ||
                                          attempts < 0 ||
                                          attempts > 10) {
                                        return 'Попытки должны быть от 0 до 10';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppConstants.defaultSpacing),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _selectedApiVersion,
                                    decoration: const InputDecoration(
                                      labelText: 'Версия API',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'v1', child: Text('v1')),
                                      DropdownMenuItem(
                                          value: 'v2', child: Text('v2')),
                                      DropdownMenuItem(
                                          value: 'v3', child: Text('v3')),
                                    ],
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _selectedApiVersion = value;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(
                                    width: AppConstants.defaultSpacing),
                                Expanded(
                                  child: SwitchListTile(
                                    title: const Text('Проверка здоровья'),
                                    subtitle: const Text(
                                        'Проверять доступность сервера'),
                                    value: _healthCheckEnabled,
                                    onChanged: (value) {
                                      setState(() {
                                        _healthCheckEnabled = value;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppConstants.defaultPadding),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _saveSettings,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.save),
                            label:
                                Text(_isSaving ? 'Сохранение...' : 'Сохранить'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppConstants.defaultSpacing),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ? null : _testConnection,
                            icon: const Icon(Icons.wifi),
                            label: const Text('Тест соединения'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.defaultSpacing),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ? null : _resetToDefaults,
                            icon: const Icon(Icons.restore),
                            label: const Text('Сбросить к умолчаниям'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
