import 'package:flutter/material.dart';

// We will create this file in the next step!
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const GuardianApp());
}

class GuardianApp extends StatelessWidget {
  const GuardianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guardian Safety',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      // For now, the app boots directly to the Login Screen
      home: const SplashScreen(),
    );
  }
}