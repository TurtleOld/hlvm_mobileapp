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
import 'package:hlvm_mobileapp/core/services/session_manager.dart';
import 'package:hlvm_mobileapp/core/services/session_provider.dart';
import 'package:hlvm_mobileapp/core/services/cache_service.dart';
import 'package:hlvm_mobileapp/core/services/app_startup_service.dart';
import 'package:hlvm_mobileapp/core/services/security_manager_service.dart';
import 'package:hlvm_mobileapp/core/services/secure_http_client.dart';
import 'package:hlvm_mobileapp/core/constants/app_constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Показываем экран загрузки сразу
  runApp(const SplashScreen());

  // Инициализируем сервисы в фоне
  await _initializeServices();

  // Перезапускаем приложение с основным UI
  runApp(await _createMainApp());
}

Future<void> _initializeServices() async {
  try {
    final talkerService = TalkerService();
    talkerService.initialize();

    final securityManager = SecurityManagerService();
    await securityManager.initializeSecurity();

    final bool isLoggedIn = await checkLoggedIn();

    final authService = AuthService();
    final sessionManager = SessionManager(authService: authService);
    GlobalErrorHandler.setupDioErrorHandler(authService.dio);

    final cacheService = CacheService();
    final appStartupService = AppStartupService(cacheService: cacheService);
    await appStartupService.initializeApp();

    // Сохраняем сервисы для использования в основном приложении
    _services = {
      'isLoggedIn': isLoggedIn,
      'talkerService': talkerService,
      'authService': authService,
      'sessionManager': sessionManager,
      'cacheService': cacheService,
      'securityManager': securityManager,
    };
  } catch (e) {
    // В случае ошибки устанавливаем значения по умолчанию
    _services = {
      'isLoggedIn': false,
      'talkerService': TalkerService(),
      'authService': AuthService(),
      'sessionManager': SessionManager(authService: AuthService()),
      'cacheService': CacheService(),
      'securityManager': SecurityManagerService(),
    };
  }
}

// Глобальная переменная для хранения сервисов
Map<String, dynamic> _services = {};

Future<MyApp> _createMainApp() async {
  return MyApp(
    isLoggedIn: _services['isLoggedIn'] ?? false,
    talkerService: _services['talkerService'],
    authService: _services['authService'],
    sessionManager: _services['sessionManager'],
    cacheService: _services['cacheService'],
    securityManager: _services['securityManager'],
  );
}

Future<bool> checkLoggedIn() async {
  try {
    const storage = FlutterSecureStorage();
    final isLoggedIn = await storage.read(key: 'isLoggedIn');
    final accessToken = await storage.read(key: 'access_token');
    final refreshToken = await storage.read(key: 'refresh_token');
    return isLoggedIn == 'true' && accessToken != null && refreshToken != null;
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

  @override
  void initState() {
    super.initState();
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

    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_services.isNotEmpty && !_isInitializationComplete) {
        timer.cancel();
        _isInitializationComplete = true;
        _transitionToMainApp();
      }
    });

    Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (mounted && !_isInitializationComplete) {
        _updateStatusText();
      } else {
        timer.cancel();
      }
    });
  }

  void _transitionToMainApp() async {
    if (_services.isNotEmpty) {
      final mainApp = await _createMainApp();
      runApp(mainApp);
    }
  }

  void _updateStatusText() {
    if (mounted) {
      final statuses = [
        'Инициализация...',
        'Загрузка сервисов...',
        'Проверка безопасности...',
        'Подготовка кеша...',
        'Почти готово...',
      ];

      final currentIndex =
          DateTime.now().millisecondsSinceEpoch ~/ 1500 % statuses.length;
      setState(() {
        _statusText = statuses[currentIndex];
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
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
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.green.shade100,
                                    Colors.green.shade200
                                  ],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withValues(alpha: 0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet,
                                size: 60,
                                color: Colors.green,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        'HLVM Mobile',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _statusText,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 40),
                      const SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.green,
                          ),
                          strokeWidth: 3,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  final bool isLoggedIn;
  final TalkerService talkerService;
  final AuthService authService;
  final SessionManager sessionManager;
  final CacheService cacheService;
  final SecurityManagerService securityManager;

  const MyApp({
    super.key,
    required this.isLoggedIn,
    required this.talkerService,
    required this.authService,
    required this.sessionManager,
    required this.cacheService,
    required this.securityManager,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<TalkerBloc>(
          create: (context) => TalkerBloc(
            talkerService: widget.talkerService,
          ),
        ),
        BlocProvider<AuthBloc>(
          create: (context) => AuthBloc(
            authService: widget.authService,
            talkerBloc: context.read<TalkerBloc>(),
            sessionManager: widget.sessionManager,
            secureHttpClient: SecureHttpClient(
              sessionManager: widget.sessionManager,
            ),
          )..add(const CheckAuthStatus()),
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
      child: SessionProvider(
        sessionManager: widget.sessionManager,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: widget.isLoggedIn ? const HomePage() : const LoginScreen(),
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
      ),
    );
  }
}

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
