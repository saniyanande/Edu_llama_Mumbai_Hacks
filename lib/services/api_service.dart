import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import '../models/chapter_models.dart';
import '../models/quiz_models.dart';
import '../config.dart'; // E6: dynamic config

class ApiService {
  // E6: reads from --dart-define=BASE_URL=http://IP:6000/api at build time
  static String get baseUrl => AppConfig.baseUrl;
  final Dio _dio = Dio();

  // ── Chapters ──────────────────────────────────────────────────────────────

  Future<ChapterResponse> getChapters() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/chapters'));
      if (response.statusCode == 200) {
        return ChapterResponse.fromJson(json.decode(response.body));
      }
      throw Exception('Failed to load chapters');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<Chapter> getChapterInfo(String chapterName) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/chapters/$chapterName'));
      if (response.statusCode == 200) {
        return Chapter.fromJson(json.decode(response.body));
      }
      throw Exception('Failed to load chapter info');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // ── E1: Conversation Memory ───────────────────────────────────────────────

  /// Standard (non-streaming) question. Sends optional session_id for memory.
  Future<ChatResponse> askQuestion(String chapter, String question,
      {String? sessionId}) async {
    try {
      final body = {
        'chapter': chapter,
        'question': question,
        if (sessionId != null) 'session_id': sessionId,
      };
      final response = await http.post(
        Uri.parse('$baseUrl/ask'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );
      if (response.statusCode == 200) {
        return ChatResponse.fromJson(json.decode(response.body));
      }
      throw Exception('Failed to get response');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  /// Clears a conversation session on the backend (used by "New Chat" button).
  Future<void> clearSession(String sessionId) async {
    await http.post(
      Uri.parse('$baseUrl/session/clear'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'session_id': sessionId}),
    );
  }

  // ── E2: Streaming Responses ───────────────────────────────────────────────

  /// Streams AI answer token-by-token. Use with `await for` in the UI.
  Stream<String> streamQuestion(String chapter, String question,
      {String? sessionId}) async* {
    final body = {
      'chapter': chapter,
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

  // ── E4: AI Quiz ───────────────────────────────────────────────────────────

  /// Fetches AI-generated MCQ quiz questions for a chapter.
  Future<List<QuizQuestion>> getQuiz(String chapter,
      {int numQuestions = 5}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/quiz'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'chapter': chapter, 'num_questions': numQuestions}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['questions'] as List)
            .map((q) => QuizQuestion.fromJson(q))
            .toList();
      }
      throw Exception('Failed to generate quiz');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }
}