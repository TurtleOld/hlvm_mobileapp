import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hlvm_mobileapp/services/api.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hlvm_mobileapp/core/services/session_manager.dart';
import 'package:hlvm_mobileapp/core/services/session_provider.dart';
import 'package:hlvm_mobileapp/features/auth/view/settings_screen.dart';
import 'package:hlvm_mobileapp/features/receipts/view/receipts_screen.dart';
import 'package:hlvm_mobileapp/main.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hlvm_mobileapp/core/theme/app_theme.dart';
import 'package:hlvm_mobileapp/core/utils/logger.dart';
import 'package:hlvm_mobileapp/core/utils/error_handler.dart';

// Функция для логирования в файл
Future<void> logToFile(String message) async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final logFile = File('${directory.path}/receipt_processing.log');

    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] $message\n';

    await logFile.writeAsString(logEntry, mode: FileMode.append);
  } catch (e) {
    AppLogger.error('Ошибка записи в лог', e);
  }
}

// Функция для очистки лог файла
Future<void> clearLogFile() async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final logFile = File('${directory.path}/receipt_processing.log');

    if (await logFile.exists()) {
      await logFile.delete();
      AppLogger.info('Лог файл очищен');
    }
  } catch (e) {
    AppLogger.error('Ошибка очистки лог файла', e);
  }
}

/// Fallback метод для выхода из аккаунта когда SessionManager недоступен
Future<void> _handleLogoutFallback(BuildContext context) async {
  try {
    const storage = FlutterSecureStorage();
    await storage.delete(key: 'access_token');
    await storage.delete(key: 'refresh_token');
    await storage.delete(key: 'isLoggedIn');

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сессия истекла. Войдите снова.')),
      );
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  } catch (e) {
    AppLogger.error('Ошибка при fallback выходе из аккаунта', e);
  }
}

class ImageCaptureScreen extends StatefulWidget {
  const ImageCaptureScreen({super.key});

  @override
  State<ImageCaptureScreen> createState() => _ImageCaptureScreenState();
}

