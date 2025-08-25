import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hlvm_mobileapp/services/api.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hlvm_mobileapp/core/services/session_provider.dart';
import 'package:hlvm_mobileapp/features/auth/view/settings_screen.dart';
import 'package:hlvm_mobileapp/main.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hlvm_mobileapp/core/theme/app_theme.dart';
import 'package:hlvm_mobileapp/core/utils/logger.dart';
import 'package:hlvm_mobileapp/core/services/server_settings_service.dart';

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
      // SessionManager будет получен из контекста при необходимости
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
      if (!SessionProvider.hasSessionProvider(currentContext)) {
        // Если SessionProvider недоступен, используем прямую проверку
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
        final Map<String, dynamic> jsonData =
            await getJsonReceipt(dataUrl).timeout(timeoutDuration);
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
                // Fallback: показываем диалог истечения сессии
                _showSessionExpiredDialog(currentContext);
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

        // Создаем чек с таймаутом
        await _apiService.createReceipt(jsonData).timeout(timeoutDuration);

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Произошла ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
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

Future<Map<String, dynamic>> getJsonReceipt(String imagePath) async {
  try {
    // Проверяем наличие access token
    const storage = FlutterSecureStorage();
    final accessToken = await storage.read(key: 'access_token');

    if (accessToken == null) {
      return {'Error': 'Access token не найден'};
    }

    // Проверяем настройки сервера
    final serverSettings = ServerSettingsService();
    final serverAddress = await serverSettings.getServerAddress();

    if (serverAddress == null || serverAddress.isEmpty) {
      return {'Error': 'Адрес сервера не настроен'};
    }

    // Проверяем GitHub API токен
    final githubToken = await storage.read(key: 'github_token');

    if (githubToken == null || githubToken.isEmpty) {
      return {'Error': 'GitHub API токен не настроен'};
    }

    // Создаем FormData для отправки
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(imagePath),
      'github_token': githubToken,
    });

    // Отправляем запрос к ИИ сервису
    final response = await Dio().post(
      '$serverAddress/api/ai/parse_receipt',
      data: formData,
      options: Options(
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'multipart/form-data',
        },
      ),
    );

    if (response.statusCode != 200) {
      return {'Error': 'Ошибка сервера: ${response.statusCode}'};
    }

    final rawResponse = response.data.toString();
    final cleanedResponse =
        rawResponse.replaceAll('```json', '').replaceAll('```', '').trim();

    final result = jsonDecode(cleanedResponse);

    // Проверяем обязательные поля
    if (result is Map<String, dynamic> && result.containsKey('receipt_date')) {
      result['receipt_date'] =
          convertToIsoDate(result['receipt_date']?.toString());
    }

    // Валидация данных
    if (result is Map<String, dynamic>) {
      // Проверяем total_sum
      if (result['total_sum'] == null) {
        return {'Error': 'Missing required data: total_sum'};
      }

      // Проверяем items
      if (result['items'] == null || result['items'].isEmpty) {
        return {'Error': 'Missing required data: items'};
      }

      // Проверяем receipt_date
      if (result['receipt_date'] == null) {
        return {'Error': 'Missing required data: receipt_date'};
      }

      // Формируем результат
      return {
        'name_seller': result['name_seller'],
        'retail_place_address': result['retail_place_address'],
        'retail_place': result['retail_place'],
        'product': result['items'],
        'total_sum': result['total_sum'],
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
      };
    }

    return result;
  } catch (e) {
    return {'Error': 'Ошибка при обработке: $e'};
  }
}
