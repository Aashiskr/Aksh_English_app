import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StatsHelper {
  static Future<void> updateScore({required bool isCorrect}) async {
    final prefs = await SharedPreferences.getInstance();
    String dateKey = DateTime.now().toString().split(' ')[0];

    String? statsString = prefs.getString('daily_stats');
    Map<String, dynamic> stats = statsString != null ? jsonDecode(statsString) : {};

    Map<String, dynamic> today = stats[dateKey] ?? {'correct': 0, 'wrong': 0};

    if (isCorrect) {
      today['correct'] = (today['correct'] ?? 0) + 1;
    } else {
      today['wrong'] = (today['wrong'] ?? 0) + 1;
    }

    stats[dateKey] = today;
    await prefs.setString('daily_stats', jsonEncode(stats));
  }
}