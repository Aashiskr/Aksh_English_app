import 'package:flutter/material.dart';
import 'screens/home_screen.dart'; // Ensure path is correct

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aksh AI Tutor',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
      ),
      // Yahan hum HomeScreen bula rahe hain (ChatScreen nahi)
      home: const HomeScreen(),
    );
  }
}