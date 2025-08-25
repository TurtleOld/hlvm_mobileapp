import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hlvm_mobileapp/features/receipts/view/view.dart';
import 'package:hlvm_mobileapp/services/api.dart';
import 'package:hlvm_mobileapp/features/auth/view/settings_screen.dart';
import 'package:hlvm_mobileapp/main.dart';

class FileReaderScreen extends StatefulWidget {
  const FileReaderScreen({super.key});

  @override
  State<FileReaderScreen> createState() => _FileReaderScreenState();
}

class _FileReaderScreenState extends State<FileReaderScreen> {
  final ApiService _apiService = ApiService();

  Future<void> _pickAndReadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      //allowedExtensions: ['json'],
    );
    if (!mounted) return;
    if (result != null) {
      final file = result.files.first;
      final filePath = file.path;
      if (filePath == null) {
        throw Exception('Не удалось получить доступ к файлу');
      }

      Future<String> readFileContent(String filePath) async {
        final file = File(filePath);
        return await file.readAsString();
      }

      final fileContent = await readFileContent(filePath);
      if (!mounted) return;

      final decodedJson = jsonDecode(fileContent);
      final content = decodedJson is List ? decodedJson[0] : decodedJson;
      final prepareData = PrepareData();

      final data = await prepareData.prepareData(content);
      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Подтверждение'),
            content: const Text('Вы уверены, что хотите добавить этот чек?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(false); // User canceled
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(true); // User confirmed
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      if (confirmed == true) {
        try {
          final result = await _apiService.createReceipt(data);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result)),
            );
            await Future.delayed(const Duration(milliseconds: 500));
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                  builder: (context) => const HomePage(selectedIndex: 1)),
              (route) => false,
            );
          }
        } catch (e) {
          final errorMsg = e.toString();
          if (errorMsg.contains('Необходимо указать адрес сервера')) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    const Text('Необходимо указать адрес сервера в настройках'),
                action: SnackBarAction(
                  label: 'Настроить',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (context) => const SettingsScreen()),
                    );
                  },
                ),
              ),
            );
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Ошибка: $e')),
              );
            }
          }
        }
      } else {
        throw Exception("Выбор файла отменен");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Загрузка файлов',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ElevatedButton(
                onPressed: _pickAndReadFile, child: const Text('Выбрать файл')),
          ],
        ),
      ),
    );
  }
}
