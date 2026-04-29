import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'services/openai_service.dart';
import 'services/user_data_service.dart';
import 'profile_page.dart';

class CognitiveCheckPage extends StatefulWidget {
  const CognitiveCheckPage({super.key});

  @override
  State<CognitiveCheckPage> createState() => _CognitiveCheckPageState();
}

class _CognitiveCheckPageState extends State<CognitiveCheckPage> {
  static const List<_VisualOption> _picturePool = <_VisualOption>[
    _VisualOption(id: 'Apple', label: 'Apple', icon: Icons.apple),
    _VisualOption(id: 'Key', label: 'Key', icon: Icons.key),
    _VisualOption(id: 'Book', label: 'Book', icon: Icons.book),
    _VisualOption(id: 'Tree', label: 'Tree', icon: Icons.park),
    _VisualOption(id: 'Car', label: 'Car', icon: Icons.directions_car),
    _VisualOption(id: 'Star', label: 'Star', icon: Icons.star),
    _VisualOption(id: 'Heart', label: 'Heart', icon: Icons.favorite),
    _VisualOption(id: 'Sun', label: 'Sun', icon: Icons.wb_sunny),
    _VisualOption(id: 'Moon', label: 'Moon', icon: Icons.nightlight_round),
    _VisualOption(id: 'Cup', label: 'Cup', icon: Icons.local_cafe),
    _VisualOption(id: 'Phone', label: 'Phone', icon: Icons.phone),
    _VisualOption(id: 'Camera', label: 'Camera', icon: Icons.camera_alt),
  ];

  static const List<String> _wordPool = <String>[
    'House',
    'Flower',
    'Spoon',
    'Bottle',
    'Window',
    'Garden',
    'Market',
    'Pillow',
    'River',
    'Bridge',
    'Candle',
    'Mountain',
    'Letter',
    'Mirror',
    'Guitar',
    'Clock',
  ];

  static const int _pictureTargetCount = 2;
  static const int _pictureDistractorCount = 2;
  static const int _wordTargetCount = 3;
  static const int _wordDistractorCount = 2;
  static const int _recognitionDistractorCount = 3;

  late List<String> _pictureTargets;
  late List<_VisualOption> _pictureOptions;
  late List<String> _wordTargets;
  late List<String> _wordOptions;
  late String _recognitionTarget;
  late List<String> _recognitionOptions;

  static const List<String> _dayOfWeekOptions = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const List<_ColorSwatch> _colorPool = <_ColorSwatch>[
    _ColorSwatch('Blue', Color(0xFF3D7BE6)),
    _ColorSwatch('Green', Color(0xFF2EA66A)),
    _ColorSwatch('Red', Color(0xFFEF4444)),
    _ColorSwatch('Yellow', Color(0xFFF59E0B)),
    _ColorSwatch('Purple', Color(0xFF8E44AD)),
    _ColorSwatch('Orange', Color(0xFFFF7A1A)),
    _ColorSwatch('Pink', Color(0xFFEC4899)),
    _ColorSwatch('Teal', Color(0xFF14B8A6)),
  ];
  static const int _sequenceLength = 3;
  static const int _sequenceDistractorCount = 2;

  late List<_ColorSwatch> _sequenceTarget;
  late List<List<_ColorSwatch>> _sequenceOptions;

  int _step = 0;
  int _score = 0;

  final Set<String> _pictureImmediateAnswers = <String>{};
  final Set<String> _wordRecallAnswers = <String>{};
  int? _dayOfWeekAnswer;
  List<_ColorSwatch>? _sequenceAnswer;
  String? _recognitionAnswer;
  final Set<String> _delayedPictureAnswers = <String>{};
  static final List<int> _assessmentHistory = <int>[];
  late List<_VisualOption> _shuffledPictureOptions;
  late List<String> _shuffledWordOptions;
  late List<List<_ColorSwatch>> _shuffledSequenceOptions;
  late List<String> _shuffledRecognitionOptions;

  String _sequenceKey(List<_ColorSwatch> seq) =>
      seq.map((_ColorSwatch c) => c.name).join(',');

  // Feature 4: AI-generated themed exercise set that overrides the random
  // pool for the next round. Cleared after one use.
  Map<String, dynamic>? _aiThemedSet;
  bool _loadingThemedSet = false;

  // Feature 1: AI trend summary of recent assessments.
  String? _trendSummary;
  bool _loadingTrend = false;

