import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hlvm_mobileapp/features/receipts/view/view.dart';
import 'package:hlvm_mobileapp/services/authentication.dart';
import 'package:pretty_json/pretty_json.dart';

class FileReaderScreen extends StatefulWidget {
  const FileReaderScreen({super.key});

  @override
  State<FileReaderScreen> createState() => _FileReaderScreenState();
}

class _FileReaderScreenState extends State<FileReaderScreen> {
  dynamic _jsonData;
  String? _errorMessage;
  final Dio _dio = Dio();
  final String _baseUrl = 'https://hlvm.pavlovteam.ru/api';
  final AuthService _authService = AuthService();
  late String accessToken;

  Future<void> _pickAndReadFile() async {
    final accessToken = await _authService.getAccessToken();
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
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

      final decodedJson = jsonDecode(fileContent);
      final content = decodedJson is List ? decodedJson[0] : decodedJson;
      final prepareData = PrepareData();

      final data = await prepareData.prepareData(content);
      print(jsonEncode(data));
      print(accessToken);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Подтверждение'),
            content: Text('Вы уверены, что хотите добавить этот чек?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(false); // User canceled
                },
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(true); // User confirmed
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
      if (confirmed == true) {
        final response = await _dio.post('$_baseUrl/receipts/create-receipt/',
            data: jsonEncode(data),
            options:
                Options(headers: {'Authorization': 'Bearer $accessToken'}));

        setState(() async {
          _jsonData = content;
          await prepareData.prepareData(content);
          _errorMessage = null;
        });
      } else {
        throw Exception("Выбор файла отменен");
      }
    }
  }

  Widget _buildContent() {
    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    if (_jsonData == null) {
      return const Center(
        child: Text("Нажмите кнопку, чтобы выбрать JSON-файл"),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        JsonEncoder.withIndent('  ').convert(_jsonData),
        style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
      ),
    );
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
            const SizedBox(height: 16),
            Expanded(
              child: _buildContent(),
            )
          ],
        ),
      ),
    );
  }
}

@override
Widget build(BuildContext context) {
  // TODO: implement build
  throw UnimplementedError();
}
