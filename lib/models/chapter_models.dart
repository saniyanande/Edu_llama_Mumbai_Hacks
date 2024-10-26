class Chapter {
  final String name;
  final int contentLength;

  Chapter({
    required this.name,
    required this.contentLength,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      name: json['chapter'] ?? '',
      contentLength: json['content_length'] ?? 0,
    );
  }
}

class ChapterResponse {
  final String status;
  final List<String> chapters;
  final int count;

  ChapterResponse({
    required this.status,
    required this.chapters,
    required this.count,
  });

  factory ChapterResponse.fromJson(Map<String, dynamic> json) {
    return ChapterResponse(
      status: json['status'] ?? '',
      chapters: List<String>.from(json['chapters'] ?? []),
      count: json['count'] ?? 0,
    );
  }
}

class ChatResponse {
  final String status;
  final String chapter;
  final String question;
  final String response;
  final double timeTaken;

  ChatResponse({
    required this.status,
    required this.chapter,
    required this.question,
    required this.response,
    required this.timeTaken,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      status: json['status'] ?? '',
      chapter: json['chapter'] ?? '',
      question: json['question'] ?? '',
      response: json['response'] ?? '',
      timeTaken: (json['time_taken'] ?? 0.0).toDouble(),
    );
  }
}