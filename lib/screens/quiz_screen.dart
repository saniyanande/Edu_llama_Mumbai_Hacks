import 'package:flutter/material.dart';
import '../models/quiz_models.dart';
import '../services/api_service.dart';

class QuizScreen extends StatefulWidget {
  final String chapter;
  const QuizScreen({Key? key, required this.chapter}) : super(key: key);

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final ApiService _api = ApiService();
  late Future<List<QuizQuestion>> _quizFuture;
  int _current = 0;
  int _score = 0;
  String? _selected;
  bool _answered = false;

  @override
  void initState() {
    super.initState();
    _quizFuture = _api.getQuiz(widget.chapter);
  }

  void _select(List<QuizQuestion> questions, String option) {
    if (_answered) return;
    setState(() {
      _selected = option;
      _answered = true;
      if (option.startsWith(questions[_current].answer)) _score++;
    });
  }

  void _next(List<QuizQuestion> questions) {
    if (_current < questions.length - 1) {
      setState(() {
        _current++;
        _selected = null;
        _answered = false;
      });
    } else {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Quiz Complete! 🎉'),
          content: Text('Your score: $_score / ${questions.length}'),
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Quiz — ${widget.chapter}'),
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
                ],
              ),
            );
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final questions = snap.data!;
          final q = questions[_current];

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress indicator
                LinearProgressIndicator(
                  value: (_current + 1) / questions.length,
                  backgroundColor: Colors.blue[100],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                const SizedBox(height: 16),
                Text(
                  'Question ${_current + 1} of ${questions.length}  •  Score: $_score',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Text(
                  q.question,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                // Answer options
                ...q.options.map((opt) {
                  Color bgColor = Colors.white;
                  if (_answered) {
                    if (opt.startsWith(q.answer)) bgColor = Colors.green[100]!;
                    else if (opt == _selected)    bgColor = Colors.red[100]!;
                  }
                  return GestureDetector(
                    onTap: () => _select(questions, opt),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(14),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: bgColor,
                        border: Border.all(color: Colors.blue[200]!),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(opt, style: const TextStyle(fontSize: 16)),
                    ),
                  );
                }),
                if (_answered) ...[
                  const SizedBox(height: 20),
                  // Explanation of correct answer
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
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _next(questions),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        _current < questions.length - 1
                            ? 'Next Question →'
                            : 'See Final Score',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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
