import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hlvm_mobileapp/services/api.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hlvm_mobileapp/features/auth/view/settings_screen.dart';
import 'package:hlvm_mobileapp/main.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hlvm_mobileapp/core/theme/app_theme.dart';
import 'package:hlvm_mobileapp/core/utils/logger.dart';
import 'package:hlvm_mobileapp/core/constants/app_constants.dart';
import 'package:hlvm_mobileapp/core/services/secure_token_storage_service.dart';
import 'package:hlvm_mobileapp/features/receipts/view/prepare_data.dart';



// Вспомогательные функции для безопасного парсинга
int _safeParseInt(dynamic value) {
  print(
      'DEBUG: _safeParseInt called with: $value (type: ${value.runtimeType})');
  if (value == null) {
    print('DEBUG: _safeParseInt: value is null, returning 0');
    return 0;
  }
  if (value is int) {
    print('DEBUG: _safeParseInt: value is int, returning $value');
    return value;
  }
  if (value is double) {
    print(
        'DEBUG: _safeParseInt: value is double, converting to int: ${value.toInt()}');
    return value.toInt();
  }
  if (value is String) {
    try {
      final result = int.parse(value);
      print('DEBUG: _safeParseInt: parsed string "$value" to int: $result');
      return result;
    } catch (e) {
      print(
          'DEBUG: _safeParseInt: failed to parse string "$value", returning 0');
      return 0;
    }
  }
  print('DEBUG: _safeParseInt: unknown type, returning 0');
  return 0;
}

double _safeParseDouble(dynamic value) {
  print(
      'DEBUG: _safeParseDouble called with: $value (type: ${value.runtimeType})');
  if (value == null) {
    print('DEBUG: _safeParseDouble: value is null, returning 0.0');
    return 0.0;
  }
  if (value is double) {
    print('DEBUG: _safeParseDouble: value is double, returning $value');
    // Округляем до 3 знаков после запятой
    return double.parse(value.toStringAsFixed(3));
  }
  if (value is int) {
    print(
        'DEBUG: _safeParseDouble: value is int, converting to double: ${value.toDouble()}');
    return value.toDouble();
  }
  if (value is String) {
    try {
      final result = double.parse(value);
      print(
          'DEBUG: _safeParseDouble: parsed string "$value" to double: $result');
      // Округляем до 3 знаков после запятой
      return double.parse(result.toStringAsFixed(3));
    } catch (e) {
      print(
          'DEBUG: _safeParseDouble: failed to parse string "$value", returning 0.0');
      return 0.0;
    }
  }
  print('DEBUG: _safeParseDouble: unknown type, returning 0.0');
  return 0.0;
}

class ImageCaptureScreen extends StatefulWidget {
  const ImageCaptureScreen({super.key});

  @override
  State<ImageCaptureScreen> createState() {
    try {
      return _ImageCaptureScreenState();
    } catch (e) {
      AppLogger.error('Ошибка создания состояния ImageCaptureScreen: $e');
      rethrow;
    }
  }
}

