import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hlvm_mobileapp/features/auth/view/authentication_screen.dart';
import 'package:hlvm_mobileapp/features/finance_account/view/view.dart';
import 'package:hlvm_mobileapp/features/receipts/view/view.dart';
import 'package:hlvm_mobileapp/features/auth/view/github_token_settings_screen.dart';
import 'package:hlvm_mobileapp/services/authentication.dart';
import 'package:hlvm_mobileapp/services/api.dart';
import 'package:hlvm_mobileapp/core/theme/app_theme.dart';
import 'package:hlvm_mobileapp/features/auth/bloc/bloc.dart';
import 'package:hlvm_mobileapp/features/finance_account/bloc/bloc.dart';
import 'package:hlvm_mobileapp/features/receipts/bloc/bloc.dart';
import 'package:hlvm_mobileapp/core/services/talker_service.dart';
import 'package:hlvm_mobileapp/core/bloc/talker_bloc.dart';
import 'package:hlvm_mobileapp/core/widgets/talker_notification_widget.dart';
import 'package:hlvm_mobileapp/core/utils/global_error_handler.dart';


import 'package:hlvm_mobileapp/core/services/cache_service.dart';
import 'package:hlvm_mobileapp/core/services/app_startup_service.dart';
import 'package:hlvm_mobileapp/core/services/security_manager_service.dart';
import 'package:hlvm_mobileapp/core/services/server_settings_service.dart';
import 'package:hlvm_mobileapp/core/utils/logger.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Показываем splash screen
    runApp(const SplashScreen());

    // Запускаем инициализацию сервисов в фоне
    _initializeServices();
  } catch (e) {
    // В случае критической ошибки показываем fallback приложение
    runApp(const FallbackApp());
  }
}

Future<void> _initializeServices() async {
  try {
    // Инициализируем TalkerService
    final talkerService = TalkerService();
    talkerService.initialize();

    // Инициализируем SecurityManagerService
    final securityManager = SecurityManagerService();
    await securityManager.initializeSecurity();

    // Инициализируем AuthService
    final authService = AuthService();

    // Настраиваем обработчик ошибок
    try {
      GlobalErrorHandler.setupDioErrorHandler(authService.dio);
    } catch (e) {
      // Игнорируем ошибки настройки обработчика ошибок
    }

    // Инициализируем CacheService
    try {
      CacheService();
      // CacheService инициализируется автоматически в конструкторе
    } catch (e) {
      // Игнорируем ошибки инициализации кеша
    }

    // Очищаем некорректные настройки сервера
    try {
      final serverSettings = ServerSettingsService();
      await serverSettings.clearInvalidSettings();

      // Проверяем корректность оставшихся настроек
      final isValid = await serverSettings.validateAllSettings();
      if (!isValid) {
        AppLogger.warning(
            'Some server settings are still invalid after cleanup');
      }
    } catch (e) {
      // Игнорируем ошибки очистки настроек
    }

    // Инициализируем AppStartupService с таймаутом
    try {
      final appStartupService = AppStartupService(cacheService: CacheService());
      await appStartupService.initializeApp().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          // В случае таймаута продолжаем работу
          return;
        },
      );
    } catch (e) {
      // Игнорируем ошибки инициализации startup сервиса
    }

    // Настраиваем карту сервисов
    _services = {
      'talker': talkerService,
      'security': securityManager,
      'auth': authService,
      'cache': CacheService(),
      'startup': AppStartupService(cacheService: CacheService()),
    };

    // Очищаем некорректные настройки в API сервисах
    try {
      final apiService = ApiService();
      await apiService.clearInvalidServerSettings();
    } catch (e) {
      // Игнорируем ошибки очистки настроек
    }
  } catch (e) {
    // В случае ошибки инициализации сервисов продолжаем работу
  }
}

// Глобальная переменная для хранения сервисов
Map<String, dynamic> _services = {};

