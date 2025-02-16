import 'package:flutter/material.dart';

class FinanceAccountScreen extends StatefulWidget {
  const FinanceAccountScreen({super.key});

  @override
  State<FinanceAccountScreen> createState() => _FinanceAccountScreenState();
}

class _FinanceAccountScreenState extends State<FinanceAccountScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  static const List<Widget> _pages = <Widget>[
    Icon(
      Icons.credit_score,
      size: 150,
      color: Colors.green,
    ),
    Icon(
      Icons.receipt,
      size: 150,
      color: Colors.green,
    ),

  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Hasta la Vista, Money!'),
        centerTitle: true,
      ),
      body: Center(
        child: _pages.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.credit_score),
            label: 'Счета',
          ),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt),
              label: 'Чеки'
          )
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
