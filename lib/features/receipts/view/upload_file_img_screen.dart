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
    return value;
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
      return result;
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
        // Обрабатываем изображение с таймаутом
        final String dataUrl =
            await getImageDataUrl(image.path, 'jpg').timeout(timeoutDuration);
        if (!mounted) return;

        setState(() {
          _dataUrl = dataUrl;
        });

        // Получаем JSON с таймаутом
        print('DEBUG: === STARTING getJsonReceipt ===');
        final Map<String, dynamic> rawJsonData =
            await getJsonReceipt(dataUrl).timeout(timeoutDuration);
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

Future<Map<String, dynamic>> getJsonReceipt(String imageData) async {
  print(
      'DEBUG: getJsonReceipt called with imageData length: ${imageData.length}');
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
      final bytes = await file.readAsBytes();
      base64Image = base64Encode(bytes);
    }

    // Формируем запрос к GitHub AI API в соответствии с рекомендациями
    final requestBody = {
      "messages": [
        {
          "role": "system",
          "content":
              "Extract receipt data and return ONLY valid JSON. Structure: {\"name_seller\":\"string\",\"retail_place_address\":\"string\",\"retail_place\":\"string\",\"items\":[{\"name\":\"string\",\"price\":number,\"quantity\":number,\"category\":\"string\"}],\"total_sum\":number,\"receipt_date\":\"string\",\"number_receipt\":number,\"nds10\":number,\"nds20\":number,\"operation_type\":1}. Extract MAXIMUM 15 items to avoid token limits.\n\nCRITICAL RULES:\n1. quantity = EXACT quantity from receipt (Кол-во column)\n2. price = price per unit (цена за единицу)\n3. For weight items (вес): quantity = weight in kg, price = price per kg\n4. For regular items: quantity = number of items, price = price per item\n5. amount = quantity × price\n6. Look at 'Кол-во' column for quantity, 'Сумма' column for total amount\n7. Calculate price = amount ÷ quantity\n8. NEVER use amount as price or vice versa\n\nUse numbers, not strings. Categories: Продукты, Бытовая химия, Другое. Return ONLY JSON."
        },
        {
          "role": "user",
          "content": [
            {
              "text": "Extract receipt data and return ONLY valid JSON:",
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
      "model": "openai/gpt-4o"
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
      return {
        'Error': 'AI модель вернула невалидный JSON. Попробуйте еще раз.'
      };
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
        print('DEBUG: Cannot find closing brace, returning error');
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
    if (result['total_sum'] == null) {
      print('DEBUG: ERROR: total_sum is null');
      return {'Error': 'Missing required data: total_sum'};
    }

    // Проверяем items
    if (result['items'] == null || result['items'].isEmpty) {
      print('DEBUG: ERROR: items is null or empty: ${result['items']}');
      return {'Error': 'Missing required data: items'};
    }

    // Проверяем receipt_date
    if (result['receipt_date'] == null) {
      print('DEBUG: ERROR: receipt_date is null');
      return {'Error': 'Missing required data: receipt_date'};
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
      'operation_type': _safeParseInt(result['operation_type']),
    };

    print('DEBUG: === FINAL PROCESSED JSON ===');
    print('DEBUG: Final result: $finalResult');
    print('DEBUG: === END FINAL PROCESSED JSON ===');

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