Future<Widget> _createMainApp() async {
  try {
    if (_services.isNotEmpty) {
      return MyApp(
        isLoggedIn: _services['isLoggedIn'] ?? false,
        isAppBlocked: _services['isAppBlocked'] ?? false,
        talkerService: _services['talkerService'] ?? TalkerService(),
        authService: _services['authService'] ?? AuthService(),

        cacheService: _services['cacheService'] ?? CacheService(),
        securityManager:
            _services['securityManager'] ?? SecurityManagerService(),
      );
    } else {
      // Если сервисы не инициализированы, возвращаем приложение с базовыми сервисами
      return MyApp(
        isLoggedIn: false,
        isAppBlocked: false,
        talkerService: TalkerService(),
        authService: AuthService(),

        cacheService: CacheService(),
        securityManager: SecurityManagerService(),
      );
    }
  } catch (e) {
    // В случае ошибки возвращаем приложение с базовыми сервисами
    return MyApp(
      isLoggedIn: false,
      isAppBlocked: false,
      talkerService: TalkerService(),
      authService: AuthService(),
      
      cacheService: CacheService(),
      securityManager: SecurityManagerService(),
    );
  }
}

Future<bool> checkLoggedIn() async {
  try {
    const storage = FlutterSecureStorage();
    final isLoggedIn = await storage.read(key: 'isLoggedIn');
    final accessToken = await storage.read(key: 'access_token');
    final refreshToken = await storage.read(key: 'refresh_token');

    final result =
        isLoggedIn == 'true' && accessToken != null && refreshToken != null;
    return result;
  } catch (e) {
    return false;
  }
}

