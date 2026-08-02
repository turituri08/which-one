import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: WhichOneApp()));
}

class WhichOneApp extends StatelessWidget {
  const WhichOneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'どっち',
      home: const Scaffold(body: Center(child: Text('どっち'))),
    );
  }
}
