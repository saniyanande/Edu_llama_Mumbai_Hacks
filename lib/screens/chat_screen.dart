import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'quiz_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chapter;

  const ChatScreen({Key? key, required this.chapter}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _questionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Message> _messages = [];
  bool _isLoading = false;
  String? _sessionId; // E1: tracks conversation session for memory

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // E2: Streaming version — fills the AI bubble token by token
  Future<void> _sendQuestion() async {
    final question = _questionController.text.trim();
    if (question.isEmpty || _isLoading) return;

    setState(() {
      // Add user message
      _messages.add(Message(
        text: question,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      // Add empty AI bubble — we'll fill it word by word
      _messages.add(Message(
        text: '',
        isUser: false,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });
    _questionController.clear();
    _scrollToBottom();

    try {
      // E2: Stream question — tokens arrive one by one
      final stream = _apiService.streamQuestion(
        widget.chapter,
        question,
        sessionId: _sessionId, // E1: send session ID for memory
      );

      await for (final token in stream) {
        setState(() {
          final last = _messages.last;
          _messages[_messages.length - 1] = Message(
            text: last.text + token,  // append each token to the bubble
            isUser: false,
            timestamp: last.timestamp,
          );
        });
        _scrollToBottom();
      }
    } catch (e) {
      setState(() {
        _messages[_messages.length - 1] = Message(
          text: 'Error: Failed to get response. Is the backend running?',
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        );
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat - ${widget.chapter}'),
        backgroundColor: Colors.blue,
        actions: [
          // E4: Quiz button — navigates to AI-generated MCQ quiz
          IconButton(
            icon: const Icon(Icons.quiz),
            tooltip: 'Quiz Me',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => QuizScreen(chapter: widget.chapter),
              ),
            ),
          ),
          // E1: New Chat button — clears session and history
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'New Chat',
            onPressed: () async {
              if (_sessionId != null) {
                await _apiService.clearSession(_sessionId!);
              }
              setState(() {
                _messages.clear();
                _sessionId = null;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return MessageBubble(message: message);
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),  // streaming progress bar
            ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  offset: Offset(0, -2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _questionController,
                    decoration: InputDecoration(
                      hintText: 'Ask a question...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: _isLoading ? null : (_) => _sendQuestion(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  // Disabled (grey) while streaming is active
                  onPressed: _isLoading ? null : _sendQuestion,
                  backgroundColor: _isLoading ? Colors.grey : Colors.blue,
                  child: const Icon(Icons.send),
                  mini: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Message {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;

  Message({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
  });
}

class MessageBubble extends StatelessWidget {
  final Message message;

  const MessageBubble({
    Key? key,
    required this.message,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: message.isUser
              ? Colors.blue
              : message.isError
                  ? Colors.red[100]
                  : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show a spinner inside the bubble if still streaming (text is empty)
            if (message.text.isEmpty && !message.isUser)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Text(
                message.text,
                style: TextStyle(
                  color: message.isUser
                      ? Colors.white
                      : message.isError
                          ? Colors.red[900]
                          : Colors.black,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 12,
                color: message.isUser ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}