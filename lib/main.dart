import 'package:flutter/material.dart';
import 'screens/grade_screen.dart';

void main() {
  runApp(const EduLlamaApp());
}

class EduLlamaApp extends StatelessWidget {
  const EduLlamaApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduLlama',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
      ),
      home: const GradeScreen(),
    );
  }
}