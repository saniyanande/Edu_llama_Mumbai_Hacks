import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chapter_models.dart';

class ApiService {
  static const String baseUrl = 'http://10.1.212.210:5000/api';

  Future<ChapterResponse> getChapters() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/chapters'));
      if (response.statusCode == 200) {
        return ChapterResponse.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to load chapters');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<Chapter> getChapterInfo(String chapterName) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chapters/$chapterName'),
      );
      if (response.statusCode == 200) {
        return Chapter.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to load chapter info');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<ChatResponse> askQuestion(String chapter, String question) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ask'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'chapter': chapter,
          'question': question,
        }),
      );
      if (response.statusCode == 200) {
        return ChatResponse.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to get response');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }
}