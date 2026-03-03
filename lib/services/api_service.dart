import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import '../models/chapter_models.dart';
import '../models/quiz_models.dart';
import '../config.dart';

class ApiService {
  static String get baseUrl => AppConfig.baseUrl;
  final Dio _dio = Dio();

  // ── T3: Grades / Subjects / Chapters ─────────────────────────────────────

  Future<List<String>> getGrades() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/grades'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<String>.from(data['grades'] ?? []);
      }
      throw Exception('Failed to load grades');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<List<String>> getSubjects(String grade) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/subjects/$grade'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<String>.from(data['subjects'] ?? []);
      }
      throw Exception('Failed to load subjects');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<List<String>> getChaptersList(String grade, String subject) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/chapters/$grade/$subject'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<String>.from(data['chapters'] ?? []);
      }
      throw Exception('Failed to load chapters');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Legacy — kept in case any old code calls it
  Future<ChapterResponse> getChapters() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/chapters'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return ChapterResponse.fromJson(json.decode(response.body));
      }
      throw Exception('Failed to load chapters');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // ── E1: Conversation memory ───────────────────────────────────────────────

  Future<ChatResponse> askQuestion(
    String grade,
    String subject,
    String chapter,
    String question, {
    String? sessionId,
  }) async {
    try {
      final body = {
        'grade':    grade,
        'subject':  subject,
        'chapter':  chapter,
        'question': question,
        if (sessionId != null) 'session_id': sessionId,
      };
      final response = await http.post(
        Uri.parse('$baseUrl/ask'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) {
        return ChatResponse.fromJson(json.decode(response.body));
      }
      throw Exception('Failed to get response');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<void> clearSession(String sessionId) async {
    await http.post(
      Uri.parse('$baseUrl/session/clear'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'session_id': sessionId}),
    );
  }

  // ── E2: Streaming ─────────────────────────────────────────────────────────

  Stream<String> streamQuestion(
    String grade,
    String subject,
    String chapter,
    String question, {
    String? sessionId,
  }) async* {
    final body = {
      'grade':    grade,
      'subject':  subject,
      'chapter':  chapter,
      'question': question,
      if (sessionId != null) 'session_id': sessionId,
    };
    final response = await _dio.post(
      '$baseUrl/ask/stream',
      data: body,
      options: Options(responseType: ResponseType.stream),
    );
    final rawStream = response.data.stream as Stream<List<int>>;
    await for (final bytes in rawStream) {
      yield String.fromCharCodes(bytes);
    }
  }

  // ── E4: Quiz ──────────────────────────────────────────────────────────────

  Future<List<QuizQuestion>> getQuiz(
    String grade,
    String subject,
    String chapter, {
    int numQuestions = 5,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/quiz'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'grade':          grade,
          'subject':        subject,
          'chapter':        chapter,
          'num_questions':  numQuestions,
        }),
      ).timeout(const Duration(seconds: 90));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['questions'] as List).map((q) {
          final map = q is String
              ? json.decode(q) as Map<String, dynamic>
              : q as Map<String, dynamic>;
          return QuizQuestion.fromJson(map);
        }).toList();
      }
      throw Exception('Failed to generate quiz');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }
}