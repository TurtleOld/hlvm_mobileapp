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
import 'package:hlvm_mobileapp/features/auth/view/settings_screen.dart';
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
  String? _dataUrl;
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _captureImage(ImageSource source) async {
    setState(() {
      _isLoading = true;
    });

    // Сохраняем контекст до async операций
    final currentContext = context;

    // Проверяем аутентификацию перед началом обработки
    final storage = const FlutterSecureStorage();
    final accessToken = await storage.read(key: 'access_token');
    if (accessToken == null) {
      if (mounted) {
        await AuthService().logout(currentContext);
        ScaffoldMessenger.of(currentContext).showSnackBar(
          const SnackBar(content: Text('Сессия истекла, войдите заново')),
        );
        await Future.delayed(const Duration(milliseconds: 500));
        Navigator.of(currentContext).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final selectedAccount = prefs.getInt('selectedAccountId');
    if (selectedAccount == null) {
      if (mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          const SnackBar(content: Text('Сначала выберите финансовый аккаунт')),
        );
      }
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Проверяем наличие GitHub токена
    final githubToken = await getGithubToken();
    if (githubToken == null || githubToken.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(
            content: const Text(
                'GitHub API токен не настроен. Перейдите в настройки и добавьте токен GitHub.'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Настройки',
              onPressed: () {
                Navigator.of(currentContext).push(
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (!mounted) return;
      if (image != null) {
        final String dataUrl = await getImageDataUrl(image.path, 'jpg');
        if (!mounted) return;

        setState(() {
          _dataUrl = dataUrl;
        });

        final Map<String, dynamic> jsonData = await getJsonReceipt(dataUrl);
        if (!mounted) return;
        if (jsonData.containsKey('Error')) {
          final errorStr = jsonData['Error'].toString();

          // Проверяем, является ли это ошибкой аутентификации к нашему серверу
          if (errorStr.contains('401') &&
              (errorStr.contains('Access token not found') ||
                  errorStr.contains('Unauthorized'))) {
            if (mounted) {
              await AuthService().logout(currentContext);
              ScaffoldMessenger.of(currentContext).showSnackBar(
                const SnackBar(content: Text('Сессия истекла, войдите заново')),
              );
              await Future.delayed(const Duration(milliseconds: 500));
              Navigator.of(currentContext).pushReplacement(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            }
            setState(() {
              _isLoading = false;
            });
            return;
          }

          // Для ошибок GitHub API показываем сообщение без выхода из аккаунта
          if (errorStr.contains('GitHub API')) {
            if (mounted) {
              ScaffoldMessenger.of(currentContext).showSnackBar(
                SnackBar(
                  content: Text(errorStr),
                  duration: const Duration(seconds: 5),
                  action: SnackBarAction(
                    label: 'Настройки',
                    onPressed: () {
                      Navigator.of(currentContext).push(
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                ),
              );
            }
            setState(() {
              _isLoading = false;
            });
            return;
          }
          if (mounted) {
            ScaffoldMessenger.of(currentContext).showSnackBar(
              SnackBar(content: Text('Ошибка: ${jsonData['Error']}')),
            );
          }
          setState(() {
            _isLoading = false;
          });
          return;
        }

        try {
          final createReceipt = await _apiService.createReceipt(jsonData);
          if (mounted) {
            ScaffoldMessenger.of(currentContext).showSnackBar(
              SnackBar(content: Text(createReceipt)),
            );
            await Future.delayed(const Duration(milliseconds: 500));
            Navigator.of(currentContext).pushAndRemoveUntil(
              MaterialPageRoute(
                  builder: (context) => const HomePage(selectedIndex: 1)),
              (route) => false,
            );
          }
        } catch (e) {
          String errorMsg = 'Ошибка при добавлении чека: $e';
          if (e is DioException) {
            if (e.response?.statusCode == 401) {
              if (mounted) {
                await AuthService().logout(currentContext);
                ScaffoldMessenger.of(currentContext).showSnackBar(
                  const SnackBar(
                      content: Text('Сессия истекла, войдите заново')),
                );
                await Future.delayed(const Duration(milliseconds: 500));
                Navigator.of(currentContext).pushReplacement(
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
          if (mounted) {
            ScaffoldMessenger.of(currentContext).showSnackBar(
              SnackBar(content: Text(errorMsg)),
            );
            await Future.delayed(const Duration(milliseconds: 500));
            Navigator.of(currentContext).pushReplacement(
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
          if (mounted) {
            await AuthService().logout(currentContext);
            Navigator.of(currentContext).pushReplacement(
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
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ошибка запроса: $detailMsg')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ошибка: $serverMsg')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Неизвестная ошибка: $e')),
          );
        }
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

  if (accessToken == null) {
    return {'Error': '401 Unauthorized - Access token not found'};
  }

  final Map<String, dynamic> decodedToken = JwtDecoder.decode(accessToken);
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

  // Проверяем наличие GitHub токена
  if (githubToken == null || githubToken.isEmpty) {
    return {
      'Error':
          'GitHub API токен не настроен. Перейдите в настройки и добавьте токен GitHub.'
    };
  }

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
        if (selectedAccount != null) {
          result['account'] = selectedAccount;
        } else {
          return {
            'Error': 'Account not selected. Please select an account first.'
          };
        }
      }
      if (!result.containsKey('user') || result['user'] == null) {
        result['user'] = userId;
      }
    }
    return result;
  } catch (e) {
    if (e is DioException) {
      final statusCode = e.response?.statusCode;
      final responseData = e.response?.data;

      // Обработка ошибок GitHub API
      if (statusCode == 401) {
        return {
          'Error':
              'GitHub API токен недействителен или просрочен. Обновите токен в настройках.'
        };
      } else if (statusCode == 403) {
        return {
          'Error':
              'Доступ к GitHub API запрещен. Проверьте права доступа токена.'
        };
      } else if (statusCode == 429) {
        return {
          'Error': 'Превышен лимит запросов к GitHub API. Попробуйте позже.'
        };
      } else if (statusCode == 500 || statusCode == 502 || statusCode == 503) {
        return {'Error': 'Ошибка сервера GitHub API. Попробуйте позже.'};
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return {
          'Error':
              'Таймаут подключения к GitHub API. Проверьте интернет-соединение.'
        };
      } else if (e.type == DioExceptionType.connectionError) {
        return {
          'Error':
              'Ошибка подключения к GitHub API. Проверьте интернет-соединение.'
        };
      }

      // Если есть данные ответа, пытаемся извлечь сообщение об ошибке
      if (responseData != null) {
        if (responseData is Map) {
          final errorMessage = responseData['error']?['message'] ??
              responseData['message'] ??
              responseData.toString();
          return {'Error': 'Ошибка GitHub API: $errorMessage'};
        } else {
          return {'Error': 'Ошибка GitHub API: ${responseData.toString()}'};
        }
      }

      return {'Error': 'Ошибка GitHub API: ${e.message ?? e.toString()}'};
    }
    return {'Error': 'Неожиданная ошибка: ${e.toString()}'};
  }
}
