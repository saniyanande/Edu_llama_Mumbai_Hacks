import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../models/chapter_models.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';
import 'score_board_screen.dart'; // score tracking

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
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard),
            tooltip: 'My Scores',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ScoreBoardScreen()),
            ),
          ),
        ],
      ),
      body: FutureBuilder<ChapterResponse>(
        future: _chaptersFuture,
        builder: (context, snapshot) {

          // E8: Shimmer skeleton grid while loading
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

          // E8: Error state with retry button + wifi-off icon
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'Could not connect to the server.',
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Make sure the backend is running on port 6000.',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                      onPressed: () => setState(() {
                        _chaptersFuture = _apiService.getChapters();
                      }),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
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
              const Icon(Icons.book, size: 48, color: Colors.white),
              const SizedBox(height: 16),
              Text(
                chapter,
                style: const TextStyle(
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