class _ImageCaptureScreenState extends State<ImageCaptureScreen>
    with TickerProviderStateMixin {
  late final ApiService _apiService;
  final String _responseDataUrl = '';
  String? _dataUrl;
  bool _isLoading = false;
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  late final ImagePicker _picker;

  _ImageCaptureScreenState() {
    try {
      _apiService = ApiService();
      _picker = ImagePicker();
    } catch (e) {
      AppLogger.error('Ошибка создания сервисов: $e');
      rethrow;
    }
  }

  @override
  void initState() {
    super.initState();
    try {
      // Проверка аутентификации выполняется через токены
      _animationController = AnimationController(
        duration: const Duration(milliseconds: 200), // Уменьшаем время анимации
        vsync: this,
      );
      _pulseController = AnimationController(
        duration:
            const Duration(milliseconds: 2000), // Увеличиваем время пульсации
        vsync: this,
      );

      _fadeAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut, // Упрощаем кривую анимации
      ));

      _scaleAnimation = Tween<double>(
        begin: 0.9,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut, // Упрощаем кривую анимации
      ));

      _pulseAnimation = Tween<double>(
        begin: 1.0,
        end: 1.05, // Уменьшаем масштаб пульсации
      ).animate(CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ));

      // Запускаем анимации с задержкой для улучшения производительности
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _animationController.forward();
          _pulseController.repeat(reverse: true);
        }
      });
    } catch (e) {
      AppLogger.error('Ошибка инициализации ImageCaptureScreen: $e');
    }
  }

  @override
  void dispose() {
    try {
      _animationController.dispose();
      _pulseController.dispose();
    } catch (e) {
      AppLogger.error(
          'Ошибка при освобождении ресурсов ImageCaptureScreen: $e');
    }
    super.dispose();
  }

  Future<void> _captureImage(ImageSource source) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Сохраняем контекст до async операций
      final currentContext = context;

      // Добавляем таймаут для предотвращения зависания
      const timeoutDuration = Duration(seconds: 30);

      // Проверяем аутентификацию перед началом обработки
      const storage = FlutterSecureStorage();
      final accessToken = await storage.read(key: 'access_token');
      if (accessToken == null) {
        if (mounted) {
          _showSessionExpiredDialog(currentContext);
        }
        setState(() {
          _isLoading = false;
        });
        return;
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
      final secureStorage = SecureTokenStorageService();
      final githubToken = await secureStorage.getGithubToken();
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

      // Выбираем изображение с таймаутом
      final XFile? image = await _picker
          .pickImage(
            source: source,
            maxWidth: 1920, // Ограничиваем размер для производительности
            maxHeight: 1920,
            imageQuality: 85, // Снижаем качество для ускорения
          )
          .timeout(timeoutDuration);

      if (!mounted) return;

      if (image != null) {
        // Тестируем разные подходы к предобработке для лучшего распознавания
        print('DEBUG: Starting multi-approach preprocessing...');
        final Map<String, dynamic> rawJsonData =
            await testDifferentPreprocessing(image.path)
                .timeout(timeoutDuration);
        print('DEBUG: === FINISHED getJsonReceipt ===');
        print('DEBUG: rawJsonData: $rawJsonData');
        if (!mounted) return;

        if (rawJsonData.containsKey('Error')) {
          final errorStr = rawJsonData['Error'].toString();

          // Проверяем, является ли это ошибкой аутентификации к нашему серверу
          if (errorStr.contains('401') &&
              (errorStr.contains('Access token not found') ||
                  errorStr.contains('Unauthorized'))) {
            if (mounted) {
              // Очищаем токены при ошибке аутентификации
              await storage.delete(key: 'access_token');
              await storage.delete(key: 'refresh_token');
              await storage.delete(key: 'isLoggedIn');
              // Fallback: показываем диалог истечения сессии
              _showSessionExpiredDialog(currentContext);
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
              SnackBar(content: Text('Ошибка: ${rawJsonData['Error']}')),
            );
          }
          setState(() {
            _isLoading = false;
          });
          return;
        }

        // Подготавливаем данные через PrepareData
        print('DEBUG: Raw JSON from AI: $rawJsonData');
        final prepareData = PrepareData();
        Map<String, dynamic> preparedData;
        try {
          preparedData = await prepareData.prepareData(rawJsonData);
          print('DEBUG: Prepared JSON for API: $preparedData');
        } catch (e) {
          print('DEBUG: Error preparing data: $e');
          if (mounted) {
            ScaffoldMessenger.of(currentContext).showSnackBar(
              SnackBar(content: Text('Ошибка подготовки данных: $e')),
            );
          }
          setState(() {
            _isLoading = false;
          });
          return;
        }

        // Создаем чек с таймаутом
        print('DEBUG: Sending receipt data to API');
        print('DEBUG: Receipt data keys: ${preparedData.keys.toList()}');
        print('DEBUG: Total sum: ${preparedData['total_sum']}');
        print('DEBUG: Items count: ${preparedData['product']?.length ?? 0}');
        print('DEBUG: Full JSON before API call: $preparedData');

        // Проверяем обязательные поля
        print('DEBUG: === MANDATORY FIELD CHECK ===');
        print('DEBUG: user: ${preparedData['user']}');
        print('DEBUG: finance_account: ${preparedData['finance_account']}');
        print('DEBUG: seller: ${preparedData['seller']}');
        print('DEBUG: total_sum: ${preparedData['total_sum']}');
        print('DEBUG: receipt_date: ${preparedData['receipt_date']}');
        print('DEBUG: number_receipt: ${preparedData['number_receipt']}');
        print('DEBUG: nds10: ${preparedData['nds10']}');
        print('DEBUG: nds20: ${preparedData['nds20']}');
        print('DEBUG: operation_type: ${preparedData['operation_type']}');
        print('DEBUG: product (items): ${preparedData['product']}');
        print('DEBUG: === END MANDATORY FIELD CHECK ===');

        final result = await _apiService
            .createReceipt(preparedData)
            .timeout(timeoutDuration);

        print('DEBUG: API response: $result');

        if (mounted) {
          if (result.contains('успешно') || result.contains('добавлен')) {
            ScaffoldMessenger.of(currentContext).showSnackBar(
              SnackBar(content: Text(result)),
            );
            await Future.delayed(const Duration(milliseconds: 500));
            Navigator.of(currentContext).pushAndRemoveUntil(
              MaterialPageRoute(
                  builder: (context) => const HomePage(selectedIndex: 1)),
              (route) => false,
            );
          } else {
            // Показываем ошибку от сервера
            ScaffoldMessenger.of(currentContext).showSnackBar(
              SnackBar(
                content: Text('Ошибка загрузки чека: $result'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } on TimeoutException catch (e) {
      AppLogger.error('Таймаут операции: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Операция превысила время ожидания. Попробуйте еще раз.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Общая ошибка в _captureImage: $e');
      
      // Проверяем специфические ошибки
      final errorStr = e.toString();
      if (errorStr.contains('Необходимо указать адрес сервера')) {
        if (mounted) {
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
        }
      } else if (errorStr.contains('авторизации') || errorStr.contains('401')) {
        if (mounted) {
          _showSessionExpiredDialog(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Произошла ошибка: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Показывает диалог истечения сессии с кнопкой "Войти снова"
  void _showSessionExpiredDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.errorRed,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                'Сессия истекла',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ваша сессия в приложении истекла, пожалуйста, войдите снова',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.errorRed.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppTheme.errorRed,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Для продолжения работы необходимо войти в систему',
                        style: TextStyle(
                          color: AppTheme.errorRed,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Закрываем диалог
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login',
                  (route) => false,
                );
              },
              style: TextButton.styleFrom(
                backgroundColor: AppTheme.errorRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Войти снова',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    try {
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
                                // await clearLogFile(); // Удалено
                                if (mounted) {
                                  Navigator.of(context).pop();
                                  // ScaffoldMessenger.of(context).showSnackBar( // Удалено
                                  //     const SnackBar( // Удалено
                                  //         content: Text('Логи очищены')), // Удалено
                                  // ); // Удалено
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
    } catch (e) {
      AppLogger.error('Ошибка построения ImageCaptureScreen: $e');
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('Обработка фото чека'),
          elevation: 0,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              SizedBox(height: 16),
              Text(
                'Ошибка загрузки экрана',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Попробуйте перезапустить приложение',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildLoadingScreen() {
    try {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primaryGreen, AppTheme.primaryLightGreen],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
    } catch (e) {
      AppLogger.error('Ошибка построения экрана загрузки: $e');
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primaryGreen, AppTheme.primaryLightGreen],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.receipt_long,
                size: 60,
                color: Colors.white,
              ),
              SizedBox(height: 32),
              Text(
                'Загрузка...',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 32),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildMainContent() {
    try {
      return AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
    } catch (e) {
      AppLogger.error('Ошибка построения основного контента: $e');
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryGreen, AppTheme.primaryLightGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 40,
                    color: Colors.white,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Загрузка чека',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Сфотографируйте или выберите чек для автоматической обработки',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Ошибка загрузки интерфейса',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Попробуйте перезапустить приложение',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryGreen, AppTheme.primaryLightGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          gradient: const LinearGradient(
            colors: [AppTheme.successGreen, AppTheme.primaryAccentGreen],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
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
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                    mainAxisSize: MainAxisSize.min,
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
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataUrlSection() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryGreen.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.check_circle,
                color: AppTheme.successGreen,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
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

    // Проверяем размер файла для предотвращения зависания
    final fileSize = await imageFile.length();
    if (fileSize > 10 * 1024 * 1024) {
      // 10MB лимит
      throw Exception("Файл слишком большой. Максимальный размер: 10MB");
    }

    List<int> imageBytes = await imageFile.readAsBytes();

    // Кодирование байтов в Base64
    String base64Image = base64Encode(imageBytes);

    // Формирование строки Data URL
    String dataUrl = "data:image/$imageFormat;base64,$base64Image";

    return dataUrl;
  } catch (e) {
    AppLogger.error('Ошибка при получении Data URL: $e');
    rethrow;
  }
}



// Функция для преобразования даты в ISO 8601
String? convertToIsoDate(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty || dateStr == 'Не указано') {
    print('DEBUG: Date is null, empty, or "Не указано", using current date');
    return DateTime.now().toIso8601String();
  }

  print('DEBUG: Converting date: "$dateStr"');

  try {
    // Пробуем распарсить "12.06.2023 18:28" или "22.08.2025 16:13"
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

        // Валидация даты
        if (year < 2000 || year > 2030) {
          print('DEBUG: Invalid year: $year, using current date');
          return DateTime.now().toIso8601String();
        }
        if (month < 1 || month > 12) {
          print('DEBUG: Invalid month: $month, using current date');
          return DateTime.now().toIso8601String();
        }
        if (day < 1 || day > 31) {
          print('DEBUG: Invalid day: $day, using current date');
          return DateTime.now().toIso8601String();
        }

        final dt = DateTime(year, month, day, hour, minute, second);
        final isoString = dt.toIso8601String();
        print('DEBUG: Successfully converted to ISO: $isoString');
        return isoString;
      }
    }

    // Пробуем распарсить "22.08.2025 16:13:00"
    if (dateStr.contains('.') && dateStr.contains(':')) {
      final parts = dateStr.split(' ');
      if (parts.length >= 2) {
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
          print('DEBUG: Successfully converted to ISO: $isoString');
          return isoString;
        }
      }
    }

    // Если уже ISO, возвращаем как есть
    DateTime.parse(dateStr);
    print('DEBUG: Date is already in ISO format: $dateStr');
    return dateStr;
  } catch (e) {
    print('DEBUG: Error parsing date "$dateStr": $e, using current date');
    return DateTime.now().toIso8601String();
  }
}

Future<Map<String, dynamic>> getJsonReceipt(String imageData) async {
  print(
      'DEBUG: getJsonReceipt called with imageData length: ${imageData.length}');
  return await _processWithModel(imageData);
}

// Функция для тестирования разных подходов к предобработке
Future<Map<String, dynamic>> testDifferentPreprocessing(
    String imagePath) async {
  print('DEBUG: Processing image with GPT-4o');

  // Обработка оригинального изображения с GPT-4o
  print('DEBUG: Processing original image with GPT-4o...');
  final gptResult = await _processWithModel(imagePath);
  print(
      'DEBUG: GPT-4o result: ${gptResult.containsKey('Error') ? 'ERROR' : 'SUCCESS'}');

  if (!gptResult.containsKey('Error')) {
    print('DEBUG: GPT-4o successful');
    return gptResult;
  }

  // Если GPT-4o не сработал, возвращаем ошибку
  print('DEBUG: GPT-4o failed');
  return gptResult;
}

Future<Map<String, dynamic>> _processWithModel(String imageData) async {
  try {
    // Определяем, является ли imageData путем к файлу или base64 строкой
    bool isBase64Data = imageData.startsWith('data:image/');
    print('DEBUG: isBase64Data: $isBase64Data');

    // Создаем запрос к GitHub AI API для обработки изображения
    final apiService = ApiService();

    // Подготавливаем base64 изображение для отправки
    String base64Image;
    if (isBase64Data) {
      final parts = imageData.split(',');
      base64Image = parts[1];
    } else {
      // Если это путь к файлу, читаем и кодируем в base64
      final file = File(imageData);
      if (!await file.exists()) {
        print('DEBUG: Image file does not exist: $imageData');
        return {'Error': 'Файл изображения не найден'};
      }

      try {
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) {
          print('DEBUG: Image file is empty: $imageData');
          return {'Error': 'Файл изображения пуст'};
        }
        base64Image = base64Encode(bytes);
        print(
            'DEBUG: Successfully encoded image to base64, size: ${bytes.length} bytes');
      } catch (e) {
        print('DEBUG: Error reading image file: $e');
        return {'Error': 'Ошибка чтения файла изображения: $e'};
      }
    }

    // Формируем запрос к GitHub AI API в соответствии с рекомендациями
    final requestBody = {
      "model": "meta/Llama-3.2-90B-Vision-Instruct",
      "messages": [
        {
          "role": "system",
          "content":
              "You are a specialized Russian receipt data extraction system. Extract receipt data with extreme precision and COMPLETENESS from the original image.\n\nSTRUCTURE: {\"name_seller\":\"string\",\"retail_place_address\":\"string\",\"retail_place\":\"string\",\"items\":[{\"name\":\"string\",\"price\":number,\"quantity\":number,\"category\":\"string\",\"nds_type\":number}],\"total_sum\":number,\"receipt_date\":\"string\",\"number_receipt\":number,\"nds10\":number,\"nds20\":number,\"operation_type\":1}\n\nCRITICAL RULES FOR RUSSIAN RECEIPTS:\n1. SELLER INFO: Look for store name in header (e.g., 'Лента', 'Магнит', 'Пятерочка'). Extract full name including 'ООО', 'ИП' if present. In this case: '000 \"Лента\"' → name_seller: '000 \"Лента\"'\n2. ADDRESS: Look for 'Адрес расчетов' or 'Место расчетов' - extract full address including city, street, building. In this case: 'Россия, 141070, Московская обл., г. Королев, Пионерская ул., 19,3' → retail_place_address: 'Россия, 141070, Московская обл., г. Королев, Пионерская ул., 19,3'\n3. RETAIL PLACE: Look for store location name (e.g., 'ТК Лента-647') → retail_place: 'ТК Лента-647'\n4. DATE: Look for 'Дата/Время' field - extract as DD.MM.YYYY HH:MM format (e.g., '22.08.2025 16:13')\n5. QUANTITY (Кол-во): Read EXACTLY from receipt - 0.648 means 0.648 kg for weight items\n6. PRICE HANDLING: Check if price column exists in receipt\n   - IF price column exists: use the price directly\n   - IF no price column: calculate price as Сумма ÷ Кол-во (amount ÷ quantity)\n7. For weight items (вес): quantity = exact weight in kg\n8. For regular items: quantity = item count\n9. Categories: \n   - Продукты: food, drinks, dairy, snacks\n   - Бытовая химия: cleaning, hygiene, cosmetics\n   - Другое: bags, decorations, stationery\n10. COMPLETENESS: Extract ALL items from the receipt - do not skip any items, even if they seem similar\n11. All numbers as numbers, not strings\n12. QR CODE: Ignore QR codes at the bottom of the receipt - focus only on text data\n13. PRECISION: Keep 3 decimal places for all calculations (e.g., 64.787, 99.983)\n14. ACCURACY: Be extremely careful not to mix up data between different items\n15. ITEM COUNT: Count all items carefully - typical receipts have 10-30 items\n16. NO SKIPPING: Do not skip items even if they appear similar or have small amounts\n17. NDS: Extract total НДС 10% and НДС 20% from summary section. They are NOT per item unless specified. Use the totals from the bottom of the receipt.\n18. TOTAL SUM: The final amount before tax breakdown is the total_sum (2844.50)\n\nEXAMPLES:\n- Store: '000 \"Лента\"' → name_seller: '000 \"Лента\"'\n- Address: 'Россия, 141070, Московская обл., г. Королев, Пионерская ул., 19,3' → retail_place_address: 'Россия, 141070, Московская обл., г. Королев, Пионерская ул., 19,3'\n- Location: 'ТК Лента-647' → retail_place: 'ТК Лента-647'\n- Date: '22.08.2025 16:13' → receipt_date: '22.08.2025 16:13'\n- With price column: 'Товар' with Цена: 99.99, Кол-во: 2, Сумма: 199.98 → price: 99.99, quantity: 2\n- Without price column: 'Кабачки грунтовые 1кг' with Кол-во: 0.648, Сумма: 64.79 → quantity: 0.648, price: 64.79 ÷ 0.648 = 99.983\n- Weight item: 'Лук репчатый вес 1кг' with Кол-во: 0.182, Сумма: 7.28 → quantity: 0.182, price: 7.28 ÷ 0.182 = 40.000\n\nIMPORTANT: Extract EVERY SINGLE ITEM from the receipt. Do not stop at 15 items - continue until you have processed ALL items visible in the image. Be extremely precise with quantities and amounts. Ignore QR codes and focus only on text data.\n\nPay special attention to header information for seller details and date/time field. Return ONLY valid JSON."
        },
        {
          "role": "user",
          "content": [
            {
              "text":
                  "Extract ALL receipt data from this Russian cash receipt. IMPORTANT: Extract EVERY SINGLE ITEM - do not skip any items. Ignore QR codes at the bottom of the receipt - focus only on text data. Check if the receipt has a price column. If price column exists, use it directly. If no price column, calculate unit price as: price = amount ÷ quantity. For weight items, this gives price per kg. For regular items, this gives price per item. Be extremely thorough and complete.",
              "type": "text"
            },
            {
              "image_url": {
                "url": "data:image/jpeg;base64,$base64Image",
                "detail": "high"
              },
              "type": "image_url"
            }
          ]
        }
      ],
      "temperature": 0.1,
      "max_tokens": 4096,
      "top_p": 1.0,
      "frequency_penalty": 0,
      "presence_penalty": 0
    };

    // Отправляем запрос к GitHub AI API используя специальный метод
    print('DEBUG: Sending request to GitHub AI API');
    print('DEBUG: Endpoint: ${AppConstants.receiptsParseImageEndpoint}');
    print('DEBUG: Request body keys: ${requestBody.keys.toList()}');
    print('DEBUG: Model: ${requestBody["model"]}');

    final response = await apiService.postToGithubAI(
      AppConstants.receiptsParseImageEndpoint,
      requestBody,
    );

    print('DEBUG: GitHub AI API response status: ${response.statusCode}');
    print('DEBUG: GitHub AI API response data: ${response.data}');

    if (response.statusCode != 200) {
      print('DEBUG: Response status code: ${response.statusCode}');
      print('DEBUG: Response data: ${response.data}');

      if (response.statusCode == 401) {
        print('DEBUG: 401 Unauthorized - Token might be invalid or expired');
        return {'Error': 'Ошибка авторизации GitHub API. Проверьте токен.'};
      }
      if (response.statusCode == 404) {
        print('DEBUG: 404 Not Found - Endpoint might be incorrect');
        return {
          'Error': 'GitHub AI API недоступен. Обратитесь к администратору.'
        };
      }
      if (response.statusCode == 403) {
        print(
            'DEBUG: 403 Forbidden - Token might not have required permissions');
        return {
          'Error': 'Токен не имеет необходимых прав доступа к GitHub AI API.'
        };
      }
      return {'Error': 'Ошибка GitHub AI API: ${response.statusCode}'};
    }

    // Обрабатываем ответ от GitHub AI API
    final responseData = response.data;
    if (responseData == null ||
        responseData['choices'] == null ||
        responseData['choices'].isEmpty) {
      return {'Error': 'Неверный ответ от GitHub AI API'};
    }

    final content = responseData['choices'][0]['message']['content'];
    if (content == null) {
      return {'Error': 'Пустой ответ от GitHub AI API'};
    }

    // Извлекаем JSON из ответа (убираем markdown код, если есть)
    String jsonString = content.trim();

    // Убираем markdown код блоки
    if (jsonString.startsWith('```json')) {
      jsonString = jsonString.substring(7);
    } else if (jsonString.startsWith('```')) {
      jsonString = jsonString.substring(3);
    }
    if (jsonString.endsWith('```')) {
      jsonString = jsonString.substring(0, jsonString.length - 3);
    }
    jsonString = jsonString.trim();

    // Проверяем, что строка начинается с {
    if (!jsonString.startsWith('{')) {
      print(
          'DEBUG: Invalid JSON response - does not start with {: $jsonString');
      // Попробуем найти начало JSON в ответе
      int jsonStart = jsonString.indexOf('{');
      if (jsonStart >= 0) {
        jsonString = jsonString.substring(jsonStart);
        print(
            'DEBUG: Found JSON start at position $jsonStart, extracted: $jsonString');
      } else {
        return {
          'Error': 'AI модель вернула невалидный JSON. Попробуйте еще раз.'
        };
      }
    }

    // Проверяем, что строка заканчивается на }
    if (!jsonString.endsWith('}')) {
      print('DEBUG: JSON response does not end with }, attempting to fix...');
      
      // Пытаемся найти последнюю закрывающую скобку
      int lastBraceIndex = jsonString.lastIndexOf('}');
      if (lastBraceIndex > 0) {
        jsonString = jsonString.substring(0, lastBraceIndex + 1);
        print('DEBUG: Fixed JSON by truncating at position $lastBraceIndex');
      } else {
        print(
            'DEBUG: Cannot find closing brace, checking if response is in Russian...');

        // Проверяем, не является ли ответ русским текстом
        if (jsonString.contains('чека') ||
            jsonString.contains('товар') ||
            jsonString.contains('сумма') ||
            jsonString.contains('дата')) {
          print('DEBUG: Response appears to be in Russian, not JSON');
          return {
            'Error':
                'AI модель вернула ответ на русском языке вместо JSON. Попробуйте еще раз.'
          };
        }
        
        return {
          'Error': 'AI модель вернула невалидный JSON. Попробуйте еще раз.'
        };
      }
    }

    // Дополнительная проверка на неполные объекты в массиве items
    if (jsonString.contains('"items":[')) {
      // Ищем последний полный объект в массиве items
      int itemsStart = jsonString.indexOf('"items":[');
      int itemsEnd = jsonString.indexOf(']', itemsStart);

      if (itemsEnd > itemsStart) {
        String itemsSection = jsonString.substring(itemsStart + 8, itemsEnd);
        
        // Проверяем, есть ли неполные объекты
        if (itemsSection.contains('"name":') && !itemsSection.endsWith('}')) {
          print('DEBUG: Found incomplete item object, attempting to fix...');
          
          // Ищем последний полный объект
          int lastCompleteObject = itemsSection.lastIndexOf('},');
          if (lastCompleteObject > 0) {
            String fixedItemsSection =
                itemsSection.substring(0, lastCompleteObject + 1);
            jsonString = jsonString.replaceRange(
                itemsStart + 8, itemsEnd, fixedItemsSection);
            print('DEBUG: Fixed incomplete items array');
          }
        }
      }
    }

    Map<String, dynamic> result;
    try {
      result = jsonDecode(jsonString);
    } catch (e) {
      print('DEBUG: JSON decode error: $e');
      print('DEBUG: Raw response: $jsonString');
      return {
        'Error': 'Ошибка парсинга JSON от AI модели. Попробуйте еще раз.'
      };
    }

    // Логируем сырой результат от AI
    print('DEBUG: === RAW AI RESPONSE ===');
    print('DEBUG: Raw result: $result');
    print('DEBUG: Result keys: ${result.keys.toList()}');
    print(
        'DEBUG: total_sum: ${result['total_sum']} (type: ${result['total_sum']?.runtimeType})');
    print(
        'DEBUG: items: ${result['items']} (type: ${result['items']?.runtimeType})');
    print(
        'DEBUG: receipt_date: ${result['receipt_date']} (type: ${result['receipt_date']?.runtimeType})');
    print('DEBUG: === END RAW AI RESPONSE ===');

    // Проверяем обязательные поля
    if (result.containsKey('receipt_date')) {
      result['receipt_date'] =
          convertToIsoDate(result['receipt_date']?.toString());
    }

    // Валидация данных
    // Проверяем total_sum
    if (result['total_sum'] == null || result['total_sum'] == 0) {
      print(
          'DEBUG: WARNING: total_sum is null or 0, calculating from items...');

      // Вычисляем total_sum из сумм товаров с точностью до 3 знаков
      double calculatedTotal = 0.0;
      if (result['items'] != null && result['items'] is List) {
        for (var item in result['items']) {
          if (item is Map && item.containsKey('amount')) {
            double amount = _safeParseDouble(item['amount']);
            calculatedTotal += amount;
          }
        }
      }

      // Округляем до 3 знаков после запятой
      calculatedTotal = double.parse(calculatedTotal.toStringAsFixed(3));
      result['total_sum'] = calculatedTotal;
      print('DEBUG: Calculated total_sum from items: $calculatedTotal');

      // Если total_sum был 0, но мы его вычислили, то nds тоже могут быть 0
      // Попробуем вычислить примерные значения НДС
      if (calculatedTotal > 0 &&
          (result['nds10'] == null || result['nds10'] == 0) &&
          (result['nds20'] == null || result['nds20'] == 0)) {
        print('DEBUG: Calculating approximate NDS values...');
        // Примерный расчет: 10% НДС для продуктов, 20% для остального
        double nds10 = 0.0;
        double nds20 = 0.0;

        if (result['items'] != null && result['items'] is List) {
          for (var item in result['items']) {
            if (item is Map &&
                item.containsKey('amount') &&
                item.containsKey('category')) {
              double amount = _safeParseDouble(item['amount']);
              String category = item['category']?.toString() ?? '';

              if (category == 'Продукты') {
                nds10 += amount * 0.1; // 10% НДС для продуктов
              } else {
                nds20 += amount * 0.2; // 20% НДС для остального
              }
            }
          }
        }

        // Округляем НДС до 3 знаков после запятой
        result['nds10'] = double.parse(nds10.toStringAsFixed(3));
        result['nds20'] = double.parse(nds20.toStringAsFixed(3));
        print(
            'DEBUG: Calculated NDS - nds10: ${result['nds10']}, nds20: ${result['nds20']}');
      }
    }

    // Проверяем items
    if (result['items'] == null || result['items'].isEmpty) {
      print('DEBUG: ERROR: items is null or empty: ${result['items']}');
      return {
        'Error': 'Не удалось распознать товары в чеке. Попробуйте еще раз.'
      };
    }

    // Проверяем receipt_date
    if (result['receipt_date'] == null) {
      print(
          'DEBUG: WARNING: receipt_date is null, using current date as fallback');
      result['receipt_date'] = DateTime.now().toIso8601String();
    }

    // Формируем результат с безопасным преобразованием типов
    final finalResult = {
      'name_seller': result['name_seller']?.toString() ?? '',
      'retail_place_address': result['retail_place_address']?.toString() ?? '',
      'retail_place': result['retail_place']?.toString() ?? '',
      'product': result['items'] ?? [],
      'total_sum': _safeParseDouble(result['total_sum']),
      'receipt_date': result['receipt_date']?.toString(),
      'number_receipt': _safeParseInt(result['number_receipt']),
      'nds10': _safeParseDouble(result['nds10']),
      'nds20': _safeParseDouble(result['nds20']),
      'operation_type': _safeParseInt(result['operation_type']) == 0
          ? 1
          : _safeParseInt(result['operation_type']),
    };

    print('DEBUG: === FINAL PROCESSED JSON ===');
    print('DEBUG: Final result: $finalResult');
    print('DEBUG: === END FINAL PROCESSED JSON ===');

    // Финальная проверка обязательных полей
    if (finalResult['total_sum'] == 0.0) {
      print('DEBUG: ERROR: total_sum is still 0 after calculation');
      return {'Error': 'Не удалось вычислить общую сумму чека'};
    }

    if ((finalResult['product'] as List).isEmpty) {
      print('DEBUG: ERROR: product list is empty');
      return {'Error': 'Не удалось распознать товары в чеке'};
    }

    // Проверка количества товаров
    final productCount = (finalResult['product'] as List).length;
    print('DEBUG: Extracted $productCount items from receipt');
    if (productCount < 5) {
      print(
          'DEBUG: WARNING: Very few items extracted ($productCount), may be incomplete');
    }

    return finalResult;
  } catch (e) {
    print('DEBUG: Exception caught: $e');

    // Проверяем на отсутствие GitHub token
    if (e.toString().contains('GitHub API токен не настроен')) {
      return {'Error': 'GitHub API токен не настроен'};
    }

    // Проверяем на неправильный формат GitHub token
    if (e.toString().contains('неправильный формат')) {
      return {
        'Error':
            'GitHub API токен имеет неправильный формат. Должен начинаться с ghp_ или github_pat_'
      };
    }

    // Проверяем на ошибки парсинга JSON
    if (e.toString().contains('FormatException') ||
        e.toString().contains('Invalid radix-10 number') ||
        e.toString().contains('jsonDecode')) {
      return {
        'Error': 'AI модель вернула невалидный ответ. Попробуйте еще раз.'
      };
    }

    if (e is DioException) {
      print('DEBUG: DioException type: ${e.type}');
      print('DEBUG: DioException message: ${e.message}');
      print('DEBUG: DioException response status: ${e.response?.statusCode}');
      print('DEBUG: DioException response data: ${e.response?.data}');
      print('DEBUG: DioException response headers: ${e.response?.headers}');
      print('DEBUG: DioException request headers: ${e.requestOptions.headers}');
      print('DEBUG: DioException request data: ${e.requestOptions.data}');

      if (e.response?.statusCode == 401) {
        print('DEBUG: 401 Unauthorized - Token might be invalid or expired');
        return {'Error': 'Ошибка авторизации GitHub API. Проверьте токен.'};
      }
      if (e.response?.statusCode == 404) {
        print('DEBUG: 404 Not Found - Endpoint might be incorrect');
        return {
          'Error': 'GitHub AI API недоступен. Обратитесь к администратору.'
        };
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return {'Error': 'Таймаут соединения с GitHub AI API'};
      }
      if (e.type == DioExceptionType.connectionError) {
        return {'Error': 'Ошибка подключения к GitHub AI API'};
      }
      return {'Error': 'Ошибка GitHub AI API: ${e.message}'};
    }
    return {'Error': 'Ошибка при обработке: $e'};
  }
}
