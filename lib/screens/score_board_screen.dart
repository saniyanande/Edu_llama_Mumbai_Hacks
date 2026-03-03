import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScoreBoardScreen extends StatefulWidget {
  const ScoreBoardScreen({Key? key}) : super(key: key);

  @override
  State<ScoreBoardScreen> createState() => _ScoreBoardScreenState();
}

class _ScoreBoardScreenState extends State<ScoreBoardScreen> {
  Map<String, List<Map<String, dynamic>>> _scores = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadScores();
  }

  Future<void> _loadScores() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('quiz_score_'));
    final Map<String, List<Map<String, dynamic>>> loaded = {};

    for (final key in keys) {
      final raw = prefs.getString(key);
      if (raw != null) {
        final chapter = key.replaceFirst('quiz_score_', '');
        loaded[chapter] = List<Map<String, dynamic>>.from(
            (json.decode(raw) as List).map((e) => Map<String, dynamic>.from(e)));
      }
    }

    setState(() {
      _scores = loaded;
      _loading = false;
    });
  }

  // Overall stats across all chapters
  int get _totalAttempts =>
      _scores.values.fold(0, (sum, list) => sum + list.length);

  int get _totalCorrect =>
      _scores.values.fold(0, (sum, list) =>
          sum + list.fold(0, (s, e) => s + (e['score'] as int)));

  int get _totalQuestions =>
      _scores.values.fold(0, (sum, list) =>
          sum + list.fold(0, (s, e) => s + (e['total'] as int)));

  double get _overallPercent =>
      _totalQuestions == 0 ? 0 : (_totalCorrect / _totalQuestions * 100);

  // Per-chapter best score
  int _bestScore(List<Map<String, dynamic>> attempts) =>
      attempts.isEmpty ? 0 : attempts.map((e) => e['score'] as int).reduce((a, b) => a > b ? a : b);

  int _totalForChapter(List<Map<String, dynamic>> attempts) =>
      attempts.isEmpty ? 0 : (attempts.last['total'] as int);

  Color _scoreColor(double pct) {
    if (pct >= 80) return Colors.green;
    if (pct >= 50) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Scoreboard 🏆'),
        backgroundColor: Colors.blue,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _scores.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.quiz, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No quiz scores yet!',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Open a chapter and tap "Quiz Me" to start.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ── Overall Summary Card ─────────────────────────────
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue[400]!, Colors.blue[700]!],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Overall Knowledge Score',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_overallPercent.toStringAsFixed(1)}%',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 40,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '$_totalCorrect / $_totalQuestions correct',
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 14),
                                    ),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Text(
                                      '$_totalAttempts',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const Text(
                                      'attempts',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_scores.length} chapters',
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: _overallPercent / 100,
                                minHeight: 10,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Text(
                      'Chapter Scores',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),

                    // ── Per-chapter score rows ───────────────────────────
                    ..._scores.entries.map((entry) {
                      final chapter = entry.key;
                      final attempts = entry.value;
                      final best = _bestScore(attempts);
                      final total = _totalForChapter(attempts);
                      final pct = total == 0 ? 0.0 : best / total * 100;
                      final color = _scoreColor(pct);

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      chapter,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: color),
                                    ),
                                    child: Text(
                                      'Best: $best/$total',
                                      style: TextStyle(
                                          color: color,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: pct / 100,
                                  minHeight: 6,
                                  backgroundColor: Colors.grey[200],
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(color),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${attempts.length} attempt${attempts.length != 1 ? 's' : ''}  •  ${pct.toStringAsFixed(0)}%',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
    );
  }
}
