import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:alzheimers_project/profile_page.dart';
import 'package:alzheimers_project/services/guest_mode.dart';
import 'package:alzheimers_project/services/openai_service.dart';
import 'package:alzheimers_project/services/user_data_service.dart';

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
    try {
      final snapshot = await UserDataService.instance
          .wellnessLogsCol()
          .orderBy('date', descending: true)
          .get();
      final List<_WellnessLogEntry> entries = snapshot.docs
          .map((doc) => _WellnessLogEntry.fromMap(doc.data()))
          .toList();

      if (!mounted) return;
      setState(() {
        _history
          ..clear()
          ..addAll(entries);
        _historyReady = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _historyReady = true;
      });
    }
  }

  Future<void> _submitWellnessLog() async {
    if (_hasSubmittedToday()) {
      _redirectToCompletedPage();
      return;
    }
    if (guestBlocked(context, feature: 'submit wellness logs')) return;

    final String dateLabel = _todayKey();

    final _WellnessLogEntry entry = _WellnessLogEntry(
      date: dateLabel,
      mood: _selectedMood ?? 'Not selected',
      sleep: _selectedSleep ?? 'Not selected',
      note: _mindController.text.trim(),
    );

    try {
      await UserDataService.instance
          .wellnessLogsCol()
          .doc(dateLabel)
          .set(<String, dynamic>{
        ...entry.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save wellness log.')),
      );
      return;
    }

    setState(() {
      _history.insert(0, entry);
      _selectedMood = null;
      _selectedSleep = null;
      _mindController.clear();
    });

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

  static const Map<String, _MoodStyle> _moodStyles = <String, _MoodStyle>{
    'Great': _MoodStyle(
      icon: Icons.sentiment_very_satisfied_rounded,
      color: Color(0xFF2EA66A),
    ),
    'Good': _MoodStyle(
      icon: Icons.sentiment_satisfied_rounded,
      color: Color(0xFF3D7BE6),
    ),
    'Okay': _MoodStyle(
      icon: Icons.sentiment_neutral_rounded,
      color: Color(0xFFE5A11A),
    ),
    'Sad': _MoodStyle(
      icon: Icons.sentiment_dissatisfied_rounded,
      color: Color(0xFFFF7A1A),
    ),
    'Bad': _MoodStyle(
      icon: Icons.sentiment_very_dissatisfied_rounded,
      color: Color(0xFFE74C3C),
    ),
  };

  static const Map<String, int> _sleepStars = <String, int>{
    'Great': 4,
    'Good': 3,
    'Fair': 2,
    'Poor': 1,
  };

  static const List<String> _weekdayNames = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const List<String> _monthNames = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _formatDate(String isoDate) {
    final DateTime? parsed = DateTime.tryParse(isoDate);
    if (parsed == null) return isoDate;
    final String weekday = _weekdayNames[parsed.weekday - 1];
    final String month = _monthNames[parsed.month - 1];
    return '$weekday, $month ${parsed.day}';
  }

  _MoodStyle _moodStyleFor(String mood) {
    return _moodStyles[mood] ??
        const _MoodStyle(
          icon: Icons.help_outline_rounded,
          color: Color(0xFF7B8493),
        );
  }

  int _sleepScoreFor(String sleep) => _sleepStars[sleep] ?? 0;

  @override
  Widget build(BuildContext context) {
    final int totalEntries = entries.length;
    final Map<String, int> moodCounts = <String, int>{};
    for (final _WellnessLogEntry e in entries) {
      moodCounts[e.mood] = (moodCounts[e.mood] ?? 0) + 1;
    }
    final String topMood = moodCounts.isEmpty
        ? '-'
        : (moodCounts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key;

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
      body: SafeArea(
        child: entries.isEmpty
            ? _buildEmptyState()
            : ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                children: <Widget>[
                  _buildSummaryCard(totalEntries, topMood),
                  const SizedBox(height: 14),
                  ...entries.map(_buildEntryCard),
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFE9EEF9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 34,
                  color: Color(0xFF5E72E4),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'No wellness history yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF273444),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Submit a daily wellness log to see your mood and sleep trends here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF5C6675),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(int total, String topMood) {
    final _MoodStyle style = _moodStyleFor(topMood);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Logged Days',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7B8493),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$total',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF202939),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 44,
            color: const Color(0xFFE3E7ED),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Most Common Mood',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7B8493),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    Icon(style.icon, color: style.color, size: 22),
                    const SizedBox(width: 6),
                    Text(
                      topMood,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF202939),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(_WellnessLogEntry entry) {
    final _MoodStyle moodStyle = _moodStyleFor(entry.mood);
    final int sleepStars = _sleepScoreFor(entry.sleep);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: IntrinsicHeight(
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            width: 6,
            decoration: BoxDecoration(
              color: moodStyle.color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _formatDate(entry.date),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF202939),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      _buildMoodChip(entry.mood, moodStyle),
                      const SizedBox(width: 8),
                      _buildSleepChip(entry.sleep, sleepStars),
                    ],
                  ),
                  if (entry.note.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Icon(
                            Icons.format_quote_rounded,
                            size: 18,
                            color: Color(0xFF8A93A3),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.note,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.35,
                                color: Color(0xFF4A5968),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildMoodChip(String mood, _MoodStyle style) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Color.lerp(style.color, Colors.white, 0.85),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(style.icon, color: style.color, size: 18),
          const SizedBox(width: 6),
          Text(
            mood,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: style.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSleepChip(String label, int stars) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5DD),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < 4; i++)
            Padding(
              padding: EdgeInsets.only(right: i == 3 ? 6 : 1),
              child: Icon(
                Icons.star_rounded,
                size: 14,
                color: i < stars
                    ? const Color(0xFFE5A11A)
                    : const Color(0xFFE3E7ED),
              ),
            ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF9A6A00),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodStyle {
  const _MoodStyle({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

class _WellnessLogCompletedPage extends StatefulWidget {
  const _WellnessLogCompletedPage({required this.entries});

  final List<_WellnessLogEntry> entries;

  @override
  State<_WellnessLogCompletedPage> createState() =>
      _WellnessLogCompletedPageState();
}

class _WellnessLogCompletedPageState extends State<_WellnessLogCompletedPage> {
  bool _analyzing = false;
  Map<String, dynamic>? _analysis;

  _WellnessLogEntry? get _latest =>
      widget.entries.isEmpty ? null : widget.entries.first;

  Future<void> _analyzeLatest() async {
    final _WellnessLogEntry? entry = _latest;
    if (entry == null) return;
    setState(() => _analyzing = true);
    try {
      final result = await OpenAIService.instance
          .analyzeWellnessNote('Mood: ${entry.mood}. Sleep: ${entry.sleep}. '
              'Notes: ${entry.note.isEmpty ? "(none)" : entry.note}');
      if (!mounted) return;
      setState(() => _analysis = result);
    } on OpenAIUnconfiguredException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('AI analysis failed: $e')));
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Color _concernColor(String level) {
    switch (level.toLowerCase()) {
      case 'high':
        return const Color(0xFFEF4444);
      case 'medium':
        return const Color(0xFFE5A11A);
      default:
        return const Color(0xFF2EA66A);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo[400],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
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
                  if (_latest != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _analyzing ? null : _analyzeLatest,
                        icon: _analyzing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.auto_awesome_rounded,
                                size: 18,
                              ),
                        label: const Text('Analyze with AI'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5E72E4),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  if (_analysis != null) ...<Widget>[
                    const SizedBox(height: 12),
                    _buildAnalysisCard(_analysis!),
                  ],
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
                                    _WellnessHistoryPage(entries: widget.entries),
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

  Widget _buildAnalysisCard(Map<String, dynamic> a) {
    final String summary = (a['summary'] ?? '').toString();
    final String concernLevel = (a['concernLevel'] ?? 'low').toString();
    final List<dynamic> moodSignals =
        a['moodSignals'] is List ? a['moodSignals'] as List<dynamic> : const [];
    final List<dynamic> observations = a['observations'] is List
        ? a['observations'] as List<dynamic>
        : const [];
    final Color concern = _concernColor(concernLevel);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Color.lerp(concern, Colors.white, 0.8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Concern: $concernLevel',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: concern,
                  ),
                ),
              ),
            ],
          ),
          if (summary.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            MarkdownBlock(
              data: summary,
              config: MarkdownConfig.defaultConfig,
            ),
          ],
          if (moodSignals.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: moodSignals.map((m) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF0FB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    m.toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF5E72E4),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          if (observations.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            ...observations.map((o) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('• ',
                          style: TextStyle(
                              color: Color(0xFF7B8493),
                              fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text(
                          o.toString(),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF4A5968),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
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

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'date': date,
      'mood': mood,
      'sleep': sleep,
      'note': note,
    };
  }

  factory _WellnessLogEntry.fromMap(Map<String, dynamic> data) {
    return _WellnessLogEntry(
      date: (data['date'] ?? '').toString(),
      mood: (data['mood'] ?? '').toString(),
      sleep: (data['sleep'] ?? '').toString(),
      note: (data['note'] ?? '').toString(),
    );
  }
}