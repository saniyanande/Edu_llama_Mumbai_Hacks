import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';

class ChaptersScreen extends StatefulWidget {
  final String grade;
  final String subject;

  const ChaptersScreen({
    Key? key,
    required this.grade,
    required this.subject,
  }) : super(key: key);

  @override
  _ChaptersScreenState createState() => _ChaptersScreenState();
}

class _ChaptersScreenState extends State<ChaptersScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<String>> _chaptersFuture;

  @override
  void initState() {
    super.initState();
    _chaptersFuture = _apiService.getChaptersList(
        widget.grade, widget.subject);
  }

  String get _subjectLabel =>
      widget.subject.replaceAll('_', ' ');

  String get _gradeLabel {
    switch (widget.grade) {
      case 'Grade6': return 'Grade 6';
      case 'Grade7': return 'Grade 7';
      case 'Grade8': return 'Grade 8';
      default:       return widget.grade;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$_gradeLabel — $_subjectLabel'),
        backgroundColor: Colors.blue,
      ),
      body: FutureBuilder<List<String>>(
        future: _chaptersFuture,
        builder: (context, snapshot) {
          // Shimmer skeleton while loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemCount: 6,
              itemBuilder: (_, __) => Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            );
          }

          // Error state with retry
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('Could not load chapters.',
                        style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      onPressed: () => setState(() {
                        _chaptersFuture = _apiService.getChaptersList(
                            widget.grade, widget.subject);
                      }),
                    ),
                  ],
                ),
              ),
            );
          }

          final chapters = snapshot.data ?? [];

          if (chapters.isEmpty) {
            return const Center(
              child: Text('No chapters found. Drop PDFs into the correct folder.'),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.85,
            ),
            itemCount: chapters.length,
            itemBuilder: (context, index) {
              final chapter = chapters[index];
              return ChapterCard(
                chapter: chapter,
                onTap: () => _navigateToChat(chapter),
              );
            },
          );
        },
      ),
    );
  }

  void _navigateToChat(String chapter) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          grade:   widget.grade,
          subject: widget.subject,
          chapter: chapter,
        ),
      ),
    );
  }
}

class ChapterCard extends StatelessWidget {
  final String chapter;
  final VoidCallback onTap;

  const ChapterCard({Key? key, required this.chapter, required this.onTap})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[200]!, Colors.blue[400]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.book, size: 48, color: Colors.white),
              const SizedBox(height: 16),
              Text(
                chapter,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}