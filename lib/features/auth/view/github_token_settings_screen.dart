import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class GithubTokenSettingsScreen extends StatefulWidget {
  const GithubTokenSettingsScreen({super.key});

  @override
  State<GithubTokenSettingsScreen> createState() =>
      _GithubTokenSettingsScreenState();
}

class _GithubTokenSettingsScreenState extends State<GithubTokenSettingsScreen> {
  final TextEditingController _tokenController = TextEditingController();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool _isLoading = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final token = await _secureStorage.read(key: 'github_token') ?? '';
    print('DEBUG: Loading GitHub token');
    print('DEBUG: Token loaded: ${token.isNotEmpty}');
    print(
        'DEBUG: Token starts with: ${token.isNotEmpty ? token.substring(0, 10) : 'empty'}...');
    
    setState(() {
      _tokenController.text = token;
    });
  }

  Future<void> _saveToken() async {
    setState(() {
      _isLoading = true;
      _message = '';
    });
    
    final token = _tokenController.text.trim();
    print('DEBUG: Saving GitHub token');
    print('DEBUG: Token length: ${token.length}');
    print(
        'DEBUG: Token starts with: ${token.isNotEmpty ? token.substring(0, 10) : 'empty'}...');

    await _secureStorage.write(key: 'github_token', value: token);

    // Проверяем, что токен сохранился
    final savedToken = await _secureStorage.read(key: 'github_token');
    print('DEBUG: Token saved successfully: ${savedToken != null}');
    
    setState(() {
      _isLoading = false;
      _message = 'Github Token сохранён';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Github Token'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(
                labelText: 'Github Token',
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
              onPressed: _isLoading ? null : _saveToken,
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
