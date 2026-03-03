import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';

class SubjectScreen extends StatefulWidget {
  final String grade;
  const SubjectScreen({Key? key, required this.grade}) : super(key: key);

  @override
  State<SubjectScreen> createState() => _SubjectScreenState();
}

class _SubjectScreenState extends State<SubjectScreen> {
  final ApiService _api = ApiService();
  late Future<List<String>> _subjectsFuture;

  @override
  void initState() {
    super.initState();
    _subjectsFuture = _api.getSubjects(widget.grade);
  }

  static const _subjectMeta = {
    'Science':        {'icon': Icons.science,  'color': Color(0xFF4CAF50)},
    'Maths':          {'icon': Icons.calculate, 'color': Color(0xFF2196F3)},
    'English':        {'icon': Icons.menu_book, 'color': Color(0xFF9C27B0)},
    'Social_Science': {'icon': Icons.public,    'color': Color(0xFFFF9800)},
  };

  String _label(String key) => key.replaceAll('_', ' ');
  IconData _icon(String s)  =>
      (_subjectMeta[s]?['icon'] as IconData?) ?? Icons.book;
  Color _color(String s)    =>
      (_subjectMeta[s]?['color'] as Color?) ?? Colors.blue;

  String _gradeLabel(String g) =>
      g.replaceAll('Grade', 'Grade ');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_gradeLabel(widget.grade)} — Choose Subject'),
        backgroundColor: Colors.blue,
      ),
      body: FutureBuilder<List<String>>(
        future: _subjectsFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                onPressed: () => setState(() {
                  _subjectsFuture = _api.getSubjects(widget.grade);
                }),
              ),
            );
          }

          final subjects = snap.data ?? [];

          return GridView.builder(
            padding: const EdgeInsets.all(24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: 1.0,
            ),
            itemCount: subjects.length,
            itemBuilder: (context, index) {
              final subject = subjects[index];
              return _SubjectCard(
                label: _label(subject),
                icon:  _icon(subject),
                color: _color(subject),
                // Tap goes DIRECTLY to ChatScreen — no chapter selection
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      grade:   widget.grade,
                      subject: subject,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SubjectCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.6), color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 56, color: Colors.white),
              const SizedBox(height: 14),
              Text(
                label,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
