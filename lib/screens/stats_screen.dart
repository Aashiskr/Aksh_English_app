import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    String? statsString = prefs.getString('daily_stats');
    if (statsString != null) {
      setState(() {
        _stats = jsonDecode(statsString);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Your Progress"), backgroundColor: Colors.teal, foregroundColor: Colors.white),
      body: _stats.isEmpty
          ? const Center(child: Text("No progress recorded yet."))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _stats.keys.length,
        itemBuilder: (context, index) {
          String date = _stats.keys.elementAt(index);
          Map<String, dynamic> data = _stats[date];
          int correct = data['correct'] ?? 0;
          int wrong = data['wrong'] ?? 0;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.calendar_today, color: Colors.teal),
              title: Text("Date: $date", style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Row(
                children: [
                  Text("✅ Correct: $correct", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 20),
                  Text("❌ Wrong: $wrong", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}