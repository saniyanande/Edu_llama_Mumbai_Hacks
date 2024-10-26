import 'package:flutter/material.dart';
import '../models/chapter_models.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';

class ChaptersScreen extends StatefulWidget {
  @override
  _ChaptersScreenState createState() => _ChaptersScreenState();
}

class _ChaptersScreenState extends State<ChaptersScreen> {
  final ApiService _apiService = ApiService();
  late Future<ChapterResponse> _chaptersFuture;

  @override
  void initState() {
    super.initState();
    _chaptersFuture = _apiService.getChapters();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Science Chapters'),
        backgroundColor:  Colors.blue,
      ),
      body: FutureBuilder<ChapterResponse>(
        future: _chaptersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return const Center(child: Text('No chapters available'));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.85,
            ),
            itemCount: snapshot.data!.chapters.length,
            itemBuilder: (context, index) {
              final chapter = snapshot.data!.chapters[index];
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
        builder: (context) => ChatScreen(chapter: chapter),
      ),
    );
  }
}

class ChapterCard extends StatelessWidget {
  final String chapter;
  final VoidCallback onTap;

  const ChapterCard({
    Key? key,
    required this.chapter,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
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
              Icon(
                Icons.book,
                size: 48,
                color: Colors.white,
              ),
              SizedBox(height: 16),
              Text(
                chapter,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}