  @override
  void initState() {
    super.initState();
    _randomizeRound();
    _loadAssessmentHistory();
  }

  void _randomizeRound() {
    final Random random = Random();

    List<_VisualOption> pictureTargetOptions;
    List<_VisualOption> pictureDistractors;
    List<String> wordTargets;
    List<String> wordDistractors;

    final Map<String, dynamic>? ai = _aiThemedSet;
    if (ai != null) {
      List<String> asStrings(dynamic v) => v is List
          ? v.map((e) => e.toString()).toList(growable: false)
          : <String>[];
      List<_VisualOption> pick(List<String> ids) => ids
          .map((String id) => _picturePool
              .firstWhere((p) => p.id == id, orElse: () => _picturePool.first))
          .toList();
      pictureTargetOptions = pick(asStrings(ai['pictureTargets']));
      pictureDistractors = pick(asStrings(ai['pictureDistractors']));
      wordTargets = asStrings(ai['wordTargets']);
      wordDistractors = asStrings(ai['wordDistractors']);
      _aiThemedSet = null; // consume once
    } else {
      final List<_VisualOption> pictures =
          List<_VisualOption>.from(_picturePool)..shuffle(random);
      pictureTargetOptions = pictures.take(_pictureTargetCount).toList();
      pictureDistractors = pictures
          .skip(_pictureTargetCount)
          .take(_pictureDistractorCount)
          .toList();

      final List<String> words = List<String>.from(_wordPool)..shuffle(random);
      wordTargets = words.take(_wordTargetCount).toList();
      wordDistractors = words
          .skip(_wordTargetCount)
          .take(_wordDistractorCount)
          .toList();
    }

    _pictureTargets =
        pictureTargetOptions.map((_VisualOption o) => o.id).toList();
    _pictureOptions = <_VisualOption>[
      ...pictureTargetOptions,
      ...pictureDistractors,
    ];
    _wordTargets = wordTargets;
    _wordOptions = <String>[...wordTargets, ...wordDistractors];

    _recognitionTarget = _wordTargets[random.nextInt(_wordTargets.length)];
    final List<String> recognitionDistractors =
        (List<String>.from(_wordPool)..shuffle(random))
            .where((String w) => !_wordTargets.contains(w))
            .take(_recognitionDistractorCount)
            .toList();
    _recognitionOptions = <String>[
      _recognitionTarget,
      ...recognitionDistractors,
    ];

    _sequenceTarget = (List<_ColorSwatch>.from(_colorPool)..shuffle(random))
        .take(_sequenceLength)
        .toList();
    _sequenceOptions = <List<_ColorSwatch>>[_sequenceTarget];
    int safety = 0;
    while (_sequenceOptions.length < 1 + _sequenceDistractorCount &&
        safety < 50) {
      safety += 1;
      final List<_ColorSwatch> candidate =
          (List<_ColorSwatch>.from(_colorPool)..shuffle(random))
              .take(_sequenceLength)
              .toList();
      final String key = _sequenceKey(candidate);
      final bool duplicate = _sequenceOptions
          .any((List<_ColorSwatch> s) => _sequenceKey(s) == key);
      if (!duplicate) {
        _sequenceOptions.add(candidate);
      }
    }

    _shuffledPictureOptions = List<_VisualOption>.from(_pictureOptions)
      ..shuffle(random);
    _shuffledWordOptions = List<String>.from(_wordOptions)..shuffle(random);
    _shuffledSequenceOptions =
        List<List<_ColorSwatch>>.from(_sequenceOptions)..shuffle(random);
    _shuffledRecognitionOptions = List<String>.from(_recognitionOptions)
      ..shuffle(random);
  }

  int get _maxScore {
    return _pictureTargets.length +
        _wordTargets.length +
        1 +
        1 +
        1 +
        _pictureTargets.length;
  }

  int get _todayWeekdayIndex => DateTime.now().weekday - 1;
  int get _latestAssessmentScore =>
      _assessmentHistory.isNotEmpty ? _assessmentHistory.first : _score;

