import 'package:flutter/material.dart';

class FinanceAccountScreen extends StatefulWidget {
  const FinanceAccountScreen({super.key});

  @override
  State<FinanceAccountScreen> createState() => _FinanceAccountScreenState();
}

class _FinanceAccountScreenState extends State<FinanceAccountScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Список счетов', style: TextStyle(color: Colors.green),),
        centerTitle: true,
      )
    );
  }
}