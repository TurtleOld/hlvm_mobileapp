import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hlvm_mobileapp/services/api.dart';

class ImageCaptureScreen extends StatefulWidget {
  const ImageCaptureScreen({super.key});

  @override
  State<ImageCaptureScreen> createState() => _ImageCaptureScreenState();
}

class _ImageCaptureScreenState extends State<ImageCaptureScreen> {
  final ApiService _apiService = ApiService();
  String _responseDataUrl = '';
  XFile? _imageFile;
  String? _dataUrl;
  Map<String, dynamic>? _jsonData;
  final ImagePicker _picker = ImagePicker();

  Future<void> _captureImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _imageFile = image;
        });

        final String dataUrl = await getImageDataUrl(image.path, 'jpeg');
        setState(() {
          _dataUrl = dataUrl;
        });

        final jsonData = await getJsonReceipt(dataUrl);
        setState(() {
          _jsonData = jsonData;
        });
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
        title: const Text('Image Capture and Process'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_imageFile == null)
              const Text('Нет изображений')
            else
              Image.file(
                File(_imageFile!.path),
                height: 200,
                width: 200,
                fit: BoxFit.cover,
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
    print(e.toString());
    rethrow;
  }
}

Future<Map<String, dynamic>> getJsonReceipt(dataUrl) async {
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
                "Распознай полный текст чека. Выдели оттуда продавца, адрес, номер чека, цену каждого товара, количество каждого товара, итоговую цену с учётом скидки если она есть, дату, НДС. Запиши это всё в Json формат, чтобы можно было сохранить результать в БД. seller - продавец, address - адрес, inn - ИНН, receipt_number - в чеке обозначайте как ФД если на изображении нет такого обозначения записать значение 0 в ином случае записать в значение в виде числа, date - дата, items - товары, discount - скидка, total_price - итоговая цена с учётом скидки, vat_20_sum - сумма НДС 20% , vat_10_sum - сумма НДС 10%, если на чеке есть слово ПРИХОД в operation_type ставить 1 тип int, если РАСХОД ставить в operation_type 2 тип int",
            "type": "text"
          },
          {
            "image_url": {"url": dataUrl, "detail": "high"},
            "type": "image_url"
          }
        ]
      }
    ],
    "model": "openai/gpt-4o",
    "max_tokens": 2048,
    "temperature": 0.7,
    "top_p": 0.5
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
    print('Error: $e');
    return {'Error': e};
  }
}
