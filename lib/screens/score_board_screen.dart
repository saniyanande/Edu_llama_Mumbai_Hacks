import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScoreBoardScreen extends StatefulWidget {
  const ScoreBoardScreen({Key? key}) : super(key: key);

  @override
  State<ScoreBoardScreen> createState() => _ScoreBoardScreenState();
}

class _ScoreBoardScreenState extends State<ScoreBoardScreen> {
  // grade → subject → chapter → list of {score, total, date}
  Map<String, Map<String, Map<String, List<Map<String, dynamic>>>>> _scores = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadScores();
  }

  Future<void> _loadScores() async {
    final prefs = await SharedPreferences.getInstance();
    final keys  = prefs.getKeys().where((k) => k.startsWith('quiz_score_'));
    final map   = <String, Map<String, Map<String, List<Map<String, dynamic>>>>>{};

    for (final key in keys) {
      final raw = prefs.getString(key);
      if (raw == null) continue;

      // key format: quiz_score_Grade7__Science__chapter1
      final parts = key.replaceFirst('quiz_score_', '').split('__');
      if (parts.length < 3) continue;

      final grade   = parts[0];
      final subject = parts[1];
      final chapter = parts.sublist(2).join('__'); // chapter names may contain __

      map.putIfAbsent(grade, () => {});
      map[grade]!.putIfAbsent(subject, () => {});
      map[grade]![subject]![chapter] = List<Map<String, dynamic>>.from(
          (json.decode(raw) as List).map((e) => Map<String, dynamic>.from(e)));
    }

    setState(() {
      _scores  = map;
      _loading = false;
    });
  }

  // ── Computed stats ────────────────────────────────────────────────────────

  int _totalAttempts() => _scores.values
      .expand((s) => s.values)
      .expand((c) => c.values)
      .fold(0, (sum, attempts) => sum + attempts.length);

  int _totalCorrect() => _scores.values
      .expand((s) => s.values)
      .expand((c) => c.values)
      .expand((a) => a)
      .fold(0, (sum, e) => sum + (e['score'] as int));

  int _totalQuestions() => _scores.values
      .expand((s) => s.values)
      .expand((c) => c.values)
      .expand((a) => a)
      .fold(0, (sum, e) => sum + (e['total'] as int));

  double _pct(int correct, int total) =>
      total == 0 ? 0 : correct / total * 100;

  Color _color(double pct) {
    if (pct >= 80) return Colors.green;
    if (pct >= 50) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final totalCorrect   = _totalCorrect();
    final totalQuestions = _totalQuestions();
    final overallPct     = _pct(totalCorrect, totalQuestions);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scoreboard 🏆'),
        backgroundColor: Colors.blue,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _scores.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.quiz, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No quiz scores yet!',
                          style: TextStyle(fontSize: 18, color: Colors.grey)),
                      SizedBox(height: 8),
                      Text('Open a chapter and tap Quiz Me to start.',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ── Overall Summary ──────────────────────────────────
                    _OverallCard(
                      pct:            overallPct,
                      totalCorrect:   totalCorrect,
                      totalQuestions: totalQuestions,
                      totalAttempts:  _totalAttempts(),
                      gradeCount:     _scores.length,
                    ),
                    const SizedBox(height: 20),

                    // ── Per Grade → Subject → Chapter ────────────────────
                    ..._scores.entries.map((gradeEntry) {
                      final grade         = gradeEntry.key;
                      final subjectScores = gradeEntry.value;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              grade.replaceAll('Grade', 'Grade '),
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          ...subjectScores.entries.map((subjectEntry) {
                            final subject        = subjectEntry.key;
                            final chapterScores  = subjectEntry.value;
                            final subjectCorrect = chapterScores.values
                                .expand((a) => a)
                                .fold(0, (s, e) => s + (e['score'] as int));
                            final subjectTotal = chapterScores.values
                                .expand((a) => a)
                                .fold(0, (s, e) => s + (e['total'] as int));
                            final subjectPct =
                                _pct(subjectCorrect, subjectTotal);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: ExpansionTile(
                                title: Text(
                                  subject.replaceAll('_', ' '),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  '$subjectCorrect / $subjectTotal correct  '
                                  '(${subjectPct.toStringAsFixed(0)}%)',
                                  style: TextStyle(
                                      color: _color(subjectPct),
                                      fontSize: 13),
                                ),
                                trailing: SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: CircularProgressIndicator(
                                    value: subjectPct / 100,
                                    backgroundColor: Colors.grey[200],
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        _color(subjectPct)),
                                    strokeWidth: 5,
                                  ),
                                ),
                                children: chapterScores.entries.map((chapEntry) {
                                  final chapter  = chapEntry.key;
                                  final attempts = chapEntry.value;
                                  final best     = attempts
                                      .map((e) => e['score'] as int)
                                      .reduce((a, b) => a > b ? a : b);
                                  final total    =
                                      attempts.last['total'] as int;
                                  final pct      = _pct(best, total);

                                  return ListTile(
                                    title: Text(chapter,
                                        style: const TextStyle(fontSize: 13)),
                                    subtitle: LinearProgressIndicator(
                                      value: pct / 100,
                                      backgroundColor: Colors.grey[200],
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          _color(pct)),
                                    ),
                                    trailing: Text(
                                      'Best $best/$total',
                                      style: TextStyle(
                                          color: _color(pct),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12),
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          }),
                        ],
                      );
                    }),
                  ],
                ),
    );
  }
}

class _OverallCard extends StatelessWidget {
  final double pct;
  final int totalCorrect, totalQuestions, totalAttempts, gradeCount;

  const _OverallCard({
    required this.pct,
    required this.totalCorrect,
    required this.totalQuestions,
    required this.totalAttempts,
    required this.gradeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            const Text('Overall Knowledge Score',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${pct.toStringAsFixed(1)}%',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.bold)),
                  Text('$totalCorrect / $totalQuestions correct',
                      style: const TextStyle(color: Colors.white70)),
                ]),
                Column(children: [
                  Text('$totalAttempts',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold)),
                  const Text('quizzes', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text('$gradeCount grade(s)',
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: pct / 100,
                minHeight: 10,
                backgroundColor: Colors.white24,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
