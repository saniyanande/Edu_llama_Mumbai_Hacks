import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'subject_screen.dart';
import 'score_board_screen.dart';

class GradeScreen extends StatefulWidget {
  const GradeScreen({Key? key}) : super(key: key);

  @override
  State<GradeScreen> createState() => _GradeScreenState();
}

class _GradeScreenState extends State<GradeScreen> {
  final ApiService _api = ApiService();
  late Future<List<String>> _gradesFuture;

  @override
  void initState() {
    super.initState();
    _gradesFuture = _api.getGrades();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EduLlama'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard),
            tooltip: 'My Scores',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScoreBoardScreen()),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<String>>(
        future: _gradesFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Could not connect to server',
                      style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    onPressed: () =>
                        setState(() { _gradesFuture = _api.getGrades(); }),
                  ),
                ],
              ),
            );
          }

          final grades = snap.data ?? [];

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Your Grade',
                    style: TextStyle(
                        fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('NCERT — Classes 6 to 8',
                    style: TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 32),
                ...grades.map((grade) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _GradeCard(
                    grade: grade,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => SubjectScreen(grade: grade)),
                    ),
                  ),
                )),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GradeCard extends StatelessWidget {
  final String grade;
  final VoidCallback onTap;

  const _GradeCard({required this.grade, required this.onTap});

  String get _label {
    switch (grade) {
      case 'Grade6': return 'Grade 6';
      case 'Grade7': return 'Grade 7';
      case 'Grade8': return 'Grade 8';
      default:       return grade;
    }
  }

  String get _subtitle {
    switch (grade) {
      case 'Grade6': return 'Class VI';
      case 'Grade7': return 'Class VII';
      case 'Grade8': return 'Class VIII';
      default:       return '';
    }
  }

  List<Color> get _gradient {
    switch (grade) {
      case 'Grade6': return [Colors.blue[300]!,   Colors.blue[600]!];
      case 'Grade7': return [Colors.green[300]!,  Colors.green[600]!];
      case 'Grade8': return [Colors.purple[300]!, Colors.purple[600]!];
      default:       return [Colors.grey[300]!,   Colors.grey[600]!];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _gradient,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.school, size: 44, color: Colors.white),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_label,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  Text(_subtitle,
                      style: const TextStyle(
                          fontSize: 13, color: Colors.white70)),
                ],
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}
