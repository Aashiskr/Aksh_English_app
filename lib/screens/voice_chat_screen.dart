import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/stats_helper.dart';

class VoiceChatScreen extends StatefulWidget {
  const VoiceChatScreen({super.key});

  @override
  State<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends State<VoiceChatScreen> {
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;

  final String myServerUrl = "https://aksh-backend.vercel.app/chat";

  bool _isListening = false;
  bool _isSpeaking = false;
  String _statusText = "Initializing...";
  String? _savedApiKey;

  // Voice Selection Variables
  List<Map<dynamic, dynamic>> _indianVoices = [];
  Map<dynamic, dynamic>? _selectedVoice;

  final List<Map<String, String>> _messages = [];
  int _sessionScore = 0;

  @override
  void initState() {
    super.initState();
    _checkApiKeyAndInitVoice();
  }

  Future<void> _checkApiKeyAndInitVoice() async {
    final prefs = await SharedPreferences.getInstance();
    String? key = prefs.getString('gemini_api_key');

    if (key != null && key.isNotEmpty) {
      _savedApiKey = key;
      _initVoiceSystem();
    } else {
      setState(() => _statusText = "API Key Missing!");
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
        content: TextField(controller: keyController, decoration: const InputDecoration(hintText: "Paste Key Here")),
        actions: [
          ElevatedButton(onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('gemini_api_key', keyController.text.trim());
            Navigator.pop(context);
            _checkApiKeyAndInitVoice();
          }, child: const Text("Save"))
        ],
      ),
    );
  }

  Future<void> _initVoiceSystem() async {
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      setState(() => _statusText = "Mic Permission Denied");
      return;
    }

    _speech = stt.SpeechToText();
    bool available = await _speech.initialize(
      onError: (val) => print('onError: $val'),
      onStatus: (val) => print('onStatus: $val'),
    );

    if (!available) {
      setState(() => _statusText = "Speech Recognition Failed");
      return;
    }

    _flutterTts = FlutterTts();

    // 👇 Pehle voices load karenge
    await _initVoices();

    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() { _isSpeaking = false; _statusText = "Tap Mic to Reply"; });
    });

    setState(() => _statusText = "Tap Mic to Start");
  }

  // 🔥 NEW: Indian Voices Fetch Karne ka Logic
  Future<void> _initVoices() async {
    try {
      var voices = await _flutterTts.getVoices;
      List<Map<dynamic, dynamic>> tempVoices = [];

      for (var voice in voices) {
        // Filter for 'en-IN' (English India)
        if (voice['locale'] != null && voice['locale'].toString().contains("en-IN")) {
          tempVoices.add(voice);
        }
      }

      setState(() {
        _indianVoices = tempVoices.take(5).toList(); // Max 5 voices
        if (_indianVoices.isNotEmpty) {
          _selectedVoice = _indianVoices[0];
          _changeVoice(_selectedVoice!);
        }
      });
    } catch (e) {
      print("Error fetching voices: $e");
    }
  }

  // 🔥 NEW: Voice Change Function
  Future<void> _changeVoice(Map<dynamic, dynamic> voice) async {
    setState(() {
      _selectedVoice = voice;
    });

    await _flutterTts.setVoice({"name": voice["name"], "locale": voice["locale"]});
    // Setting typical Indian Speech Rate
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);
  }

  void _toggleListening() async {
    if (_isSpeaking) return;

    if (_isListening) {
      _speech.stop();
      setState(() { _isListening = false; _statusText = "Tap Mic"; });
    } else {
      setState(() { _isListening = true; _statusText = "Listening..."; });
      await _speech.listen(
        onResult: (val) {
          if (val.finalResult && val.recognizedWords.isNotEmpty) {
            _speech.stop();
            setState(() => _isListening = false);
            _sendVoiceMessage(val.recognizedWords);
          }
        },
        listenFor: const Duration(seconds: 30),
      );
    }
  }

  Future<void> _sendVoiceMessage(String text) async {
    setState(() {
      _messages.add({"role": "user", "text": text});
      _statusText = "Thinking...";
    });

    try {
      final response = await http.post(
        Uri.parse(myServerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "apiKey": _savedApiKey,
          "message": text,
          "history": _messages
        }),
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
          _statusText = "Playing Audio...";
          _isSpeaking = true;
        });

        String speakText = !isCorrect ? "Correction. $correction. $reply" : "Correct! $reply";
        await _flutterTts.speak(speakText);

      } else {
        setState(() => _statusText = "Server Error");
      }
    } catch (e) {
      setState(() => _statusText = "Connection Error");
    }
  }

  @override
  void dispose() { _speech.stop(); _flutterTts.stop(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Voice Tutor"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          // 🔥 NEW: Voice Selection Menu
          PopupMenuButton<Map<dynamic, dynamic>>(
            icon: const Icon(Icons.record_voice_over, color: Colors.white),
            tooltip: "Change Voice",
            onSelected: _changeVoice,
            itemBuilder: (BuildContext context) {
              if (_indianVoices.isEmpty) {
                return [
                  const PopupMenuItem(
                    enabled: false,
                    child: Text("No Indian Voices Found"),
                  )
                ];
              }
              return _indianVoices.map((voice) {
                return PopupMenuItem(
                  value: voice,
                  child: Row(
                    children: [
                      Icon(
                        Icons.check,
                        color: _selectedVoice == voice ? Colors.green : Colors.transparent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(voice["name"].toString().split("-").last), // Sirf naam dikhayega
                    ],
                  ),
                );
              }).toList();
            },
          ),
          Center(child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Text("🔥 $_sessionScore", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ))
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        backgroundColor: _isListening ? Colors.red : (_isSpeaking ? Colors.grey : Colors.deepPurple),
        child: Icon(_isListening ? Icons.stop : Icons.mic, color: Colors.white),
        onPressed: _toggleListening,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity, padding: const EdgeInsets.all(10), color: Colors.grey[200],
            child: Text(_statusText, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                bool isUser = msg['role'] == "user";
                bool isCorrection = msg['text']!.startsWith("📝");

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.deepPurple : (isCorrection ? Colors.orange[100] : Colors.grey[300]),
                      borderRadius: BorderRadius.circular(10),
                      border: isCorrection ? Border.all(color: Colors.orange) : null,
                    ),
                    child: Text(msg['text']!, style: TextStyle(color: isUser ? Colors.white : Colors.black)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}