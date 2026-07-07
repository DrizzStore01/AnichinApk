import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const AnichinApp());
}

class AnichinApp extends StatelessWidget {
  const AnichinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anichin Beta',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const HomeScreen(),
    );
  }
}
