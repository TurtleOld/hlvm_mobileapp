import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация Talker
  final talkerService = TalkerService();
  talkerService.initialize();

  final bool isLoggedIn = await checkLoggedIn();
  await dotenv.load(fileName: ".env");
  runApp(MyApp(
    isLoggedIn: isLoggedIn,
    talkerService: talkerService,
  ));
}

Future<bool> checkLoggedIn() async {
  final storage = const FlutterSecureStorage();
  final isLoggedIn = await storage.read(key: 'isLoggedIn');
  final accessToken = await storage.read(key: 'access_token');
  final refreshToken = await storage.read(key: 'refresh_token');
  return isLoggedIn == 'true' && accessToken != null && refreshToken != null;
}

class MyApp extends StatefulWidget {
  final bool isLoggedIn;
  final TalkerService talkerService;

  const MyApp({
    super.key,
    required this.isLoggedIn,
    required this.talkerService,
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
            authService: AuthService(),
            talkerBloc: context.read<TalkerBloc>(),
          )..add(CheckAuthStatus()),
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
          ),
        ),
      ],
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

  // Список страниц
  static const List<Widget> _pages = <Widget>[
    FinanceAccountScreen(),
    ReceiptScreen(),
    GithubTokenSettingsScreen(),
  ];

  // Обработчик нажатия на элемент BottomNavigationBar
  void _onItemTapped(int index) async {
    if (index == 3) {
      context.read<AuthBloc>().add(LogoutRequested());
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
