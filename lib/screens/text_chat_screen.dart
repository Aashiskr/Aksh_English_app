import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/stats_helper.dart';

class TextChatScreen extends StatefulWidget {
  const TextChatScreen({super.key});

  @override
  State<TextChatScreen> createState() => _TextChatScreenState();
}

class _TextChatScreenState extends State<TextChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];

  String _statusText = "Checking API Key...";
  String? _savedApiKey;
  bool _isLoading = false;
  int _sessionScore = 0;

  final String myServerUrl = "https://aksh-backend.vercel.app/chat";

  @override
  void initState() {
    super.initState();
    _checkApiKey();
  }

  Future<void> _checkApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    String? key = prefs.getString('gemini_api_key');
    if (key != null && key.isNotEmpty) {
      setState(() { _savedApiKey = key; _statusText = "Ready to Chat"; });
    } else {
      _showApiKeyDialog();
    }
  }

  void _showApiKeyDialog() {
    TextEditingController keyController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Enter API Key"),
        content: TextField(
            controller: keyController,
            decoration: const InputDecoration(hintText: "Paste Key")
        ),
        actions: [
          ElevatedButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('gemini_api_key', keyController.text.trim());
                Navigator.pop(context);
                _checkApiKey();
              },
              child: const Text("Save")
          )
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    String text = _textController.text.trim();
    if (text.isEmpty || _savedApiKey == null) return;

    _textController.clear();
    setState(() {
      _messages.add({"role": "user", "text": text});
      _statusText = "Thinking...";
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse(myServerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({ "apiKey": _savedApiKey, "message": text, "history": _messages }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String correction = data['correction'] ?? "";
        String reply = data['reply'] ?? "";

        bool isCorrect = (correction == "Perfect!" || correction.isEmpty || correction == "No correction");
        StatsHelper.updateScore(isCorrect: isCorrect);

        setState(() {
          if (!isCorrect) {
            _messages.add({"role": "bot", "text": "📝 Correction: $correction"});
          } else {
            _sessionScore++;
          }

          _messages.add({"role": "bot", "text": reply});
          _statusText = "Reply Received";
          _isLoading = false;
        });
      } else {
        setState(() => _statusText = "Server Error");
      }
    } catch (e) {
      setState(() => _statusText = "Connection Failed");
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("Text Chat"),
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          actions: [
            Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                    child: Text("🔥 $_sessionScore", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
                )
            )
          ]
      ),
      // 🟢 CHANGE 1: SafeArea lagaya taaki navigation bar ke peeche na chupe
      body: SafeArea(
        child: Column(
          children: [
            // Chat Area
            Expanded(
              child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    bool isUser = msg['role'] == "user";
                    bool isCorrection = msg['text']!.startsWith("📝");

                    // 🟢 CHANGE 2: Chat Bubble UI improve kiya
                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: const EdgeInsets.all(12),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: isUser
                              ? Colors.blueAccent
                              : (isCorrection ? Colors.orange[100] : Colors.grey[200]),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(12),
                            topRight: const Radius.circular(12),
                            bottomLeft: isUser ? const Radius.circular(12) : Radius.zero,
                            bottomRight: isUser ? Radius.zero : const Radius.circular(12),
                          ),
                          border: isCorrection ? Border.all(color: Colors.orange) : null,
                        ),
                        child: Text(
                            msg['text']!,
                            style: TextStyle(
                                color: isUser ? Colors.white : Colors.black,
                                fontSize: 16
                            )
                        ),
                      ),
                    );
                  }
              ),
            ),

            // 🟢 CHANGE 3: Input Box ko Container mein daal kar Padding di
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Colors.grey.shade300, blurRadius: 5, offset: const Offset(0, -2))
                  ]
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: "Type a sentence...",
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    radius: 24,
                    child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white, size: 20),
                        onPressed: _sendMessage
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}