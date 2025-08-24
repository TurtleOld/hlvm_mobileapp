import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _serverController.text = prefs.getString('server_address') ?? '';
      });
    }
  }

  Future<void> _saveServerAddress() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _message = '';
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_address', _serverController.text.trim());

    if (mounted) {
      setState(() {
        _isLoading = false;
        _message = 'Сервер сохранён';
      });
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
                        const Text(
                          'Настройки сервера',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
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
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _serverController,
                      decoration: const InputDecoration(
                        labelText: 'Адрес сервера',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    if (_message.isNotEmpty)
                      Text(
                        _message,
                        style: const TextStyle(color: Colors.green),
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
