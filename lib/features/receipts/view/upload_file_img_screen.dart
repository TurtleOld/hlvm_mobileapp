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

        setState(() {
          _jsonData = jsonData;
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

// Функция для преобразования даты в ISO 8601
String? convertToIsoDate(String? dateStr) {
  if (dateStr == null) return null;
  try {
    // Пробуем распарсить "12.06.2023 18:28"
    final parts = dateStr.split(' ');
    if (parts.length == 2) {
      final dateParts = parts[0].split('.');
      final timeParts = parts[1].split(':');
      if (dateParts.length == 3 && timeParts.length >= 2) {
        final year = int.parse(dateParts[2]);
        final month = int.parse(dateParts[1]);
        final day = int.parse(dateParts[0]);
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        final second = timeParts.length > 2 ? int.parse(timeParts[2]) : 0;
        final dt = DateTime(year, month, day, hour, minute, second);
        return dt.toIso8601String();
      }
    }
    // Если уже ISO, возвращаем как есть
    DateTime.parse(dateStr);
    return dateStr;
  } catch (_) {
    return dateStr; // если не получилось, возвращаем как есть
  }
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
            "Вы — помощник, который извлекает структурированные данные из кассовых чеков по фотографии. Ваша задача — вернуть только корректный JSON без какого-либо дополнительного текста, комментариев или форматирования вне JSON. Не добавляйте пояснений, не используйте markdown. Если какое-либо поле отсутствует на чеке, используйте null для строк, 0 для чисел или пустой массив для списков. Все суммы указывайте в рублях, без знака валюты, с точкой как разделителем. Не придумывайте данные, если их нет на чеке. Поле receipt_date возвращайте строго в формате ISO 8601 (YYYY-MM-DDTHH:MM:SS)."
      },
      {
        "role": "user",
        "content": [
          {
            "type": "text",
            "text":
                "На изображении кассовый чек. Преобразуйте его в JSON со следующими ключами:\n- name_seller: строка, имя продавца, если указано\n- retail_place_address: строка, адрес расчетов, если указан\n- retail_place: строка, место расчетов, если указано\n- total_sum: число, итоговая сумма в чеке\n- operation_type: число, 1 для 'Приход', 2 для 'Расход'\n- receipt_date: строка, дата и время в формате ISO 8601 (YYYY-MM-DDTHH:MM:SS)\n- number_receipt: число, номер ФД из чека\n- nds10: число, сумма НДС 10%, если указано, иначе 0\n- nds20: число, сумма НДС 20%, если указано, иначе 0\n- items: массив товаров, каждый товар — отдельный объект со следующими полями:\n  - product_name: строка, название товара\n  - category: строка, категория товара (определяется по названию, если возможно)\n  - price: число, цена за единицу товара\n  - quantity: число, количество товара\n  - amount: число, общая сумма за товар (цена × количество)\nНе объединяйте товары, даже если они полностью совпадают. Каждый товар на чеке — отдельный элемент массива items. Не пропускайте товары с нулевой ценой или количеством. Если данные отсутствуют, используйте null или 0."
          },
          {
            "type": "text",
            "text":
                "Пример чека:\n1. Хлеб пшеничный 25.00 руб x 2 = 50.00\n2. Хлеб пшеничный 25.00 руб x 1 = 25.00\n3. Молоко 3% 45.00 руб x 1 = 45.00\n\nОжидаемый JSON:\n{\n  \"items\": [\n    {\"product_name\": \"Хлеб пшеничный\", \"category\": \"Хлебобулочные изделия\", \"price\": 25.00, \"quantity\": 2, \"amount\": 50.00},\n    {\"product_name\": \"Хлеб пшеничный\", \"category\": \"Хлебобулочные изделия\", \"price\": 25.00, \"quantity\": 1, \"amount\": 25.00},\n    {\"product_name\": \"Молоко 3%\", \"category\": null, \"price\": 45.00, \"quantity\": 1, \"amount\": 45.00}\n  ]\n}\nКаждая строка товара должна быть отдельным объектом в массиве items, даже если названия совпадают."
          },
          {
            "type": "image_url",
            "image_url": {"url": dataUrl, "detail": "high"}
          }
        ]
      }
    ],
    "model": "openai/gpt-4.1",
    "max_tokens": 2048,
    "temperature": 0.6,
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
    final result = jsonDecode(cleanedResponse);
    // Автоматически преобразуем дату в ISO 8601, если нужно
    if (result is Map<String, dynamic> && result.containsKey('receipt_date')) {
      result['receipt_date'] =
          convertToIsoDate(result['receipt_date']?.toString());
    }
    if (result is Map<String, dynamic>) {
      if (!result.containsKey('account') || result['account'] == null) {
        result['account'] = selectedAccount;
      }
      if (!result.containsKey('user') || result['user'] == null) {
        result['user'] = userId;
      }
    }
    return result;
  } catch (e) {
    if (e is DioException) {
      return {'Error': e.response?.data?.toString() ?? e.toString()};
    }
    return {'Error': e.toString()};
  }
}
