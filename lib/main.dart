import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const AnichinApp());
}

class AnichinApp extends StatelessWidget {
  const AnichinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anichin App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.red,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const HomeScreen(),
    );
  }
}
