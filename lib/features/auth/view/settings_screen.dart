import 'package:flutter/material.dart';
import 'package:hlvm_mobileapp/core/services/server_settings_service.dart';
import 'cache_info_widget.dart';
import 'server_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _serverController = TextEditingController();
  bool _isLoading = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _loadServerAddress();
  }

  Future<void> _loadServerAddress() async {
    final serverSettings = ServerSettingsService();
    final address = await serverSettings.getServerAddress();
    if (mounted) {
      setState(() {
        _serverController.text = address ?? '';
      });
    }
  }

  Future<void> _saveServerAddress() async {
    if (!mounted) return;

    final address = _serverController.text.trim();

    // Валидация адреса
    if (address.isEmpty) {
      setState(() {
        _message = 'Введите адрес сервера';
      });
      return;
    }

    // Проверяем, что адрес не содержит протокол
    if (address.startsWith('http://') || address.startsWith('https://')) {
      setState(() {
        _message =
            'Не вводите протокол (http:// или https://). Введите только домен или IP адрес';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      final serverSettings = ServerSettingsService();
      await serverSettings.setServerAddress(address);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _message = 'Сервер сохранён';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _message = 'Ошибка: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Настройки сервера',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: TextButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ServerSettingsScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.settings),
                            label: const Text('Расширенные'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _serverController,
                      decoration: const InputDecoration(
                        labelText: 'Адрес сервера',
                        hintText: 'example.com или 192.168.1.100',
                        helperText:
                            'Введите только домен или IP адрес. API будет доступен по адресу: http://example.com/api',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    if (_message.isNotEmpty)
                      Text(
                        _message,
                        style: TextStyle(
                          color: _message.contains('Ошибка') ||
                                  _message.contains('Не вводите')
                              ? Colors.red
                              : Colors.green,
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveServerAddress,
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : const Text('Сохранить'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const CacheInfoWidget(),
          ],
        ),
      ),
    );
  }
}
