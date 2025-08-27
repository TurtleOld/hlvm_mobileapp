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
  String _processingStatus = '';
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
      const timeoutDuration = Duration(seconds: 120);

      // Проверяем аутентификацию перед началом обработки
      const storage = FlutterSecureStorage();
      final accessToken = await storage.read(key: 'access_token');
      if (accessToken == null) {
        if (mounted) {
          _showSessionExpiredDialog(currentContext);
        }
        setState(() {
          _isLoading = false;
          _processingStatus = '';
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
          _processingStatus = '';
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

        setState(() {
          _processingStatus = 'Обрабатываю изображение...';
        });

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
              _processingStatus = '';
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
              _processingStatus = '';
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
            _processingStatus = '';
          });
          return;
        }

        // Подготавливаем данные через PrepareData
        print('DEBUG: Raw JSON from AI: $rawJsonData');

        setState(() {
          _processingStatus = 'Подготавливаю данные...';
        });

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
            _processingStatus = '';
          });
          return;
        }

        // Создаем чек с таймаутом
        print('DEBUG: Sending receipt data to API');
        print('DEBUG: Receipt data keys: ${preparedData.keys.toList()}');
        print('DEBUG: Total sum: ${preparedData['total_sum']}');
        print('DEBUG: Items count: ${preparedData['product']?.length ?? 0}');
        print('DEBUG: Full JSON before API call: $preparedData');

        setState(() {
          _processingStatus = 'Отправляю данные на сервер...';
        });

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
          _processingStatus = '';
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
              Text(
                _processingStatus.isNotEmpty
                    ? _processingStatus
                    : 'Пожалуйста, подождите',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
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

/// Тестирует разные подходы к предобработке изображения для лучшего распознавания
Future<Map<String, dynamic>> testDifferentPreprocessing(
    String imagePath) async {
  print('DEBUG: === STARTING DIFFERENT PREPROCESSING APPROACHES ===');

  try {
    // Пробуем сначала с GPT-4o (более стабильная модель)
    print('DEBUG: Trying with GPT-4o model');
    Map<String, dynamic> result =
        await _processWithModelInternal(imagePath, "openai/gpt-4o");

    if (!result.containsKey('Error')) {
      print('DEBUG: Success with GPT-4o model');
      return result;
    }

    // Если GPT-4o не сработал, пробуем Llama модель
    print('DEBUG: GPT-4o failed, trying Llama model');
    result = await _processWithModelInternal(
        imagePath, "meta/Llama-3.2-90B-Vision-Instruct");

    if (!result.containsKey('Error')) {
      print('DEBUG: Success with Llama model');
      return result;
    }

    // Если и Llama не сработал, пробуем еще раз с GPT-4o с более простым промптом
    print('DEBUG: Llama failed, trying GPT-4o with simplified prompt');
    result =
        await _processWithModelInternalSimplified(imagePath, "openai/gpt-4o");

    if (!result.containsKey('Error')) {
      print('DEBUG: Success with GPT-4o simplified prompt');
      return result;
    }

    // Если и это не сработал, возвращаем ошибку
    print('DEBUG: All models failed');
    return result;
  } catch (e) {
    print('DEBUG: Exception in testDifferentPreprocessing: $e');
    return {'Error': 'Ошибка обработки изображения: $e'};
  }
}

Future<Map<String, dynamic>> _processWithModelInternal(
    String imageData, String modelName) async {
  try {
    // Определяем, является ли imageData путем к файлу или base64 строкой
    bool isBase64Data = imageData.startsWith('data:image/');
    print('DEBUG: isBase64Data: $isBase64Data');
    print('DEBUG: Using model: $modelName');

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

    // Проверяем размер изображения и оптимизируем если нужно
    print('DEBUG: Original image size: ${base64Image.length} characters');

    // Если изображение слишком большое, используем среднее качество
    String imageDetail = "high";
    if (base64Image.length > 1000000) {
      // Больше 1MB в base64
      print('DEBUG: Image is large, using medium detail');
      imageDetail = "high";
    }

    // Формируем запрос к GitHub AI API в соответствии с рекомендациями
    final requestBody = {
      "model": modelName,
      "messages": [
        {
          "role": "system",
          "content":
              "Вы — помощник, который извлекает данные с кассовых чеков на русском языке и возвращает строго валидный JSON. Извлекайте данные с ПОЛНОТОЙ и ТОЧНОСТЬЮ.\n\nСТРУКТУРА ВЫВОДА:\n{\"name_seller\":\"string\",\"retail_place_address\":\"string\",\"retail_place\":\"string\",\"items\":[{\"product_name\":\"string\",\"category\":\"string\",\"price\":number,\"quantity\":number,\"amount\":number}],\"total_sum\":number,\"receipt_date\":\"string\",\"number_receipt\":number,\"nds10\":number,\"nds20\":number,\"operation_type\":1}\n\nПРАВИЛА:\n1. **name_seller**: Полное название магазина из заголовка чека, включая 'ООО', 'ИП' и кавычки.\n2. **retail_place_address**: Полный адрес из 'Адрес расчетов'.\n3. **retail_place**: Название из 'Место расчетов'.\n4. **receipt_date**: Из 'Дата/Время:' в формате 'ДД.ММ.ГГГГ ЧЧ:ММ'.\n5. **number_receipt**: Из 'Чек №:' или 'ФД №:'.\n6. **total_sum**: Из 'Итог:'.\n7. **nds10** и **nds20**: Из соответствующих строк.\n8. **items**:\n   - **product_name**: Полное название товара из 'ПРЕДМЕТ РАСЧЕТА'. Не оставлять пустым.\n   - **quantity**: Из 'КОЛ-ВО' точно как в чеке (может быть дробным, например 0.648 кг).\n   - **amount**: Из 'СУММА, Р' точно как в чеке (общая сумма за товар).\n   - **price**: Вычисляйте как price = amount ÷ quantity, округляя до 3 знаков после запятой.\n   - **category**: Определяйте по названию товара: 'Продукты' (еда, напитки), 'Бытовая химия' (средства), 'Другое'.\n   - Каждый товар отдельным объектом. Не пропускать товары с нулевой суммой.\n9. **operation_type**: Всегда 1.\n10. **ВАЖНО - Парсинг сумм и количества**:\n    - 'КОЛ-ВО' - это количество товара (может быть дробным для весовых товаров)\n    - 'СУММА, Р' - это общая сумма за товар (количество × цена за единицу)\n    - Цена за единицу = СУММА ÷ КОЛ-ВО\n    - Проверяйте, что сумма всех amount = total_sum\n11. **ПРИМЕР ПАРСИНГА**:\n    Если в чеке: 'Кабачки грунтовые 1кг' | 'КОЛ-ВО: 0.648' | 'СУММА, Р: 64.79'\n    То: quantity=0.648, amount=64.79, price=64.79÷0.648=99.98\n12. Все числа как числа, не строки. Ответ строго JSON, без текста, markdown или объяснений."
        },
        {
          "role": "user",
          "content": [
            {
              "type": "text",
              "text":
                  "Изучите изображение чека и преобразуйте его в JSON по инструкции выше. ВАЖНО: Внимательно различайте колонки 'КОЛ-ВО' (количество) и 'СУММА, Р' (общая сумма за товар). Количество может быть дробным (например, 0.648 кг), а сумма - это общая стоимость товара. Цену за единицу вычисляйте как СУММА ÷ КОЛ-ВО. Извлеките ВСЕ товары с правильными названиями, количеством, суммой и ценой. Проверьте, что сумма всех amount равна total_sum. Ответ только JSON, без текста."
            },
            {
              "type": "image_url",
              "image_url": {
                "url": "data:image/jpeg;base64,$base64Image",
                "detail": imageDetail
              }
            }
          ]
        }
      ],
      "temperature": 0.1,
      "max_tokens": 4096
    };

    // Отправляем запрос к GitHub AI API используя специальный метод
    print('DEBUG: Sending request to GitHub AI API');
    print('DEBUG: Endpoint: ${AppConstants.receiptsParseImageEndpoint}');
    print('DEBUG: Request body keys: ${requestBody.keys.toList()}');
    print('DEBUG: Model: ${requestBody["model"]}');
    print('DEBUG: Request body structure:');
    print(
        'DEBUG: - messages count: ${(requestBody["messages"] as List).length}');
    print(
        'DEBUG: - first message role: ${(requestBody["messages"] as List)[0]["role"]}');
    print(
        'DEBUG: - second message role: ${(requestBody["messages"] as List)[1]["role"]}');
    print(
        'DEBUG: - second message content type: ${(requestBody["messages"] as List)[1]["content"] is List ? "List" : "String"}');
    if ((requestBody["messages"] as List)[1]["content"] is List) {
      print(
          'DEBUG: - second message content items: ${((requestBody["messages"] as List)[1]["content"] as List).length}');
      print(
          'DEBUG: - first content item type: ${((requestBody["messages"] as List)[1]["content"] as List)[0]["type"]}');
      print(
          'DEBUG: - second content item type: ${((requestBody["messages"] as List)[1]["content"] as List)[1]["type"]}');
    }

    Response response;
    try {
      response = await apiService.postToGithubAI(
        AppConstants.receiptsParseImageEndpoint,
        requestBody,
      );
    } catch (e) {
      print('DEBUG: Exception during API call: $e');
      return {'Error': 'Ошибка отправки запроса к GitHub AI API: $e'};
    }

    print('DEBUG: GitHub AI API response status: ${response.statusCode}');
    print('DEBUG: GitHub AI API response data: ${response.data}');
    print('DEBUG: Response data type: ${response.data.runtimeType}');
    print(
        'DEBUG: Response data keys: ${response.data is Map ? response.data.keys.toList() : 'Not a Map'}');

    if (response.statusCode != 200) {
      print('DEBUG: Response status code: ${response.statusCode}');
      print('DEBUG: Response data: ${response.data}');

      // Если ошибка с GPT-4o, пробуем Llama модель
      if (modelName == "openai/gpt-4o" &&
          (response.statusCode == 500 || response.statusCode == 503)) {
        print('DEBUG: Server error with GPT-4o, trying Llama model');
        return await _processWithModelInternal(
            imageData, "meta/Llama-3.2-90B-Vision-Instruct");
      }

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
      if (response.statusCode == 400) {
        print('DEBUG: 400 Bad Request - Request structure might be incorrect');
        print('DEBUG: Response data: ${response.data}');
        return {
          'Error':
              'Неправильная структура запроса к GitHub AI API. Проверьте формат данных.'
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

    print('DEBUG: === AI MODEL RESPONSE CONTENT ===');
    print('DEBUG: Content length: ${content.length}');
    print(
        'DEBUG: Content preview (first 500 chars): ${content.length > 500 ? content.substring(0, 500) + '...' : content}');
    print(
        'DEBUG: Content ends with: ${content.length > 100 ? content.substring(content.length - 100) : content}');
    print('DEBUG: === END AI MODEL RESPONSE CONTENT ===');

    // Извлекаем JSON из ответа (убираем markdown код, если есть)
    String jsonString = content.trim();

    print('DEBUG: === JSON EXTRACTION PROCESS ===');
    print(
        'DEBUG: Original content starts with: ${jsonString.length > 50 ? jsonString.substring(0, 50) : jsonString}');
    print(
        'DEBUG: Original content ends with: ${jsonString.length > 50 ? jsonString.substring(jsonString.length - 50) : jsonString}');

    // Убираем markdown код блоки
    if (jsonString.startsWith('```json')) {
      jsonString = jsonString.substring(7);
      print('DEBUG: Removed ```json prefix');
    } else if (jsonString.startsWith('```')) {
      jsonString = jsonString.substring(3);
      print('DEBUG: Removed ``` prefix');
    }
    if (jsonString.endsWith('```')) {
      jsonString = jsonString.substring(0, jsonString.length - 3);
      print('DEBUG: Removed ``` suffix');
    }

    // Удаляем заголовки и лишний текст
    jsonString = jsonString.replaceAll('**Receipt Data Extraction**', '');
    jsonString = jsonString.replaceAll('Receipt Data Extraction', '');
    jsonString = jsonString.replaceAll('**', '');
    jsonString = jsonString.replaceAll('#', '');
    jsonString = jsonString.replaceAll('##', '');
    jsonString = jsonString.replaceAll('###', '');
    jsonString = jsonString.replaceAll('####', '');
    jsonString = jsonString.replaceAll('#####', '');
    jsonString = jsonString.replaceAll('######', '');

    // Удаляем другие возможные заголовки
    jsonString = jsonString.replaceAll('Receipt Analysis', '');
    jsonString = jsonString.replaceAll('Receipt Data', '');
    jsonString = jsonString.replaceAll('Extracted Data', '');
    jsonString = jsonString.replaceAll('Data Extraction', '');
    jsonString = jsonString.replaceAll('Receipt Information', '');
    jsonString = jsonString.replaceAll('Receipt Details', '');

    // Удаляем лишние пробелы и переносы строк
    jsonString = jsonString.trim();

    print(
        'DEBUG: After cleaning: ${jsonString.length > 100 ? jsonString.substring(0, 100) + '...' : jsonString}');
    print('DEBUG: === END JSON EXTRACTION PROCESS ===');

    // Проверяем, что строка начинается с {
    if (!jsonString.startsWith('{')) {
      print(
          'DEBUG: Invalid JSON response - does not start with {: $jsonString');

      // Удаляем заголовки и лишний текст
      jsonString = jsonString.replaceAll('**Receipt Data Extraction**', '');
      jsonString = jsonString.replaceAll('Receipt Data Extraction', '');
      jsonString = jsonString.replaceAll('**', '');
      jsonString = jsonString.replaceAll('#', '');
      jsonString = jsonString.replaceAll('##', '');
      jsonString = jsonString.replaceAll('###', '');
      jsonString = jsonString.replaceAll('####', '');
      jsonString = jsonString.replaceAll('#####', '');
      jsonString = jsonString.replaceAll('######', '');
      jsonString = jsonString.trim();

      // Попробуем найти начало JSON в ответе
      int jsonStart = jsonString.indexOf('{');
      if (jsonStart >= 0) {
        jsonString = jsonString.substring(jsonStart);
        print(
            'DEBUG: Found JSON start at position $jsonStart, extracted: $jsonString');
      } else {
        // Попробуем найти другие возможные начала JSON
        jsonStart = jsonString.indexOf('[');
        if (jsonStart >= 0) {
          jsonString = jsonString.substring(jsonStart);
          print(
              'DEBUG: Found array start at position $jsonStart, extracted: $jsonString');
        } else {
          return {
            'Error': 'AI модель вернула невалидный JSON. Попробуйте еще раз.'
          };
        }
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
      print('DEBUG: === JSON PARSING ===');
      print(
          'DEBUG: Attempting to parse JSON string: ${jsonString.length > 200 ? jsonString.substring(0, 200) + '...' : jsonString}');
      result = jsonDecode(jsonString);
      print('DEBUG: JSON parsing successful');
    } catch (e) {
      print('DEBUG: JSON decode error: $e');
      print('DEBUG: Raw JSON string: $jsonString');
      print('DEBUG: JSON string length: ${jsonString.length}');
      print(
          'DEBUG: JSON string starts with: ${jsonString.length > 50 ? jsonString.substring(0, 50) : jsonString}');
      print(
          'DEBUG: JSON string ends with: ${jsonString.length > 50 ? jsonString.substring(jsonString.length - 50) : jsonString}');

      // Попробуем найти и исправить распространенные ошибки JSON
      String fixedJson = jsonString;

      // Исправляем незакрытые кавычки
      if (fixedJson.split('"').length % 2 != 1) {
        print('DEBUG: Detected unclosed quotes, attempting to fix...');
        // Добавляем закрывающую кавычку в конец
        if (!fixedJson.endsWith('"')) {
          fixedJson += '"';
        }
      }

      // Исправляем незакрытые скобки
      int openBraces = fixedJson.split('{').length - 1;
      int closeBraces = fixedJson.split('}').length - 1;
      if (openBraces > closeBraces) {
        print('DEBUG: Detected unclosed braces, adding missing }');
        fixedJson += '}';
      }

      // Пробуем снова
      try {
        print('DEBUG: Attempting to parse fixed JSON...');
        result = jsonDecode(fixedJson);
        print('DEBUG: Fixed JSON parsing successful');
      } catch (e2) {
        print('DEBUG: Fixed JSON also failed: $e2');
        return {
          'Error': 'Ошибка парсинга JSON от AI модели. Попробуйте еще раз.'
        };
      }
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

    // Проверяем, что это действительно чек (есть основные поля)
    if (result['name_seller'] == null ||
        result['name_seller'].toString().isEmpty) {
      print('DEBUG: WARNING: Missing seller name, may not be a valid receipt');
    }

    if (result['total_sum'] == null || result['total_sum'] == 0) {
      print(
          'DEBUG: WARNING: Missing or zero total sum, may not be a valid receipt');
    }

    // Проверяем и исправляем цены товаров
    print('DEBUG: === PRICE VALIDATION AND FIX ===');
    int fixedPrices = 0;
    int invalidItems = 0;
    for (int i = 0; i < (result['items'] as List).length; i++) {
      var item = (result['items'] as List)[i];
      if (item is Map) {
        double quantity = _safeParseDouble(item['quantity'] ?? 0);
        double amount = _safeParseDouble(item['amount'] ?? 0);
        double price = _safeParseDouble(item['price'] ?? 0);

        // Проверяем валидность данных
        if (quantity <= 0 || amount <= 0) {
          print(
              'DEBUG: WARNING - Item $i has invalid quantity or amount: quantity=$quantity, amount=$amount');
          invalidItems++;
          continue;
        }

        // Проверяем, правильно ли вычислена цена
        double calculatedPrice = amount / quantity;
        double priceDifference = (price - calculatedPrice).abs();

        // Если разница в цене больше 1 рубля, пересчитываем
        if (priceDifference > 1.0) {
          print(
              'DEBUG: Fixing price for item $i: original=$price, calculated=$calculatedPrice');
          item['price'] = double.parse(calculatedPrice.toStringAsFixed(3));
          fixedPrices++;
        }

        // Проверяем разумность цены (не должна быть слишком высокой или низкой)
        if (calculatedPrice > 10000) {
          print(
              'DEBUG: WARNING - Item $i has suspiciously high price: $calculatedPrice');
        }
        if (calculatedPrice < 0.01 && amount > 1) {
          print(
              'DEBUG: WARNING - Item $i has suspiciously low price: $calculatedPrice');
        }
      }
    }
    if (fixedPrices > 0) {
      print('DEBUG: Fixed prices for $fixedPrices items');
    }
    if (invalidItems > 0) {
      print('DEBUG: Found $invalidItems items with invalid data');
    }
    print('DEBUG: === END PRICE VALIDATION ===');

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
      'items': result['items'] ?? [],
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

    if ((finalResult['items'] as List).isEmpty) {
      print('DEBUG: ERROR: items list is empty');
      return {'Error': 'Не удалось распознать товары в чеке'};
    }

    // Проверка количества товаров
    final itemsCount = (finalResult['items'] as List).length;
    print('DEBUG: Extracted $itemsCount items from receipt');
    if (itemsCount < 5) {
      print(
          'DEBUG: WARNING: Very few items extracted ($itemsCount), may be incomplete');
    }

    // Дополнительная валидация данных
    print('DEBUG: === DATA VALIDATION ===');

    // Проверяем названия товаров и добавляем fallback названия для пустых
    int emptyNames = 0;
    int shortNames = 0;
    for (int i = 0; i < (finalResult['items'] as List).length; i++) {
      var item = (finalResult['items'] as List)[i];
      if (item is Map) {
        String productName = '';
        if (item.containsKey('product_name')) {
          productName = item['product_name']?.toString() ?? '';
        } else if (item.containsKey('name')) {
          productName = item['name']?.toString() ?? '';
        }

        if (productName.isEmpty) {
          emptyNames++;
          print(
              'DEBUG: WARNING: Item $i has empty product name, adding fallback');

          // Генерируем fallback название на основе категории и цены
          String category = item['category']?.toString() ?? 'Товар';
          double price = _safeParseDouble(item['price']);
          double amount = _safeParseDouble(item['amount']);

          String fallbackName =
              _generateFallbackProductName(category, price, amount, i + 1);

          // Обновляем название товара
          if (item.containsKey('product_name')) {
            item['product_name'] = fallbackName;
          } else if (item.containsKey('name')) {
            item['name'] = fallbackName;
          } else {
            item['product_name'] = fallbackName;
          }

          print('DEBUG: Added fallback name: "$fallbackName" for item $i');
        } else if (productName.length < 3) {
          shortNames++;
          print(
              'DEBUG: WARNING: Item $i has very short product name: "$productName"');
        }
      }
    }

    if (emptyNames > 0) {
      print(
          'DEBUG: Fixed $emptyNames items with empty product names using fallbacks');
    }
    if (shortNames > 0) {
      print(
          'DEBUG: WARNING: Found $shortNames items with very short product names');
    }

    // Проверяем суммы
    double calculatedTotal = 0.0;
    for (int i = 0; i < (finalResult['items'] as List).length; i++) {
      var item = (finalResult['items'] as List)[i];
      if (item is Map) {
        double amount = 0.0;
        if (item.containsKey('amount')) {
          amount = _safeParseDouble(item['amount']);
        }
        calculatedTotal += amount;
      }
    }

    double expectedTotal = _safeParseDouble(finalResult['total_sum']);
    double difference = (calculatedTotal - expectedTotal).abs();

    print('DEBUG: Expected total: $expectedTotal');
    print('DEBUG: Calculated total from items: $calculatedTotal');
    print('DEBUG: Difference: $difference');

    // Более толерантная проверка разницы в суммах
    double tolerance = expectedTotal * 0.05; // 5% от общей суммы
    if (tolerance < 1.0) tolerance = 1.0; // Минимум 1 рубль
    if (tolerance > 10.0) tolerance = 10.0; // Максимум 10 рублей

    if (difference > tolerance) {
      print(
          'DEBUG: WARNING: Total sum mismatch! Difference: $difference, Tolerance: $tolerance');
      if (difference > 50.0) {
        print(
            'DEBUG: ERROR: Large total sum mismatch! Difference: $difference');
        return {
          'Error':
              'Суммы в чеке не сходятся (разница: ${difference.toStringAsFixed(2)} руб). Возможно, AI модель пропустила некоторые товары или неправильно распознала цены. Попробуйте еще раз или убедитесь, что чек хорошо освещен и все данные читаемы. Если проблема повторяется, попробуйте сфотографировать чек при лучшем освещении.'
        };
      }
    }

    print('DEBUG: === END DATA VALIDATION ===');

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

/// Упрощенная версия обработки с более простым промптом
Future<Map<String, dynamic>> _processWithModelInternalSimplified(
    String imageData, String modelName) async {
  try {
    // Определяем, является ли imageData путем к файлу или base64 строкой
    bool isBase64Data = imageData.startsWith('data:image/');
    print('DEBUG: Simplified processing - isBase64Data: $isBase64Data');
    print('DEBUG: Using model: $modelName');

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

    // Упрощенный промпт для лучшего распознавания
    final requestBody = {
      "model": modelName,
      "messages": [
        {
          "role": "system",
          "content":
              "Извлеките данные с кассового чека в JSON формате. Структура: {\"name_seller\":\"название магазина\",\"items\":[{\"product_name\":\"название товара\",\"quantity\":количество,\"amount\":сумма,\"price\":цена за единицу}],\"total_sum\":общая сумма,\"receipt_date\":\"дата\",\"number_receipt\":номер чека,\"nds10\":НДС 10%,\"nds20\":НДС 20%}. ВАЖНО: quantity - количество из колонки 'КОЛ-ВО', amount - сумма из колонки 'СУММА, Р', price = amount ÷ quantity."
        },
        {
          "role": "user",
          "content": [
            {
              "type": "text",
              "text":
                  "Извлеките все данные с чека в JSON формате. Внимательно различайте количество и сумму."
            },
            {
              "type": "image_url",
              "image_url": {
                "url": "data:image/jpeg;base64,$base64Image",
                "detail": "high"
              }
            }
          ]
        }
      ],
      "temperature": 0.1,
      "max_tokens": 4096
    };

    // Отправляем запрос к GitHub AI API
    print('DEBUG: Sending simplified request to GitHub AI API');
    Response response = await apiService.postToGithubAI(
      AppConstants.receiptsParseImageEndpoint,
      requestBody,
    );

    if (response.statusCode != 200) {
      return {'Error': 'Ошибка GitHub AI API: ${response.statusCode}'};
    }

    // Обрабатываем ответ
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

    // Извлекаем JSON из ответа
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

    // Парсим JSON
    Map<String, dynamic> result;
    try {
      result = jsonDecode(jsonString);
    } catch (e) {
      return {'Error': 'Ошибка парсинга JSON от AI модели'};
    }

    // Применяем ту же логику валидации и исправления
    if (result.containsKey('receipt_date')) {
      result['receipt_date'] =
          convertToIsoDate(result['receipt_date']?.toString());
    }

    // Проверяем и исправляем цены
    if (result['items'] != null && result['items'] is List) {
      for (var item in result['items']) {
        if (item is Map) {
          double quantity = _safeParseDouble(item['quantity'] ?? 0);
          double amount = _safeParseDouble(item['amount'] ?? 0);

          if (quantity > 0 && amount > 0) {
            double calculatedPrice = amount / quantity;
            item['price'] = double.parse(calculatedPrice.toStringAsFixed(3));
          }
        }
      }
    }

    // Формируем результат
    final finalResult = {
      'name_seller': result['name_seller']?.toString() ?? '',
      'retail_place_address': result['retail_place_address']?.toString() ?? '',
      'retail_place': result['retail_place']?.toString() ?? '',
      'items': result['items'] ?? [],
      'total_sum': _safeParseDouble(result['total_sum']),
      'receipt_date': result['receipt_date']?.toString(),
      'number_receipt': _safeParseInt(result['number_receipt']),
      'nds10': _safeParseDouble(result['nds10']),
      'nds20': _safeParseDouble(result['nds20']),
      'operation_type': _safeParseInt(result['operation_type']) == 0
          ? 1
          : _safeParseInt(result['operation_type']),
    };

    return finalResult;
  } catch (e) {
    print('DEBUG: Exception in simplified processing: $e');
    return {'Error': 'Ошибка упрощенной обработки: $e'};
  }
}

/// Конвертирует дату в ISO формат
String convertToIsoDate(String? dateString) {
  if (dateString == null || dateString.isEmpty) {
    return DateTime.now().toIso8601String();
  }

  try {
    // Парсим дату из формата DD.MM.YYYY HH:MM
    final parts = dateString.split(' ');
    if (parts.length == 2) {
      final dateParts = parts[0].split('.');
      final timeParts = parts[1].split(':');

      if (dateParts.length == 3 && timeParts.length >= 2) {
        final day = dateParts[0].padLeft(2, '0');
        final month = dateParts[1].padLeft(2, '0');
        final year = dateParts[2];
        final hour = timeParts[0].padLeft(2, '0');
        final minute = timeParts[1].padLeft(2, '0');
        final second =
            timeParts.length > 2 ? timeParts[2].padLeft(2, '0') : '00';

        // Преобразуем в YYYY-MM-DDTHH:MM:SS
        return '$year-$month-${day}T$hour:$minute:$second';
      }
    } else if (dateString.contains('.')) {
      // Парсим только дату DD.MM.YYYY
      final dateParts = dateString.split('.');
      if (dateParts.length == 3) {
        final day = dateParts[0].padLeft(2, '0');
        final month = dateParts[1].padLeft(2, '0');
        final year = dateParts[2];
        return '$year-$month-${day}T00:00:00';
      }
    }
  } catch (e) {
    print('DEBUG: Error converting date format: $e');
  }

  // Если не удалось преобразовать, используем текущую дату
  return DateTime.now().toIso8601String();
}

/// Генерирует fallback название товара на основе категории, цены и номера
String _generateFallbackProductName(
    String category, double price, double amount, int itemNumber) {
  // Базовые названия для разных категорий
  Map<String, List<String>> categoryNames = {
    'Продукты': [
      'Продукт питания',
      'Продукт',
      'Еда',
      'Продукт питания',
      'Продукт',
    ],
    'Бытовая химия': [
      'Средство бытовой химии',
      'Бытовая химия',
      'Средство',
      'Химия',
      'Бытовая химия',
    ],
    'Другое': [
      'Товар',
      'Изделие',
      'Продукт',
      'Товар',
      'Изделие',
    ],
  };

  // Получаем список названий для категории
  List<String> names = categoryNames[category] ?? categoryNames['Другое']!;

  // Выбираем название на основе номера товара
  String baseName = names[itemNumber % names.length];

  // Добавляем информацию о цене, если она есть
  if (price > 0) {
    if (price < 50) {
      baseName += ' (дешевый)';
    } else if (price > 200) {
      baseName += ' (дорогой)';
    }
  }

  // Добавляем номер товара для уникальности
  baseName += ' №$itemNumber';

  return baseName;
}
