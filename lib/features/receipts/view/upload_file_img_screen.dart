import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hlvm_mobileapp/services/api.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  final ImagePicker _picker = ImagePicker();

  Future<void> _captureImage(ImageSource source) async {
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
        String prettyJson = JsonEncoder.withIndent('  ').convert(jsonData);
        setState(() {
          _jsonData = jsonData;
          _stringJson = prettyJson;
        });
        final createReceipt = await _apiService.createReceipt(jsonData);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(createReceipt)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Обработка фото чека'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_stringJson != null)
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _stringJson!,
                      style: const TextStyle(fontSize: 14, color: Colors.black),
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

Future<Map<String, dynamic>> getJsonReceipt(dataUrl) async {
  final prefs = await SharedPreferences.getInstance();
  final accessToken = prefs.getString('access_token');
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
  final githubToken = dotenv.env['GITHUB_TOKEN'];
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
    return {'Error': e};
  }
}
