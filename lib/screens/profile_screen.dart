import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart'; // Apna login screen import karein

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  int _totalCorrect = 0;
  int _totalWrong = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _calculateOverallStats();
  }

  // 🔴 Logic: Purane day-wise data ko jod kar 'Overall' nikalna
  Future<void> _calculateOverallStats() async {
    final prefs = await SharedPreferences.getInstance();
    String? statsString = prefs.getString('daily_stats');

    if (statsString != null) {
      Map<String, dynamic> stats = jsonDecode(statsString);
      int correct = 0;
      int wrong = 0;

      stats.forEach((date, data) {
        correct += (data['correct'] ?? 0) as int;
        wrong += (data['wrong'] ?? 0) as int;
      });

      setState(() {
        _totalCorrect = correct;
        _totalWrong = wrong;
      });
    }
    setState(() => _isLoading = false);
  }

  // 🔴 Logic: Logout karna aur local data clear karna
  Future<void> _logout() async {
    // 👇 Naya step: Local stats clear kar rahe hain taaki naye user ko na dikhein
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('daily_stats');

    await GoogleSignIn.instance.signOut(); // ✅ Updated to .instance
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  // 🔴 Logic: Account Delete karna aur local data clear karna
  Future<void> _deleteAccount() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Account?"),
        content: const Text("Are you sure? This will permanently delete your account and progress. This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                // 👇 Naya step: Local stats clear kar rahe hain
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('daily_stats');

                await user?.delete();
                await GoogleSignIn.instance.signOut(); // ✅ Updated to .instance

                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                        (route) => false,
                  );
                }
              } on FirebaseAuthException catch (e) {
                // Agar user ne bahut pehle login kiya tha, toh Firebase security ke liye dobara login maangta hai
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.code == 'requires-recent-login' ? 'Please log out and log in again to delete your account.' : e.message ?? 'Error')),
                );
              }
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Profile"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // --- PROFILE INFO SECTION ---
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.deepPurple.shade100,
              // Google se aayi hui photo, agar na ho toh default icon
              backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
              child: user?.photoURL == null ? const Icon(Icons.person, size: 50, color: Colors.deepPurple) : null,
            ),
            const SizedBox(height: 15),
            Text(
              user?.displayName ?? "Student",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              user?.email ?? "No email",
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 30),

            // --- OVERALL STATS SECTION ---
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("Overall Progress", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(child: _buildStatCard("Total Correct", _totalCorrect, Colors.green, Icons.check_circle)),
                const SizedBox(width: 15),
                Expanded(child: _buildStatCard("Total Wrong", _totalWrong, Colors.red, Icons.cancel)),
              ],
            ),
            const SizedBox(height: 40),

            // --- ACTION BUTTONS ---
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.logout),
                label: const Text("Log Out"),
                onPressed: _logout,
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                icon: const Icon(Icons.delete_forever),
                label: const Text("Delete Account"),
                onPressed: _deleteAccount,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 10),
          Text(count.toString(), style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 5),
          Text(title, style: TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}