// Экран загрузки
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  bool _isInitializationComplete = false;
  String _statusText = 'Инициализация...';
  Timer? _statusTimer;
  Timer? _timeoutTimer;
  late DateTime _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
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

    // Запускаем таймер для обновления статуса
    _startStatusUpdates();

    // Запускаем таймер для проверки инициализации
    _startInitializationCheck();

    // Устанавливаем таймаут на 15 секунд
    _timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && !_isInitializationComplete) {
        _forceTransitionToMainApp();
      }
    });
  }

  void _startStatusUpdates() {
    _statusTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (mounted && !_isInitializationComplete) {
        _updateStatusText();

        // Дополнительная проверка на зависание
        if (DateTime.now().difference(_startTime).inSeconds > 20) {
          timer.cancel();
          if (mounted) {
            _forceTransitionToMainApp();
          }
        }
      } else {
        timer.cancel();
      }
    });
  }

  void _startInitializationCheck() {
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      try {
        // Проверяем, есть ли сервисы и не завершена ли инициализация
        if (_services.isNotEmpty && !_isInitializationComplete) {
          timer.cancel();
          _isInitializationComplete = true;
          _transitionToMainApp();
        }

        // Добавляем дополнительную проверку на таймаут
        // Если прошло больше 10 секунд и сервисы не инициализированы,
        // переходим к основному приложению
        if (!_isInitializationComplete &&
            DateTime.now().difference(_startTime).inSeconds > 10) {
          timer.cancel();
          _isInitializationComplete = true;
          _transitionToMainApp();
        }
      } catch (e) {
        if (mounted) {
          _showFallbackApp();
        }
      }
    });
  }

  void _forceTransitionToMainApp() {
    try {
      if (mounted) {
        _isInitializationComplete = true;
        _transitionToMainApp();
      }
    } catch (e) {
      if (mounted) {
        _showFallbackApp();
      }
    }
  }

  void _transitionToMainApp() async {
    if (mounted) {
      try {
        final mainApp = await _createMainApp();
        if (mounted) {
          runApp(mainApp);
        }
      } catch (e) {
        if (mounted) {
          _showFallbackApp();
        }
      }
    }
  }

  void _showFallbackApp() {
    try {
      final fallbackApp = MyApp(
        isLoggedIn: false,
        isAppBlocked: false,
        talkerService: TalkerService(),
        authService: AuthService(),

        cacheService: CacheService(),
        securityManager: SecurityManagerService(),
      );
      runApp(fallbackApp);
    } catch (e) {
      // В случае критической ошибки показываем простой fallback
      runApp(const FallbackApp());
    }
  }

  void _updateStatusText() {
    try {
      if (mounted) {
        setState(() {
          _statusText = 'Инициализация...';
        });
      }
    } catch (e) {
      // Игнорируем ошибки обновления статуса
    }
  }

  @override
  void dispose() {
    try {
      _animationController.dispose();
      _pulseController.dispose();
      _statusTimer?.cancel();
      _timeoutTimer?.cancel();
      super.dispose();
    } catch (e) {
      // Игнорируем ошибки при dispose
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      return MaterialApp(
        title: 'HLVM Mobile App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Логотип или иконка
                  AnimatedBuilder(
                    animation: _scaleAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(60),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(red: &.red, green: &.green, blue: &.blue, alpha: 77),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.security,
                            size: 60,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                  // Текст статуса
                  AnimatedBuilder(
                    animation: _fadeAnimation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _fadeAnimation.value,
                        child: Text(
                          _statusText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  // Индикатор загрузки
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _pulseAnimation.value.clamp(0.0, 1.0),
                        child: const SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 3,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      // В случае ошибки показываем простой fallback
      return const FallbackApp();
    }
  }
}

class MyApp extends StatefulWidget {
  final bool isLoggedIn;
  final bool isAppBlocked;
  final TalkerService talkerService;
  final AuthService authService;
  final CacheService cacheService;
  final SecurityManagerService securityManager;

  const MyApp({
    super.key,
    required this.isLoggedIn,
    required this.isAppBlocked,
    required this.talkerService,
    required this.authService,
    required this.cacheService,
    required this.securityManager,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    // Приложение больше не может быть заблокировано
    return MultiBlocProvider(
      providers: [
        BlocProvider<TalkerBloc>(
          create: (context) => TalkerBloc(
            talkerService: widget.talkerService,
          ),
        ),
        BlocProvider<AuthBloc>(
          create: (context) {
            final talkerBloc = context.read<TalkerBloc>();
            return AuthBloc(
              authService: widget.authService,
              talkerBloc: talkerBloc,
            )..add(const CheckAuthStatus());
          },
        ),
        BlocProvider<FinanceAccountBloc>(
          create: (context) => FinanceAccountBloc(
            apiService: ApiService(),
            talkerBloc: context.read<TalkerBloc>(),
          ),
        ),
        BlocProvider<ReceiptBloc>(
          create: (context) => ReceiptBloc(
            apiService: ApiService(),
            talkerBloc: context.read<TalkerBloc>(),
            cacheService: widget.cacheService,
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const AuthWrapper(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomePage(),
          '/uploadFile': (context) => const FileReaderScreen(),
          '/image_capture': (context) => const ImageCaptureScreen(),
        },
        builder: (context, child) {
          return Stack(
            children: [
              child!,
              const TalkerNotificationWidget(),
            ],
          );
        },
      ),
    );
  }
}

// Виджет для определения экрана на основе состояния авторизации
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        // print('AuthWrapper: State changed to ${state.runtimeType}');
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          // Добавляем отладочную информацию
          // print('AuthWrapper: Current state is ${state.runtimeType}');
          
          if (state is AuthLoading) {
            return const Scaffold(
              backgroundColor: AppTheme.backgroundColor,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Проверка авторизации...',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else if (state is AuthAuthenticated) {
            print('AuthWrapper: User is authenticated, showing HomePage');
            return const HomePage();
          } else if (state is AuthError) {
            // print('AuthWrapper: Auth error, showing LoginScreen');
            // При ошибке показываем экран входа, но с сообщением об ошибке
            return const LoginScreen();
          } else {
            // print('AuthWrapper: User is not authenticated, showing LoginScreen');
            return const LoginScreen();
          }
        },
      ),
    );
  }
}

// Экран блокировки приложения больше не нужен

class HomePage extends StatefulWidget {
  final int selectedIndex;
  const HomePage({super.key, this.selectedIndex = 0});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedIndex;
  }

  static const List<Widget> _pages = <Widget>[
    FinanceAccountScreen(),
    ReceiptScreen(),
    GithubTokenSettingsScreen(),
  ];

  void _onItemTapped(int index) async {
    if (index == 3) {
      context.read<AuthBloc>().add(LogoutRequested(context: context));
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.credit_score),
            label: 'Счета',
            backgroundColor: Colors.green,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt),
            label: 'Чеки',
            backgroundColor: Colors.green,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Настройки',
            backgroundColor: Colors.green,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.logout),
            label: 'Выход',
            backgroundColor: Colors.green,
          )
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

// Fallback приложение для случаев критических ошибок
class FallbackApp extends StatelessWidget {
  const FallbackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HLVM Mobile',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const FallbackScreen(),
    );
  }
}

// Fallback экран для случаев критических ошибок
class FallbackScreen extends StatelessWidget {
  const FallbackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline,
                  size: 60,
                  color: Colors.red.shade600,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Ошибка инициализации',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Произошла ошибка при запуске приложения. Попробуйте перезапустить.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.red.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  // Перезапускаем приложение
                  Navigator.of(context).pushReplacementNamed('/');
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Перезапустить'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
