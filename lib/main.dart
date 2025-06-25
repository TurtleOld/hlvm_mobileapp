import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hlvm_mobileapp/features/auth/view/authentication_screen.dart';
import 'package:hlvm_mobileapp/features/finance_account/view/view.dart';
import 'package:hlvm_mobileapp/features/receipts/view/view.dart';
import 'package:hlvm_mobileapp/features/auth/view/github_token_settings_screen.dart';
import 'package:hlvm_mobileapp/services/authentication.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bool isLoggedIn = await checkLoggedIn();
  await dotenv.load(fileName: ".env");
  runApp(MyApp(
    isLoggedIn: isLoggedIn,
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

  const MyApp({super.key, required this.isLoggedIn});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: widget.isLoggedIn ? const HomePage() : const LoginScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomePage(),
        '/uploadFile': (context) => const FileReaderScreen(),
        '/image_capture': (context) => const ImageCaptureScreen(),
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  // Список страниц
  static const List<Widget> _pages = <Widget>[
    FinanceAccountScreen(),
    ReceiptScreen(),
    GithubTokenSettingsScreen(),
  ];

  // Обработчик нажатия на элемент BottomNavigationBar
  void _onItemTapped(int index) async {
    if (index == 3) {
      await AuthService().logout(context);
      Navigator.pushReplacementNamed(context, '/login');
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
