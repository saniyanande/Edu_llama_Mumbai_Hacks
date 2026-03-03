import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'quiz_screen.dart';

class ChatScreen extends StatefulWidget {
  final String grade;
  final String subject;
  final String chapter;

  const ChatScreen({
    Key? key,
    required this.grade,
    required this.subject,
    required this.chapter,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _questionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Message> _messages = [];
  bool _isLoading = false;
  String? _sessionId;
  late SharedPreferences _prefs;

  // Unique storage key scoped to grade + subject + chapter
  String get _storageKey =>
      '${widget.grade}__${widget.subject}__${widget.chapter}';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── E7: Persistence ───────────────────────────────────────────────────────

  Future<void> _loadHistory() async {
    _prefs = await SharedPreferences.getInstance();
    final saved = _prefs.getString('chat_$_storageKey');
    if (saved != null) {
      final list = json.decode(saved) as List;
      setState(() {
        _messages.addAll(list.map((m) => Message(
          text:      m['text'] as String,
          isUser:    m['isUser'] as bool,
          timestamp: DateTime.parse(m['timestamp'] as String),
        )));
      });
    }
    _sessionId = _prefs.getString('session_$_storageKey');
  }

  Future<void> _saveHistory() async {
    await _prefs.setString(
      'chat_$_storageKey',
      json.encode(_messages.map((m) => {
        'text':      m.text,
        'isUser':    m.isUser,
        'timestamp': m.timestamp.toIso8601String(),
      }).toList()),
    );
    if (_sessionId != null) {
      await _prefs.setString('session_$_storageKey', _sessionId!);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

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

  // ── E2: Streaming send ────────────────────────────────────────────────────

  Future<void> _sendQuestion() async {
    final question = _questionController.text.trim();
    if (question.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(
          Message(text: question, isUser: true, timestamp: DateTime.now()));
      _messages.add(
          Message(text: '', isUser: false, timestamp: DateTime.now()));
      _isLoading = true;
    });
    _questionController.clear();
    _scrollToBottom();

    try {
      final stream = _apiService.streamQuestion(
        widget.grade,
        widget.subject,
        widget.chapter,
        question,
        sessionId: _sessionId,
      );

      await for (final token in stream) {
        setState(() {
          final last = _messages.last;
          _messages[_messages.length - 1] = Message(
            text: last.text + token,
            isUser: false,
            timestamp: last.timestamp,
          );
        });
        _scrollToBottom();
      }
    } catch (e) {
      setState(() {
        _messages[_messages.length - 1] = Message(
          text: 'Error: Could not get a response. Is the backend running?',
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        );
      });
    } finally {
      setState(() => _isLoading = false);
      await _saveHistory();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  String get _subjectLabel => widget.subject.replaceAll('_', ' ');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chapter,
            style: const TextStyle(fontSize: 14)),
        backgroundColor: Colors.blue,
        actions: [
          // E4: Quiz button
          IconButton(
            icon: const Icon(Icons.quiz),
            tooltip: 'Quiz Me',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => QuizScreen(
                  grade:   widget.grade,
                  subject: widget.subject,
                  chapter: widget.chapter,
                ),
              ),
            ),
          ),
          // E1 + E7: New chat clears backend session + local history
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'New Chat',
            onPressed: () async {
              if (_sessionId != null) {
                await _apiService.clearSession(_sessionId!);
              }
              await _prefs.remove('chat_$_storageKey');
              await _prefs.remove('session_$_storageKey');
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
          // Breadcrumb bar
          Container(
            width: double.infinity,
            color: Colors.blue[50],
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              '${widget.grade.replaceAll('G', 'G ')} › $_subjectLabel',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) =>
                  MessageBubble(message: _messages[index]),
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black12,
                    offset: Offset(0, -2),
                    blurRadius: 4),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _questionController,
                    decoration: InputDecoration(
                      hintText: 'Ask about $_subjectLabel...',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                    onSubmitted:
                        _isLoading ? null : (_) => _sendQuestion(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _isLoading ? null : _sendQuestion,
                  backgroundColor:
                      _isLoading ? Colors.grey : Colors.blue,
                  mini: true,
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data models ───────────────────────────────────────────────────────────────

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
  const MessageBubble({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment:
          message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              '${message.timestamp.hour}:'
              '${message.timestamp.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 12,
                color: message.isUser
                    ? Colors.white70
                    : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}