  Future<void> _loadAssessmentHistory() async {
    try {
      final snapshot = await UserDataService.instance
          .cognitiveAssessmentsCol()
          .orderBy('createdAt', descending: true)
          .get();
      final List<int> parsedHistory = snapshot.docs
          .map((doc) => (doc.data()['score'] as num?)?.toInt())
          .whereType<int>()
          .toList();

      if (!mounted) return;
      setState(() {
        _assessmentHistory
          ..clear()
          ..addAll(parsedHistory);
        if (_score == 0 && _assessmentHistory.isNotEmpty) {
          _score = _assessmentHistory.first;
        }
      });
    } catch (_) {
      // Fail-safe: render page even if load fails.
    }
  }

  Future<void> _generateTrendInsight() async {
    if (_loadingTrend) return;
    setState(() => _loadingTrend = true);
    try {
      final snapshot = await UserDataService.instance
          .cognitiveAssessmentsCol()
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();
      final List<Map<String, dynamic>> data = snapshot.docs.map((doc) {
        final d = doc.data();
        final ts = d['createdAt'];
        String dateLabel = '';
        if (ts != null) {
          try {
            dateLabel = ts.toDate().toIso8601String().split('T').first;
          } catch (_) {}
        }
        return <String, dynamic>{
          'score': d['score'],
          'maxScore': d['maxScore'],
          'date': dateLabel,
        };
      }).toList();
      final String summary =
          await OpenAIService.instance.analyzeCognitiveTrend(data);
      if (!mounted) return;
      setState(() => _trendSummary = summary);
    } on OpenAIUnconfiguredException catch (e) {
      if (!mounted) return;
      setState(() => _trendSummary = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _trendSummary = 'Could not generate insight: $e');
    } finally {
      if (mounted) setState(() => _loadingTrend = false);
    }
  }

