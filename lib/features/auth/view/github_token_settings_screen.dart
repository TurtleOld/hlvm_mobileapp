import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GithubTokenSettingsScreen extends StatefulWidget {
  const GithubTokenSettingsScreen({super.key});

  @override
  State<GithubTokenSettingsScreen> createState() =>
      _GithubTokenSettingsScreenState();
}

class _GithubTokenSettingsScreenState extends State<GithubTokenSettingsScreen> {
  final TextEditingController _tokenController = TextEditingController();
  bool _isLoading = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('github_token') ?? '';
    setState(() {
      _tokenController.text = token;
    });
  }

  Future<void> _saveToken() async {
    setState(() {
      _isLoading = true;
      _message = '';
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('github_token', _tokenController.text.trim());
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
