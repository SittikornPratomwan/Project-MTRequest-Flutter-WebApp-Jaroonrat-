import 'package:flutter/material.dart';
import 'Authen/authen.dart';

/// Application entry point. The login page decides the next navigation flow.
void main() {
  runApp(const MyApp());
}

/// Root app shell used by the production app.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: const Authen());
  }
}
