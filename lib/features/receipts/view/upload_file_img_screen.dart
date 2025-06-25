import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hlvm_mobileapp/services/api.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hlvm_mobileapp/services/authentication.dart';
import 'package:hlvm_mobileapp/features/auth/view/authentication_screen.dart';
import 'package:hlvm_mobileapp/features/receipts/view/receipts_screen.dart';
import 'package:hlvm_mobileapp/main.dart';

class ImageCaptureScreen extends StatefulWidget {
  const ImageCaptureScreen({super.key});

  @override
  State<ImageCaptureScreen> createState() => _ImageCaptureScreenState();
}

class _ImageCaptureScreenState extends State<ImageCaptureScreen> {
  final ApiService _apiService = ApiService();
  final String _responseDataUrl = '';
  XFile? _imageFile;
  String? _dataUrl;
  Map<String, dynamic>? _jsonData;
  String? _stringJson;
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _captureImage(ImageSource source) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _imageFile = image;
        });

        final String dataUrl = await getImageDataUrl(image.path, 'jpg');
        setState(() {
          _dataUrl = dataUrl;
        });

        final Map<String, dynamic> jsonData = await getJsonReceipt(dataUrl);
        print('jsonData');
        print(jsonData);
        if (jsonData.containsKey('Error')) {
          final errorStr = jsonData['Error'].toString();
          if (errorStr.contains('401') || errorStr.contains('Unauthorized')) {
            await AuthService().logout(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Сессия истекла, войдите заново')),
            );
            await Future.delayed(const Duration(milliseconds: 500));
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            }
            setState(() {
              _isLoading = false;
            });
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: ${jsonData['Error']}')),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
        String prettyJson = JsonEncoder.withIndent('  ').convert(jsonData);
        setState(() {
          _jsonData = jsonData;
          _stringJson = prettyJson;
        });
        try {
          final createReceipt = await _apiService.createReceipt(jsonData);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(createReceipt)),
          );
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                  builder: (context) => const HomePage(selectedIndex: 1)),
              (route) => false,
            );
          }
        } catch (e) {
          String errorMsg = 'Ошибка при добавлении чека: $e';
          if (e is DioException) {
            if (e.response?.statusCode == 401) {
              await AuthService().logout(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Сессия истекла, войдите заново')),
              );
              await Future.delayed(const Duration(milliseconds: 500));
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              }
              setState(() {
                _isLoading = false;
              });
              return;
            }
            if (e.response?.statusCode == 400) {
              final data = e.response?.data;
              if (data is Map && data['detail'] != null) {
                errorMsg = data['detail'].toString();
              } else if (data != null) {
                errorMsg = data.toString();
              }
            }
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg)),
          );
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const ReceiptScreen()),
            );
          }
        }
      }
    } catch (e) {
      if (e is DioException) {
        final status = e.response?.statusCode;
        final serverMsg = e.response?.data?.toString() ?? '';
        if (status == 401) {
          await AuthService().logout(context);
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          }
          return;
        } else if (status == 400) {
          print('Ошибка 400, ответ сервера:');
          print(e.response?.data);
          String detailMsg = '';
          final data = e.response?.data;
          if (data is Map && data['detail'] != null) {
            detailMsg = data['detail'].toString();
          } else if (data != null) {
            detailMsg = data.toString();
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка запроса: $detailMsg')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $serverMsg')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Неизвестная ошибка: $e')),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Обработка фото чека'),
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_stringJson != null)
                    Expanded(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            _stringJson!,
                            style: const TextStyle(
                                fontSize: 14, color: Colors.black),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  if (_dataUrl != null)
                    Text(
                      _responseDataUrl,
                      style: const TextStyle(fontSize: 12, color: Colors.green),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 3,
                    ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => _captureImage(ImageSource.camera),
                    child: const Text('Сделать фото'),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () => _captureImage(ImageSource.gallery),
                    child: const Text('Выбрать из галереи'),
                  ),
                ],
              ),
      ),
    );
  }
}

// Функция для получения Data URL
Future<String> getImageDataUrl(String imagePath, String imageFormat) async {
  try {
    // Чтение файла изображения в виде байтов
    final File imageFile = File(imagePath);
    if (!await imageFile.exists()) {
      throw Exception("Could not read '$imagePath'.");
    }

    List<int> imageBytes = await imageFile.readAsBytes();

    // Кодирование байтов в Base64
    String base64Image = base64Encode(imageBytes);

    // Формирование строки Data URL
    return "data:image/$imageFormat;base64,$base64Image";
  } catch (e) {
    rethrow;
  }
}

Future<String?> getGithubToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('github_token');
}

Future<Map<String, dynamic>> getJsonReceipt(dataUrl) async {
  final storage = const FlutterSecureStorage();
  final accessToken = await storage.read(key: 'access_token');
  final prefs = await SharedPreferences.getInstance();
  final selectedAccount = prefs.getInt('selectedAccountId');
  final Map<String, dynamic> decodedToken = JwtDecoder.decode(accessToken!);
  final int userId = decodedToken['user_id'];
  final dio = Dio();
  final payload = {
    "messages": [
      {
        "role": "system",
        "content":
            "You are a helpful assistant tasked with providing detailed and accurate descriptions of images. Ensure your responses are thorough, specific, and capture key visual elements, including objects, actions, settings, and any notable details. Avoid assumptions about elements not visible in the image."
      },
      {
        "role": "user",
        "content": [
          {
            "text":
                "Распознай текст чека и только создай JSON где значения должны быть число - тип int или float, слова - тип строка $userId и $selectedAccount - type int: {'seller': {'name_seller': 'имя продавца', 'retail_place_address': 'адрес', 'user': $userId}, 'number_receipt': 'ФД или 0' type int, 'receipt_date': записать в формате ISO 8601 YYYY-MM-DDTHH:MM:SS на чеках может быть в форматах DD.MM.YYYY HH:MM, 'total_sum': итоговая сумма, 'nds20': сумма НДС 20%, 'nds10': сумма НДС 10%, 'operation_type': 1 для ПРИХОД, 2 для РАСХОД, 'product': [{'product_name': 'товар', 'quantity': 'количество', 'amount': 'цена', 'price': 'стоимость за единицу', 'nds_type': 1 если НДС 20%, 2 если НДС 10% type int, 'nds_sum': рассчитанная сумма НДС - type int}], 'user': $userId - type int, 'finance_account': $selectedAccount - type int}. Если данных нет, используй 0 для int или '' для string.",
            "type": "text"
          },
          {
            "image_url": {"url": dataUrl, "detail": "high"},
            "type": "image_url"
          }
        ]
      }
    ],
    "model": "openai/gpt-4.1",
    "max_tokens": 2048,
    "temperature": 1,
    "top_p": 1
  };
  final githubToken = await getGithubToken();
  try {
    final response = await dio.post(
      'https://models.github.ai/inference/chat/completions',
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $githubToken',
        },
      ),
      data: payload,
    );
    String rawResponse = response.data['choices'][0]['message']['content'];
    String cleanedResponse =
        rawResponse.replaceAll('```json', '').replaceAll('```', '').trim();
    return jsonDecode(cleanedResponse);
  } catch (e) {
    if (e is DioException) {
      return {'Error': e.response?.data?.toString() ?? e.toString()};
    }
    return {'Error': e.toString()};
  }
}
