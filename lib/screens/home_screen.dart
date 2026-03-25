import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 👇 Imports
import 'text_chat_screen.dart';
import 'voice_chat_screen.dart';
import 'stats_screen.dart';
import 'video_player_screen.dart';
import 'profile_screen.dart'; // ✅ Profile Screen import kiya

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Current user ka data fetch kar rahe hain DP ke liye
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,

        // 🔴 Naya Profile Icon (Top Left Corner)
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
            child: CircleAvatar(
              backgroundColor: Colors.deepPurple.shade100,
              // Google wali photo yahan dikhegi
              backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
              child: user?.photoURL == null ? const Icon(Icons.person, color: Colors.deepPurple) : null,
            ),
          ),
        ),

        actions: [
          // Video Player Button
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const VideoPlayerScreen()),
              );
            },
            icon: const Icon(Icons.play_circle_fill, color: Colors.red),
            label: const Text(
              "Get API Key",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.school_rounded, size: 80, color: Colors.deepPurple),
              const SizedBox(height: 30),
              const Text(
                "Aksh English",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 50),

              // Button 1: Text Chat
              _buildButton(context, "Text Chat", Icons.chat, Colors.blue, const TextChatScreen()),
              const SizedBox(height: 20),

              // Button 2: Voice Tutor
              _buildButton(context, "Voice Tutor", Icons.mic, Colors.deepPurple, const VoiceChatScreen()),
              const SizedBox(height: 20),

              // Button 3: Progress
              _buildButton(context, "My Progress", Icons.bar_chart, Colors.teal, const StatsScreen()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context, String text, IconData icon, Color color, Widget page) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton.icon(
        icon: Icon(icon),
        label: Text(text),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 5,
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => page),
          );
        },
      ),
    );
  }
}