import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quiz_models.dart';
import '../services/api_service.dart';

class QuizScreen extends StatefulWidget {
  final String grade;
  final String subject;
  final String chapter;

  const QuizScreen({
    Key? key,
    required this.grade,
    required this.subject,
    required this.chapter,
  }) : super(key: key);

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final ApiService _api = ApiService();
  late Future<List<QuizQuestion>> _quizFuture;
  int _current = 0;
  int _score   = 0;
  String? _selected;
  bool _answered = false;

  // Score storage key scoped to grade + subject + chapter
  String get _scoreKey =>
      'quiz_score_${widget.grade}__${widget.subject}__${widget.chapter}';

  @override
  void initState() {
    super.initState();
    _quizFuture = _api.getQuiz(
      widget.grade,
      widget.subject,
      widget.chapter,
    );
  }

  void _select(List<QuizQuestion> questions, String option) {
    if (_answered) return;
    setState(() {
      _selected = option;
      _answered = true;
      if (option.startsWith(questions[_current].answer)) _score++;
    });
  }

  Future<void> _saveScore(int total) async {
    final prefs    = await SharedPreferences.getInstance();
    final existing = prefs.getString(_scoreKey);
    final List<Map<String, dynamic>> history = existing != null
        ? List<Map<String, dynamic>>.from(
            (json.decode(existing) as List)
                .map((e) => Map<String, dynamic>.from(e)))
        : [];

    history.add({
      'score': _score,
      'total': total,
      'date':  DateTime.now().toIso8601String(),
    });
    await prefs.setString(_scoreKey, json.encode(history));
  }

  void _next(List<QuizQuestion> questions) {
    if (_current < questions.length - 1) {
      setState(() {
        _current++;
        _selected = null;
        _answered = false;
      });
    } else {
      _saveScore(questions.length);
      final pct = (_score / questions.length * 100).toStringAsFixed(0);
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('Quiz Complete! 🎉',
              textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$_score / ${questions.length}',
                  style: const TextStyle(
                      fontSize: 40, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              Text(
                '$pct% correct',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: int.parse(pct) >= 80
                      ? Colors.green
                      : int.parse(pct) >= 50
                          ? Colors.orange
                          : Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                int.parse(pct) >= 80
                    ? 'Excellent work! 🌟'
                    : int.parse(pct) >= 50
                        ? 'Good effort! Keep practising.'
                        : "Keep studying — you'll get there!",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjectLabel = widget.subject.replaceAll('_', ' ');
    return Scaffold(
      appBar: AppBar(
        title: Text('Quiz — $subjectLabel'),
        backgroundColor: Colors.blue,
      ),
      body: FutureBuilder<List<QuizQuestion>>(
        future: _quizFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Generating quiz with AI...'),
                  SizedBox(height: 8),
                  Text('This may take up to 30 seconds.',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final questions = snap.data!;
          final q         = questions[_current];

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: (_current + 1) / questions.length,
                  backgroundColor: Colors.blue[100],
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                const SizedBox(height: 16),
                Text(
                  'Q${_current + 1} / ${questions.length}  •  Score: $_score',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Text(q.question,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                ...q.options.map((opt) {
                  Color bg = Colors.white;
                  if (_answered) {
                    if (opt.startsWith(q.answer)) bg = Colors.green[100]!;
                    else if (opt == _selected)    bg = Colors.red[100]!;
                  }
                  return GestureDetector(
                    onTap: () => _select(questions, opt),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(14),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: bg,
                        border: Border.all(color: Colors.blue[200]!),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child:
                          Text(opt, style: const TextStyle(fontSize: 16)),
                    ),
                  );
                }),
                if (_answered) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Correct answer: ${q.answer}',
                      style: TextStyle(
                          color: Colors.blue[800],
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _next(questions),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        _current < questions.length - 1
                            ? 'Next Question →'
                            : 'See Final Score',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
