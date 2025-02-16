import 'package:flutter/material.dart';

class FinanceAccountScreen extends StatefulWidget {
  const FinanceAccountScreen({super.key});

  @override
  State<FinanceAccountScreen> createState() => _FinanceAccountScreenState();
}

class _FinanceAccountScreenState extends State<FinanceAccountScreen> {

  final List<String> _accountList = [
    "Счет 1",
    "Счет 2",
    "Счет 3",
    "Счет 4",
    "Счет 5",
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Список счетов', style: TextStyle(color: Colors.white),),
          backgroundColor: Colors.green,
          centerTitle: true,
        ),
    );
  }
}