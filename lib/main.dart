import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hlvm_mobileapp/features/auth/view/authentication_screen.dart';
import 'package:hlvm_mobileapp/features/finance_account/view/view.dart';
import 'package:hlvm_mobileapp/features/receipts/view/view.dart';
import 'package:hlvm_mobileapp/services/authentication.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bool isLoggedIn = await checkLoggedIn();
  await dotenv.load(fileName: ".env");
  runApp(MyApp(
    isLoggedIn: isLoggedIn,
  ));
}

Future<bool> checkLoggedIn() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getBool('isLoggedIn') ?? false;
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: isLoggedIn ? const HomePage() : const LoginScreen(),
      initialRoute: '/login',
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
  ];

  // Обработчик нажатия на элемент BottomNavigationBar
  void _onItemTapped(int index) async {
    if (index == 2) {
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
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt),
            label: 'Чеки',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.logout),
            label: 'Выход',
          )
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
