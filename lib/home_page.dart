import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:alzheimers_project/notes_reminders_page.dart';
import 'package:alzheimers_project/wellness_log_page.dart';
import 'package:alzheimers_project/safety_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.onTabSelected});

  final ValueChanged<int> onTabSelected;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const Color _homeButtonColor = Colors.white;
  static const String _loginDatesKey = 'home_login_dates';
  static const String _medicationsKey = 'saved_medications';
  static const String _wellnessHistoryKey = 'wellness_log_history';
  static const List<String> _weekdayLabels = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  String _daysStreakLabel = '-';
  String _medicationPercentLabel = '-';
  String _todayMoodLabel = '-';

  @override
  void initState() {
    super.initState();
    _loadHomeStats();
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadHomeStats();
  }

  Future<void> _loadHomeStats() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // 1) Login day streak
    final DateTime now = DateTime.now();
    final String todayKey = _dateKey(now);
    final Set<String> loginDates = (prefs.getStringList(_loginDatesKey) ?? <String>[])
        .toSet();
    loginDates.add(todayKey);
    await prefs.setStringList(_loginDatesKey, loginDates.toList(growable: false));

    int streak = 0;
    DateTime cursor = DateTime(now.year, now.month, now.day);
    while (loginDates.contains(_dateKey(cursor))) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    // 2) Today's medication percentage
    final List<String> rawMeds = prefs.getStringList(_medicationsKey) ?? <String>[];
    final String todayLabel = _weekdayLabels[now.weekday - 1];
    int scheduled = 0;
    int taken = 0;
    for (final String raw in rawMeds) {
      try {
        final Map<String, dynamic> item = jsonDecode(raw) as Map<String, dynamic>;
        final List<dynamic> days = item['days'] is List ? item['days'] as List<dynamic> : <dynamic>[];
        final bool scheduledToday = days.map((d) => d.toString()).contains(todayLabel);
        if (!scheduledToday) continue;
        scheduled += 1;
        final String status = (item['status'] ?? '').toString();
        final String statusDate = (item['statusDate'] ?? '').toString();
        if (status == 'Taken' && statusDate == todayKey) {
          taken += 1;
        }
      } catch (_) {
        // Ignore malformed row.
      }
    }
    final String medicationPercent = scheduled == 0
        ? '0%'
        : '${((taken / scheduled) * 100).round()}%';

    // 3) Today's mood from wellness log
    String todayMood = '-';
    final List<String> rawHistory = prefs.getStringList(_wellnessHistoryKey) ?? <String>[];
    for (final String raw in rawHistory) {
      try {
        final Map<String, dynamic> item = jsonDecode(raw) as Map<String, dynamic>;
        if ((item['date'] ?? '').toString() == todayKey) {
          final String mood = (item['mood'] ?? '').toString();
          todayMood = mood.isEmpty ? '-' : mood;
          break;
        }
      } catch (_) {
        // Ignore malformed row.
      }
    }

    if (!mounted) return;
    setState(() {
      _daysStreakLabel = streak.toString();
      _medicationPercentLabel = medicationPercent;
      _todayMoodLabel = todayMood;
    });
  }

  String _dateKey(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _timeGreeting() {
    final int hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good Morning';
    if (hour >= 12 && hour < 17) return 'Good Afternoon';
    if (hour >= 17 && hour < 21) return 'Good Evening';
    return 'Good Night';
  }

  @override
  Widget build(BuildContext context) {
    final String greeting = _timeGreeting();
    return Container(
      color: Colors.indigo[400],
      child: SafeArea(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "$greeting, Hudson",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.indigo[300],
                    borderRadius: BorderRadius.circular(15.0),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      _buildStatColumn(_daysStreakLabel, "Days Active"),
                      _buildStatColumn(_medicationPercentLabel, "Medication"),
                      _buildStatColumn(_todayMoodLabel, "Today's Mood"),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16.0),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16.0,
                mainAxisSpacing: 16.0,
                childAspectRatio: 0.72,
                children: <Widget>[
                  // 1) Cognitive Check (tab)
                  _buildTabButton(
                    "Cognitive Check",
                    "Assess your cognitive abilities",
                    Icons.psychology_alt,
                    Colors.blue,
                    _homeButtonColor,
                    1, // tab index
                  ),
                  // 2) Wellness Log (push)
                  _buildPushButton(
                    context,
                    "Wellness Log",
                    "Track your daily well-being",
                    Icons.favorite,
                    Colors.pink,
                    const WellnessLogPage(),
                    _homeButtonColor,
                  ),
                  // 3) Medication (tab)
                  _buildTabButton(
                    "Medication",
                    "Manage your medication schedule",
                    Icons.medication_liquid,
                    Colors.green,
                    _homeButtonColor,
                    2, // tab index
                  ),
                  // 4) Notes & Reminders (push)
                  _buildPushButton(
                    context,
                    "Notes & Reminders",
                    "Manage your daily notes and reminders",
                    Icons.event_note,
                    Colors.red,
                    const NotesRemindersPage(),
                    _homeButtonColor,
                  ),
                  // 5) Safety (push)
                  _buildPushButton(
                    context,
                    "Safety",
                    "Access emergency contacts and resources",
                    Icons.security,
                    Colors.orange,
                    const SafetyPage(),
                    _homeButtonColor,
                  ),
                  // 6) My Profile (tab)
                  _buildTabButton(
                    "My Profile",
                    "Review your personal information",
                    Icons.person,
                    Colors.purple,
                    _homeButtonColor,
                    3, // tab index
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(
    String title,
    String description,
    IconData icon,
    Color iconColor,
    Color color,
    int tabIndex,
  ) {
    return Card(
      color: color,
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: () {
          widget.onTabSelected(tabIndex);
        },
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _buildButtonIcon(icon, iconColor),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(fontSize: 12, color: Colors.black),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPushButton(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color iconColor,
    Widget targetPage,
    Color color,
  ) {
    return Card(
      color: color,
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => targetPage),
          );
          if (!mounted) return;
          await _loadHomeStats();
        },
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _buildButtonIcon(icon, iconColor),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(fontSize: 12, color: Colors.black),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButtonIcon(IconData icon, Color iconColor) {
    final Color lightFill = Color.lerp(iconColor, Colors.white, 0.75)!;
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: lightFill,
        border: Border.all(color: iconColor, width: 2),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 32.0, color: iconColor),
    );
  }

  Widget _buildStatColumn(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.white70),
        ),
      ],
    );
  }
}