  Future<void> _generateThemedExerciseSet() async {
    if (_loadingThemedSet) return;
    setState(() => _loadingThemedSet = true);
    try {
      final Map<String, dynamic> result =
          await OpenAIService.instance.generateThemedExerciseSet(
        availablePictureIds: _picturePool.map((p) => p.id).toList(),
        availableWords: _wordPool,
        pictureTargetCount: _pictureTargetCount,
        pictureDistractorCount: _pictureDistractorCount,
        wordTargetCount: _wordTargetCount,
        wordDistractorCount: _wordDistractorCount,
      );
      if (!mounted) return;
      setState(() => _aiThemedSet = result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Theme ready: "${result['theme'] ?? 'custom set'}". Tap Start to begin.',
          ),
        ),
      );
    } on OpenAIUnconfiguredException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not generate themed set: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingThemedSet = false);
    }
  }

  Future<void> _saveLatestAssessment(int score) async {
    try {
      await UserDataService.instance
          .cognitiveAssessmentsCol()
          .add(<String, dynamic>{
        'score': score,
        'maxScore': _maxScore,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Ignore; in-memory history is already updated.
    }
  }

  void _goToNextStep() {
    if (_step < 9) {
      setState(() {
        final int nextStep = _step + 1;
        if (nextStep == 1) {
          // Fresh randomization + clean slate every time Start is tapped,
          // so users don't see the same targets across tab visits.
          _randomizeRound();
          _pictureImmediateAnswers.clear();
          _wordRecallAnswers.clear();
          _dayOfWeekAnswer = null;
          _sequenceAnswer = null;
          _recognitionAnswer = null;
          _delayedPictureAnswers.clear();
        }
        if (nextStep == 2) {
          _shuffledPictureOptions = List<_VisualOption>.from(_pictureOptions)
            ..shuffle(Random());
        }
        _step += 1;
      });
    }
  }

  void _finishAssessment() {
    final int pictureImmediateScore =
        _pictureImmediateAnswers
            .where((String answer) => _pictureTargets.contains(answer))
            .length;

    final int wordRecallScore =
        _wordRecallAnswers
            .where((String answer) => _wordTargets.contains(answer))
            .length;

    final int orientationScore = _dayOfWeekAnswer == _todayWeekdayIndex ? 1 : 0;

    final int sequenceScore = (_sequenceAnswer != null &&
            _sequenceKey(_sequenceAnswer!) == _sequenceKey(_sequenceTarget))
        ? 1
        : 0;

    final int recognitionScore =
        _recognitionAnswer == _recognitionTarget ? 1 : 0;

    final int delayedPictureScore =
        _delayedPictureAnswers
            .where((String answer) => _pictureTargets.contains(answer))
            .length;

    final int totalScore = pictureImmediateScore +
        wordRecallScore +
        orientationScore +
        sequenceScore +
        recognitionScore +
        delayedPictureScore;

    setState(() {
      _score = totalScore;
      _assessmentHistory.insert(0, totalScore);
      _step = 9;
    });
    _saveLatestAssessment(totalScore);
  }

  void _restartAssessment() {
    setState(() {
      _randomizeRound();
      _step = 0;
      _pictureImmediateAnswers.clear();
      _wordRecallAnswers.clear();
      _dayOfWeekAnswer = null;
      _sequenceAnswer = null;
      _recognitionAnswer = null;
      _delayedPictureAnswers.clear();
    });
  }

  Widget _buildHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 16, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Widget _buildMultiSelectOptions({
    required List<String> options,
    required Set<String> selectedValues,
    required void Function(String value, bool selected) onToggle,
  }) {
    return Column(
      children: options.map((String option) {
        final bool isSelected = selectedValues.contains(option);
        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => onToggle(option, !isSelected),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF5E72E4)
                    : const Color(0xFFD6DAE3),
                width: isSelected ? 2 : 1.5,
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    option,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF273444),
                    ),
                  ),
                ),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? const Color(0xFF5E72E4)
                        : const Color(0xFFE3E7ED),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 11, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVisualMultiSelectOptions({
    required List<_VisualOption> options,
    required Set<String> selectedValues,
    required void Function(String value, bool selected) onToggle,
    bool iconOnly = false,
  }) {
    return Column(
      children: options.map((_VisualOption option) {
        final bool isSelected = selectedValues.contains(option.id);
        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => onToggle(option.id, !isSelected),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF5E72E4)
                    : const Color(0xFFD6DAE3),
                width: isSelected ? 2 : 1.5,
              ),
            ),
            child: Row(
              children: <Widget>[
                if (iconOnly)
                  Expanded(
                    child: Center(
                      child: Icon(
                        option.icon,
                        size: 20,
                        color: const Color(0xFF2E63DE),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Row(
                      children: <Widget>[
                        Icon(
                          option.icon,
                          size: 18,
                          color: const Color(0xFF2E63DE),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          option.label,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF273444),
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? const Color(0xFF5E72E4)
                        : const Color(0xFFE3E7ED),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 11, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuestionPanel({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3F7),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              color: Color(0xFFDCE5F7),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: const Color(0xFF2E63DE)),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF273444),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF4A5968),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDayOfWeekOption({
    required int index,
    required String label,
    required bool isSelected,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        setState(() {
          _dayOfWeekAnswer = index;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? const Color(0xFF5E72E4) : const Color(0xFFD6DAE3),
            width: isSelected ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF273444),
                ),
              ),
            ),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? const Color(0xFF5E72E4) : const Color(0xFFE3E7ED),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 11, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleSelectOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? const Color(0xFF5E72E4) : const Color(0xFFD6DAE3),
            width: isSelected ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF273444),
                ),
              ),
            ),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? const Color(0xFF5E72E4) : const Color(0xFFE3E7ED),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 11, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorSequence(
    List<_ColorSwatch> sequence, {
    bool showLabels = false,
    double chipSize = 52,
  }) {
    final List<Widget> children = <Widget>[];
    for (int i = 0; i < sequence.length; i++) {
      final _ColorSwatch c = sequence[i];
      children.add(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: chipSize,
              height: chipSize,
              decoration: BoxDecoration(
                color: c.color,
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: c.color.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
            if (showLabels) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                c.name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4A5968),
                ),
              ),
            ],
          ],
        ),
      );
      if (i != sequence.length - 1) {
        children.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 20,
              color: Color(0xFF7B8493),
            ),
          ),
        );
      }
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: children,
    );
  }

  Widget _buildColorSequenceOption({
    required List<_ColorSwatch> sequence,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF5E72E4)
                : const Color(0xFFD6DAE3),
            width: isSelected ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: _buildColorSequence(sequence, chipSize: 34),
            ),
            const SizedBox(width: 10),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? const Color(0xFF5E72E4)
                    : const Color(0xFFE3E7ED),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 11, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiInsightsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF0FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC8CEE4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFF5E72E4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'AI Insights',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF202939),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loadingTrend ? null : _generateTrendInsight,
              icon: _loadingTrend
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.trending_up_rounded, size: 18),
              label: const Text('Analyze my trend'),
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
          if (_trendSummary != null) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: MarkdownBlock(
                data: _trendSummary!,
                config: MarkdownConfig.defaultConfig,
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _loadingThemedSet ? null : _generateThemedExerciseSet,
              icon: _loadingThemedSet
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF5E72E4),
                      ),
                    )
                  : const Icon(Icons.palette_outlined, size: 18),
              label: Text(
                _aiThemedSet != null
                    ? 'Themed set ready - tap Start'
                    : 'Generate themed exercise',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF5E72E4),
                side: const BorderSide(color: Color(0xFF5E72E4)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _buildCard(
          child: Column(
            children: <Widget>[
              _buildQuestionPanel(
                icon: Icons.psychology_alt_rounded,
                title: 'Quick Memory Assessment',
                subtitle:
                    'This check has 5 short memory activities. Take your time and tap your best answer.',
                children: <Widget>[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _goToNextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo[400],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Start'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F3F7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD6DAE3), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Current Score',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF273444),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$_latestAssessmentScore / $_maxScore',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E63DE),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F3F7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD6DAE3), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Assessment History',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF273444),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_assessmentHistory.isEmpty)
                      const Text(
                        'No previous assessments yet.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF4A5968),
                        ),
                      )
                    else
                      ..._assessmentHistory.take(5).toList().asMap().entries.map((
                        entry,
                      ) {
                        final int index = _assessmentHistory.length - entry.key;
                        final int score = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Attempt $index: $score / $_maxScore',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF4A5968),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _buildAiInsightsCard(),
            ],
          ),
        );

      case 1:
        return _buildCard(
          child: _buildQuestionPanel(
            icon: Icons.image_search_rounded,
            title: '1) Picture Recall',
            subtitle:
                'Remember these pictures. You will be asked about them now and later.',
            children: <Widget>[
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: _pictureTargets.map((String id) {
                  final _VisualOption opt = _picturePool.firstWhere(
                    (_VisualOption o) => o.id == id,
                  );
                  return Chip(
                    label: SizedBox(
                      width: 28,
                      height: 28,
                      child: Center(child: Icon(opt.icon, size: 22)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _goToNextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo[400],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('I am ready'),
                ),
              ),
            ],
          ),
        );

      case 2:
        return _buildCard(
          child: _buildQuestionPanel(
            icon: Icons.photo_library_outlined,
            title: '1) Picture Recall',
            subtitle: 'Select the pictures you saw.',
            children: <Widget>[
              _buildVisualMultiSelectOptions(
                options: _shuffledPictureOptions,
                selectedValues: _pictureImmediateAnswers,
                iconOnly: true,
                onToggle: (String value, bool selected) {
                  setState(() {
                    if (selected) {
                      _pictureImmediateAnswers.add(value);
                    } else {
                      _pictureImmediateAnswers.remove(value);
                    }
                  });
                },
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _goToNextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo[400],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        );

      case 3:
        return _buildCard(
          child: _buildQuestionPanel(
            icon: Icons.menu_book_rounded,
            title: '2) Word List Recall',
            subtitle:
                'Please remember these words: ${_wordTargets.join(', ')}.',
            children: <Widget>[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _goToNextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo[400],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Hide words and answer'),
                ),
              ),
            ],
          ),
        );

      case 4:
        return _buildCard(
          child: _buildQuestionPanel(
            icon: Icons.fact_check_outlined,
            title: '2) Word List Recall',
            subtitle: 'Select the words you just saw.',
            children: <Widget>[
              _buildMultiSelectOptions(
                options: _shuffledWordOptions,
                selectedValues: _wordRecallAnswers,
                onToggle: (String value, bool selected) {
                  setState(() {
                    if (selected) {
                      _wordRecallAnswers.add(value);
                    } else {
                      _wordRecallAnswers.remove(value);
                    }
                  });
                },
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _goToNextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo[400],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        );

      case 5:
        return _buildCard(
          child: _buildQuestionPanel(
            icon: Icons.calendar_today_rounded,
            title: '3) Date & Time',
            subtitle: 'What day of the week is today?',
            children: <Widget>[
              ..._dayOfWeekOptions.asMap().entries.map((entry) {
                return _buildDayOfWeekOption(
                  index: entry.key,
                  label: entry.value,
                  isSelected: _dayOfWeekAnswer == entry.key,
                );
              }),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _goToNextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo[400],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        );

      case 6:
        return _buildCard(
          child: _buildQuestionPanel(
            icon: Icons.palette_rounded,
            title: '4) Color Sequence',
            subtitle: 'Remember this color sequence in order.',
            children: <Widget>[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFD6DAE3), width: 1.5),
                ),
                child: _buildColorSequence(_sequenceTarget, showLabels: true),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _goToNextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo[400],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('I am ready to answer'),
                ),
              ),
            ],
          ),
        );

      case 7:
        return _buildCard(
          child: _buildQuestionPanel(
            icon: Icons.palette_rounded,
            title: '4) Color Sequence',
            subtitle: 'Pick the color sequence you saw.',
            children: <Widget>[
              ..._shuffledSequenceOptions.map((List<_ColorSwatch> option) {
                final bool isSelected = _sequenceAnswer != null &&
                    _sequenceKey(_sequenceAnswer!) == _sequenceKey(option);
                return _buildColorSequenceOption(
                  sequence: option,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() {
                      _sequenceAnswer = option;
                    });
                  },
                );
              }),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _goToNextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo[400],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        );

      case 8:
        return _buildCard(
          child: _buildQuestionPanel(
            icon: Icons.psychology_alt_outlined,
            title: '5) Recognition + Delayed Picture Recall',
            subtitle: 'Complete both parts below.',
            children: <Widget>[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Part A: Which one word appeared in Question 2?',
                  style: TextStyle(fontSize: 13, color: Color(0xFF4A5968)),
                ),
              ),
              const SizedBox(height: 8),
              ..._shuffledRecognitionOptions.map((String option) {
                return _buildSingleSelectOption(
                  label: option,
                  isSelected: _recognitionAnswer == option,
                  onTap: () {
                    setState(() {
                      _recognitionAnswer = option;
                    });
                  },
                );
              }),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Part B: Which pictures did you see at the beginning?',
                  style: TextStyle(fontSize: 13, color: Color(0xFF4A5968)),
                ),
              ),
              const SizedBox(height: 8),
              _buildVisualMultiSelectOptions(
                options: _shuffledPictureOptions,
                selectedValues: _delayedPictureAnswers,
                iconOnly: true,
                onToggle: (String value, bool selected) {
                  setState(() {
                    if (selected) {
                      _delayedPictureAnswers.add(value);
                    } else {
                      _delayedPictureAnswers.remove(value);
                    }
                  });
                },
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _finishAssessment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo[400],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Finish Assessment'),
                ),
              ),
            ],
          ),
        );

      case 9:
        return _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Assessment Complete',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'Score: $_score / $_maxScore',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'This is a quick wellness check and not a diagnosis.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _restartAssessment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo[400],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Try Again'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _restartAssessment();
                      _step = 0;
                    });
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.indigo[400],
                    side: BorderSide(color: Colors.indigo[400]!),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool showStepText = _step > 0 && _step < 9;
    final bool showProgressBar = _step > 0;
    const int totalQuestions = 5;
    final int completedQuestions;
    if (_step >= 9) {
      completedQuestions = 5;
    } else if (_step >= 8) {
      completedQuestions = 4;
    } else if (_step >= 6) {
      completedQuestions = 3;
    } else if (_step >= 5) {
      completedQuestions = 2;
    } else if (_step >= 3) {
      completedQuestions = 1;
    } else {
      completedQuestions = 0;
    }
    final double progressValue =
        showProgressBar ? (completedQuestions / totalQuestions) : 0.0;
    final int progressPercent = (progressValue * 100).round();

    return Scaffold(
      appBar: AppBar(
        title: const SizedBox.shrink(),
        backgroundColor: Colors.indigo[400],
        foregroundColor: Colors.white,
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: IconButton(
              icon: const Icon(Icons.account_circle, size: 30.0),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                );
              },
            ),
          ),
        ],
      ),
      backgroundColor: Colors.indigo[400],
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildHeader(
                'Cognitive Check',
                showStepText
                    ? 'Step $_step of 8'
                    : _step >= 9
                    ? 'Assessment complete.'
                    : 'Short, simple exercises to track memory patterns.',
              ),
              const SizedBox(height: 6),
              if (showProgressBar) ...<Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progressValue,
                          minHeight: 8,
                          backgroundColor: const Color(0x66C9CFDA),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$progressPercent%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
              _buildStepContent(),
            ],
          ),
        ),
      ),
    );
  }
}

class _VisualOption {
  const _VisualOption({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final IconData icon;
}

class _ColorSwatch {
  const _ColorSwatch(this.name, this.color);

  final String name;
  final Color color;
}