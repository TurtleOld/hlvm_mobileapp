import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    final server = prefs.getString('server_address') ?? '';
    setState(() {
      _serverController.text = server;
    });
  }

  Future<void> _saveServerAddress() async {
    setState(() {
      _isLoading = true;
      _message = '';
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_address', _serverController.text.trim());
    setState(() {
      _isLoading = false;
      _message = 'Сервер сохранён';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
            ElevatedButton(
              onPressed: _isLoading ? null : _saveServerAddress,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }
} 