import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_page.dart';

class CognitiveCheckPage extends StatefulWidget {
  const CognitiveCheckPage({super.key});

  @override
  State<CognitiveCheckPage> createState() => _CognitiveCheckPageState();
}

class _CognitiveCheckPageState extends State<CognitiveCheckPage> {
  static const List<String> _pictureTargets = <String>['Apple', 'Key'];
  static const List<_VisualOption> _pictureOptions = <_VisualOption>[
    _VisualOption(id: 'Apple', label: 'Apple', icon: Icons.apple),
    _VisualOption(id: 'Key', label: 'Key', icon: Icons.key),
    _VisualOption(id: 'Book', label: 'Book', icon: Icons.book),
    _VisualOption(id: 'Tree', label: 'Tree', icon: Icons.park),
  ];

  static const List<String> _wordTargets = <String>[
    'House',
    'Flower',
    'Spoon',
  ];
  static const List<String> _wordOptions = <String>[
    'House',
    'Flower',
    'Spoon',
    'Bottle',
    'Window',
  ];

  static const List<String> _dayOfWeekOptions = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const String _targetSequence = 'Blue -> Green';
  static const List<String> _sequenceOptions = <String>[
    'Blue -> Green',
    'Green -> Blue',
    'Blue -> Red',
  ];

  static const List<String> _recognitionOptions = <String>[
    'Flower',
    'Garden',
    'Market',
    'Pillow',
  ];
  static const String _recognitionTarget = 'Flower';

  int _step = 0;
  int _score = 0;

  final Set<String> _pictureImmediateAnswers = <String>{};
  final Set<String> _wordRecallAnswers = <String>{};
  int? _dayOfWeekAnswer;
  String? _sequenceAnswer;
  String? _recognitionAnswer;
  final Set<String> _delayedPictureAnswers = <String>{};
  static final List<int> _assessmentHistory = <int>[];
  late List<_VisualOption> _shuffledPictureOptions;
  late List<String> _shuffledWordOptions;
  late List<String> _shuffledSequenceOptions;
  late List<String> _shuffledRecognitionOptions;

  @override
  void initState() {
    super.initState();
    _shuffleAnswerOptions();
    _loadAssessmentHistory();
  }

  void _shuffleAnswerOptions() {
    _shuffledPictureOptions = List<_VisualOption>.from(_pictureOptions)
      ..shuffle();
    _shuffledWordOptions = List<String>.from(_wordOptions)..shuffle();
    _shuffledSequenceOptions = List<String>.from(_sequenceOptions)..shuffle();
    _shuffledRecognitionOptions = List<String>.from(_recognitionOptions)
      ..shuffle();
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
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Object? storedValue = prefs.get('assessment_history_scores');
    List<int> parsedHistory = <int>[];

    if (storedValue is List) {
      parsedHistory = storedValue
          .map((dynamic item) => int.tryParse(item.toString()))
          .whereType<int>()
          .toList();
    } else if (storedValue is int) {
      // Backward-compatible recovery for previously stored single score.
      parsedHistory = <int>[storedValue];
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _assessmentHistory
        ..clear()
        ..addAll(parsedHistory);
      if (_score == 0 && _assessmentHistory.isNotEmpty) {
        _score = _assessmentHistory.first;
      }
    });
  }

  Future<void> _saveAssessmentHistory() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'assessment_history_scores',
      _assessmentHistory.map((int score) => score.toString()).toList(),
    );
  }

  void _goToNextStep() {
    if (_step < 9) {
      setState(() {
        final int nextStep = _step + 1;
        if (nextStep == 2) {
          _shuffledPictureOptions = List<_VisualOption>.from(_pictureOptions)
            ..shuffle();
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

    final int sequenceScore = _sequenceAnswer == _targetSequence ? 1 : 0;

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
    _saveAssessmentHistory();
  }

  void _restartAssessment() {
    setState(() {
      _shuffleAnswerOptions();
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
              const Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: <Widget>[
                  Chip(
                    label: SizedBox(
                      width: 28,
                      height: 28,
                      child: Center(child: Icon(Icons.apple, size: 22)),
                    ),
                  ),
                  Chip(
                    label: SizedBox(
                      width: 28,
                      height: 28,
                      child: Center(child: Icon(Icons.key, size: 22)),
                    ),
                  ),
                ],
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
            subtitle: 'Please remember these words: House, Flower, Spoon.',
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
            icon: Icons.format_list_numbered_rounded,
            title: '4) Sequence Repeat',
            subtitle: 'Remember this sequence.',
            children: <Widget>[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFD6DAE3), width: 1.5),
                ),
                child: Text(
                  _targetSequence,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF273444),
                  ),
                ),
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
            icon: Icons.format_list_numbered_rounded,
            title: '4) Sequence Repeat',
            subtitle: 'Pick the sequence you remember from before.',
            children: <Widget>[
              ..._shuffledSequenceOptions.map((String option) {
                return _buildSingleSelectOption(
                  label: option,
                  isSelected: _sequenceAnswer == option,
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