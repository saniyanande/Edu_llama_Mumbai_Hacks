import 'package:flutter/material.dart';
import 'screens/chapters_screen.dart';

void main() {
  runApp(ScienceTutorApp());
}

class ScienceTutorApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Science Tutor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      home: ChaptersScreen(),
    );
  }
}