class _ImageCaptureScreenState extends State<ImageCaptureScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final String _responseDataUrl = '';
  String? _dataUrl;
  bool _isLoading = false;
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // SessionManager будет получен из контекста при необходимости
    _animationController = AnimationController(
      duration: AppStyles.defaultAnimationDuration,
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _captureImage(ImageSource source) async {
    setState(() {
      _isLoading = true;
    });

    // Сохраняем контекст до async операций
    final currentContext = context;

    // Проверяем аутентификацию перед началом обработки
    if (!SessionProvider.hasSessionProvider(currentContext)) {
      // Если SessionProvider недоступен, используем прямую проверку
      final storage = const FlutterSecureStorage();
      final accessToken = await storage.read(key: 'access_token');
      if (accessToken == null) {
        if (mounted) {
          ScaffoldMessenger.of(currentContext).showSnackBar(
            const SnackBar(content: Text('Сессия истекла. Войдите снова.')),
          );
          Navigator.of(currentContext)
              .pushNamedAndRemoveUntil('/login', (route) => false);
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }
    } else {
      final sessionManager = SessionProvider.maybeOf(currentContext);
      if (sessionManager == null ||
          !await sessionManager.checkAuthenticationWithUI(currentContext)) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final selectedAccount = prefs.getInt('selectedAccountId');

    if (selectedAccount == null || selectedAccount == 0) {
      if (mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          const SnackBar(content: Text('Сначала выберите финансовый счет')),
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
          const SnackBar(
            content: Text(
                'GitHub API токен не настроен. Перейдите в настройки и добавьте токен GitHub.'),
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
              if (SessionProvider.hasSessionProvider(currentContext)) {
                final sessionManager = SessionProvider.maybeOf(currentContext);
                if (sessionManager != null) {
                  await sessionManager.logoutOnSessionExpired(currentContext);
                }
              } else {
                // Fallback: прямой выход из аккаунта
                await _handleLogoutFallback(currentContext);
              }
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
          await _apiService.createReceipt(jsonData);

          if (mounted) {
            ScaffoldMessenger.of(currentContext).showSnackBar(
              const SnackBar(content: Text('Чек был успешно загружен')),
            );
            await Future.delayed(const Duration(milliseconds: 500));
            Navigator.of(currentContext).pushAndRemoveUntil(
              MaterialPageRoute(
                  builder: (context) => const HomePage(selectedIndex: 1)),
              (route) => false,
            );
          }
        } catch (e) {
          await logToFile('❌ [_captureImage] Ошибка при создании чека: $e');
          await logToFile(
              '🔍 [_captureImage] Данные, отправленные на сервер: $jsonData');
          String errorMsg = 'Ошибка при добавлении чека: $e';
          if (e is DioException) {
            await logToFile(
                '🔍 [_captureImage] DioException при создании чека: ${e.type}');
            await logToFile(
                '🔍 [_captureImage] DioException статус: ${e.response?.statusCode}');
            await logToFile(
                '🔍 [_captureImage] DioException данные: ${e.response?.data}');

            if (e.response?.statusCode == 401) {
              await logToFile(
                  '❌ [_captureImage] Ошибка авторизации при создании чека');
              if (mounted) {
                if (SessionProvider.hasSessionProvider(currentContext)) {
                  final sessionManager =
                      SessionProvider.maybeOf(currentContext);
                  if (sessionManager != null) {
                    await sessionManager.logoutOnSessionExpired(currentContext);
                  }
                } else {
                  await _handleLogoutFallback(currentContext);
                }
              }
              setState(() {
                _isLoading = false;
              });
              return;
            }
            if (e.response?.statusCode == 400) {
              final data = e.response?.data;
              await logToFile('🔍 [_captureImage] Данные ошибки 400: $data');
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
      await logToFile('❌ [_captureImage] Общая ошибка: $e');
      if (e is DioException) {
        final status = e.response?.statusCode;
        final serverMsg = e.response?.data?.toString() ?? '';

        if (status == 401) {
          await logToFile('❌ [_captureImage] Ошибка авторизации в общем блоке');
          if (mounted) {
            if (SessionProvider.hasSessionProvider(currentContext)) {
              final sessionManager = SessionProvider.maybeOf(currentContext);
              if (sessionManager != null) {
                await sessionManager.logoutOnSessionExpired(currentContext);
              }
            } else {
              await _handleLogoutFallback(currentContext);
            }
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
          await logToFile('🔍 [_captureImage] Детали ошибки 400: $detailMsg');
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
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Обработка фото чека'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () async {
              try {
                final directory = await getApplicationDocumentsDirectory();
                final logFile =
                    File('${directory.path}/receipt_processing.log');

                if (await logFile.exists()) {
                  final logContent = await logFile.readAsString();
                  if (mounted) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Логи обработки'),
                        content: SingleChildScrollView(
                          child: SelectableText(logContent),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Закрыть'),
                          ),
                          TextButton(
                            onPressed: () async {
                              await clearLogFile();
                              if (mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Логи очищены')),
                                );
                              }
                            },
                            child: const Text('Очистить'),
                          ),
                        ],
                      ),
                    );
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Лог файл не найден')),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ошибка чтения логов: $e')),
                  );
                }
              }
            },
            tooltip: 'Просмотр логов',
          ),
        ],
      ),
      body: _isLoading ? _buildLoadingScreen() : _buildMainContent(),
    );
  }

  Widget _buildLoadingScreen() {
    return Container(
      decoration: BoxDecoration(
        gradient: AppStyles.balanceCardGradient,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.receipt_long,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            const Text(
              'Обрабатываем чек...',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Пожалуйста, подождите',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: SingleChildScrollView(
              padding: AppStyles.defaultPadding,
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildHeaderSection(),
                  const SizedBox(height: 40),
                  _buildActionButtons(),
                  const SizedBox(height: 40),
                  _buildInfoSection(),
                  if (_dataUrl != null) ...[
                    const SizedBox(height: 20),
                    _buildDataUrlSection(),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: AppStyles.cardPadding,
      decoration: BoxDecoration(
        gradient: AppStyles.balanceCardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppStyles.cardShadow,
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Загрузка чека',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Сфотографируйте или выберите чек для автоматической обработки',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        _buildActionButton(
          icon: Icons.camera_alt,
          title: 'Сделать фото',
          subtitle: 'Сфотографировать чек',
          onTap: () => _captureImage(ImageSource.camera),
          gradient: AppStyles.balanceCardGradient,
        ),
        const SizedBox(height: 16),
        _buildActionButton(
          icon: Icons.photo_library,
          title: 'Выбрать из галереи',
          subtitle: 'Выбрать существующее фото',
          onTap: () => _captureImage(ImageSource.gallery),
          gradient: AppStyles.successCardGradient,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required LinearGradient gradient,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppStyles.buttonShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white70,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: AppStyles.cardPadding,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppStyles.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: AppTheme.primaryGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Советы по фотографированию',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTipItem(
            icon: Icons.light_mode,
            text: 'Обеспечьте хорошее освещение',
          ),
          _buildTipItem(
            icon: Icons.crop_free,
            text: 'Чек должен полностью помещаться в кадр',
          ),
          _buildTipItem(
            icon: Icons.straighten,
            text: 'Держите камеру ровно и параллельно чеку',
          ),
          _buildTipItem(
            icon: Icons.visibility,
            text: 'Убедитесь, что текст четко читается',
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppTheme.primaryGreen,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataUrlSection() {
    return Container(
      padding: AppStyles.cardPadding,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryGreen.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: AppTheme.successGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Изображение загружено',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.successGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _responseDataUrl,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 3,
          ),
        ],
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
    String dataUrl = "data:image/$imageFormat;base64,$base64Image";

    return dataUrl;
  } catch (e) {
    rethrow;
  }
}

Future<String?> getGithubToken() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('github_token');

  return token;
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
        final isoString = dt.toIso8601String();
        return isoString;
      }
    }

    // Если уже ISO, возвращаем как есть
    DateTime.parse(dateStr);
    return dateStr;
  } catch (e) {
    return dateStr; // если не получилось, возвращаем как есть
  }
}

Future<Map<String, dynamic>> getJsonReceipt(dataUrl) async {
  final storage = const FlutterSecureStorage();
  final accessToken = await storage.read(key: 'access_token');
  final prefs = await SharedPreferences.getInstance();
  final selectedAccount = prefs.getInt('selectedAccountId');

  if (accessToken == null) {
    await logToFile('❌ [getJsonReceipt] Ошибка: Access token не найден');
    return {'Error': '401 Unauthorized - Access token not found'};
  }

  final Map<String, dynamic> decodedToken = JwtDecoder.decode(accessToken);

  final int userId;
  if (decodedToken['user_id'] is String) {
    userId = int.parse(decodedToken['user_id']);
  } else {
    userId = decodedToken['user_id'];
  }

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
    await logToFile('❌ [getJsonReceipt] Ошибка: GitHub API токен не настроен');
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
    await logToFile('🔍 [getJsonReceipt] Сырой ответ от ИИ: $rawResponse');

    String cleanedResponse =
        rawResponse.replaceAll('```json', '').replaceAll('```', '').trim();

    final result = jsonDecode(cleanedResponse);
    await logToFile('🔍 [getJsonReceipt] Парсированный JSON: $result');

    // Автоматически преобразуем дату в ISO 8601, если нужно
    if (result is Map<String, dynamic> && result.containsKey('receipt_date')) {
      result['receipt_date'] =
          convertToIsoDate(result['receipt_date']?.toString());
    }

    if (result is Map<String, dynamic>) {
      // Проверяем наличие обязательных полей
      if (result['total_sum'] == null) {
        await logToFile('❌ [getJsonReceipt] Ошибка: отсутствует total_sum');
        return {'Error': 'Missing required data: total_sum'};
      }

      if (result['items'] == null || result['items'].isEmpty) {
        await logToFile(
            '❌ [getJsonReceipt] Ошибка: отсутствуют items или массив пуст');
        return {'Error': 'Missing required data: items'};
      }

      if (result['receipt_date'] == null) {
        await logToFile('❌ [getJsonReceipt] Ошибка: отсутствует receipt_date');
        return {'Error': 'Missing required data: receipt_date'};
      }

      // Преобразуем структуру данных для соответствия ожиданиям сервера

      // Создаем объект seller
      final seller = {
        'user': userId,
        'name_seller': result['name_seller'],
        'retail_place_address': result['retail_place_address'],
        'retail_place': result['retail_place'],
      };

      // Преобразуем items в product
      final List<Map<String, dynamic>> products = [];
      for (var item in result['items']) {
        products.add({
          'user': userId,
          'product_name': item['product_name'],
          'category': item['category'],
          'price': item['price'] is String
              ? double.parse(item['price'])
              : item['price'],
          'quantity': item['quantity'] is String
              ? double.parse(item['quantity'])
              : item['quantity'],
          'amount': item['amount'] is String
              ? double.parse(item['amount'])
              : item['amount'],
        });
      }

      // Создаем финальную структуру данных
      final Map<String, dynamic> finalData = {
        'user': userId,
        'finance_account': selectedAccount ?? 0,
        'receipt_date': result['receipt_date'],
        'number_receipt': result['number_receipt'] is String
            ? int.parse(result['number_receipt'])
            : result['number_receipt'],
        'nds10': result['nds10'] is String
            ? double.parse(result['nds10'])
            : result['nds10'],
        'nds20': result['nds20'] is String
            ? double.parse(result['nds20'])
            : result['nds20'],
        'operation_type': result['operation_type'] is String
            ? int.parse(result['operation_type'])
            : result['operation_type'],
        'total_sum': result['total_sum'] is String
            ? double.parse(result['total_sum'])
            : result['total_sum'],
        'seller': seller,
        'product': products,
      };

      await logToFile(
          '🔍 [getJsonReceipt] Финальная структура данных: $finalData');

      return finalData;
    }

    return result;
  } catch (e) {
    await logToFile('❌ [getJsonReceipt] Ошибка при обработке: $e');
    if (e is DioException) {
      final statusCode = e.response?.statusCode;
      final responseData = e.response?.data;

      await logToFile(
          '🔍 [getJsonReceipt] DioException - статус: $statusCode, данные: $responseData');

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
