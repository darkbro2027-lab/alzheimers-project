import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:alzheimers_project/profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WellnessLogPage extends StatefulWidget {
  const WellnessLogPage({super.key});

  @override
  State<WellnessLogPage> createState() => _WellnessLogPageState();
}

class _WellnessLogPageState extends State<WellnessLogPage> {
  String? _selectedMood;
  String? _selectedSleep;
  final TextEditingController _mindController = TextEditingController();
  final List<_WellnessLogEntry> _history = <_WellnessLogEntry>[];
  bool _historyReady = false;
  bool _isRedirectingToCompleted = false;

  @override
  void initState() {
    super.initState();
    _initializeWellnessPage();
  }

  @override
  void dispose() {
    _mindController.dispose();
    super.dispose();
  }

  String _todayKey() {
    final DateTime now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  bool _hasSubmittedToday() {
    final String today = _todayKey();
    return _history.any((entry) => entry.date == today);
  }

  void _redirectToCompletedPage() {
    if (!mounted || _isRedirectingToCompleted) return;
    _isRedirectingToCompleted = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => _WellnessLogCompletedPage(entries: _history),
      ),
    );
  }

  Future<void> _initializeWellnessPage() async {
    await _loadHistory();
    if (!mounted) return;
    if (_hasSubmittedToday()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _redirectToCompletedPage();
      });
    }
  }

  Future<void> _loadHistory() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> raw = prefs.getStringList('wellness_log_history') ?? <String>[];
    final List<_WellnessLogEntry> entries = raw
        .map((item) {
          try {
            return _WellnessLogEntry.fromJson(
              jsonDecode(item) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<_WellnessLogEntry>()
        .toList();

    if (!mounted) return;
    setState(() {
      _history
        ..clear()
        ..addAll(entries);
      _historyReady = true;
    });
  }

  Future<void> _saveHistory() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'wellness_log_history',
      _history.map((e) => jsonEncode(e.toJson())).toList(growable: false),
    );
  }

  Future<void> _submitWellnessLog() async {
    if (_hasSubmittedToday()) {
      _redirectToCompletedPage();
      return;
    }

    final String dateLabel = _todayKey();

    final _WellnessLogEntry entry = _WellnessLogEntry(
      date: dateLabel,
      mood: _selectedMood ?? 'Not selected',
      sleep: _selectedSleep ?? 'Not selected',
      note: _mindController.text.trim(),
    );

    setState(() {
      _history.insert(0, entry);
      _selectedMood = null;
      _selectedSleep = null;
      _mindController.clear();
    });
    await _saveHistory();

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _WellnessLogCompletedPage(entries: _history),
      ),
    );
  }

  Widget _buildMoodOption({
    required String label,
    required IconData icon,
    required Color iconColor,
  }) {
    final bool isSelected = _selectedMood == label;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        setState(() {
          _selectedMood = label;
        });
      },
      child: Container(
        height: 112,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFDCE9FF) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFFD6DAE3),
            width: isSelected ? 2 : 1.2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, color: iconColor, size: 30),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF273444),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSleepOption({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        height: 110,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFDCE9FF) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFF3B82F6) : const Color(0xFFD6DAE3),
            width: selected ? 2 : 1.2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.star_rounded,
              color: selected ? const Color(0xFFE5A11A) : const Color(0xFF9AA4B2),
              size: 34,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF273444),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_historyReady) {
      return Scaffold(
        backgroundColor: Colors.indigo[400],
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_hasSubmittedToday()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _redirectToCompletedPage();
      });
      return Scaffold(
        backgroundColor: Colors.indigo[400],
        body: const SizedBox.shrink(),
      );
    }

    final DateTime today = DateTime.now();
    const List<String> monthNames = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final String todayLabel =
        'Today - ${monthNames[today.month - 1]} ${today.day} ${today.year}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wellness Log'),
        backgroundColor: Colors.indigo[400],
        foregroundColor: Colors.white,
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 10, top: 8, bottom: 8),
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => _WellnessHistoryPage(entries: _history),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF273444),
                elevation: 0,
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                shape: const StadiumBorder(),
              ),
              child: const Text(
                'View history',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle, size: 30),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
          ),
        ],
      ),
      backgroundColor: Colors.indigo[400],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.indigo[300],
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: <Widget>[
                  Text(
                    todayLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Let's check how you're feeling",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFCFD3DC),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 174),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFD6DAE3), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Row(
                    children: <Widget>[
                      SizedBox(
                        width: 58,
                        height: 58,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xFFEEE7F8),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.sentiment_satisfied_alt_rounded,
                            color: Color(0xFF8E44AD),
                            size: 28,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'How are you feeling today?',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF273444),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildMoodOption(
                            label: 'Great',
                            icon: Icons.sentiment_very_satisfied_rounded,
                            iconColor: const Color(0xFF2EA66A),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildMoodOption(
                            label: 'Good',
                            icon: Icons.sentiment_satisfied_rounded,
                            iconColor: const Color(0xFF3D7BE6),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildMoodOption(
                            label: 'Okay',
                            icon: Icons.sentiment_neutral_rounded,
                            iconColor: const Color(0xFFE5A11A),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildMoodOption(
                            label: 'Sad',
                            icon: Icons.sentiment_dissatisfied_rounded,
                            iconColor: const Color(0xFFFF7A1A),
                          ),
                        ),
                      ),
                      Expanded(
                        child: _buildMoodOption(
                          label: 'Bad',
                          icon: Icons.sentiment_very_dissatisfied_rounded,
                          iconColor: const Color(0xFFE74C3C),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 174),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFD6DAE3), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Row(
                    children: <Widget>[
                      SizedBox(
                        width: 58,
                        height: 58,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xFFDCE9FF),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.bed_rounded,
                            color: Color(0xFF3D7BE6),
                            size: 28,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'How did you sleep?',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF273444),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildSleepOption(
                            label: 'Great',
                            selected: _selectedSleep == 'Great',
                            onTap: () => setState(() => _selectedSleep = 'Great'),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildSleepOption(
                            label: 'Good',
                            selected: _selectedSleep == 'Good',
                            onTap: () => setState(() => _selectedSleep = 'Good'),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildSleepOption(
                            label: 'Fair',
                            selected: _selectedSleep == 'Fair',
                            onTap: () => setState(() => _selectedSleep = 'Fair'),
                          ),
                        ),
                      ),
                      Expanded(
                        child: _buildSleepOption(
                          label: 'Poor',
                          selected: _selectedSleep == 'Poor',
                          onTap: () => setState(() => _selectedSleep = 'Poor'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFD6DAE3), width: 1.2),
              ),
              child: Column(
                children: <Widget>[
                  const Row(
                    children: <Widget>[
                      SizedBox(
                        width: 58,
                        height: 58,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xFFE9EEF9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: Color(0xFF5E72E4),
                            size: 28,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        "What's on your mind?",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF273444),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _mindController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Write your thoughts here...',
                      filled: true,
                      fillColor: const Color(0xFFF7F8FB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFD6DAE3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFD6DAE3)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _historyReady ? _submitWellnessLog : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF273444),
                  elevation: 3,
                  shadowColor: const Color(0x33000000),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Submit',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WellnessHistoryPage extends StatelessWidget {
  const _WellnessHistoryPage({required this.entries});

  final List<_WellnessLogEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wellness History'),
        backgroundColor: Colors.indigo[400],
        foregroundColor: Colors.white,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.account_circle, size: 30),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
          ),
        ],
      ),
      backgroundColor: Colors.indigo[400],
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: <Widget>[
          if (entries.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'No wellness history yet.',
                style: TextStyle(color: Color(0xFF4A5968)),
              ),
            )
          else
            ...entries.map((entry) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entry.date,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF273444),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('Mood: ${entry.mood}'),
                    Text('Sleep: ${entry.sleep}'),
                    Text(
                      'Notes: ${entry.note.isEmpty ? '(none)' : entry.note}',
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _WellnessLogCompletedPage extends StatelessWidget {
  const _WellnessLogCompletedPage({required this.entries});

  final List<_WellnessLogEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo[400],
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF2EA66A),
                    size: 56,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Wellness log completed today!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF273444),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.popUntil(
                              context,
                              (route) => route.isFirst,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo[400],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Return home',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    _WellnessHistoryPage(entries: entries),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF273444),
                            side: const BorderSide(color: Color(0xFFD6DAE3)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'View history',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WellnessLogEntry {
  const _WellnessLogEntry({
    required this.date,
    required this.mood,
    required this.sleep,
    required this.note,
  });

  final String date;
  final String mood;
  final String sleep;
  final String note;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'date': date,
      'mood': mood,
      'sleep': sleep,
      'note': note,
    };
  }

  factory _WellnessLogEntry.fromJson(Map<String, dynamic> json) {
    return _WellnessLogEntry(
      date: (json['date'] ?? '').toString(),
      mood: (json['mood'] ?? '').toString(),
      sleep: (json['sleep'] ?? '').toString(),
      note: (json['note'] ?? '').toString(),
    );
  }
}