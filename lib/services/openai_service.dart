import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

// NOTE: this service calls OpenAI directly from the client. Fine for a
// student/demo build, but ships the key inside the app bundle. For a public
// release, move these calls behind a backend proxy. Put the key in
// assets/.env as OPENAI_API_KEY=sk-... and ensure it is loaded via dotenv.
class OpenAIService {
  OpenAIService._();
  static final OpenAIService instance = OpenAIService._();

  static const String _endpoint =
      'https://api.openai.com/v1/chat/completions';
  static const String _model = 'gpt-4o-mini';

  String get _apiKey {
    try {
      return (dotenv.maybeGet('OPENAI_API_KEY') ?? '').trim();
    } catch (_) {
      return '';
    }
  }

  bool get isConfigured => _apiKey.isNotEmpty;

  Future<String> _chat({
    required String systemPrompt,
    required String userPrompt,
    bool jsonMode = false,
    double temperature = 0.6,
  }) async {
    final String key = _apiKey;
    if (key.isEmpty) {
      throw const OpenAIUnconfiguredException();
    }
    final response = await http.post(
      Uri.parse(_endpoint),
      headers: <String, String>{
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'model': _model,
        'messages': <Map<String, String>>[
          <String, String>{'role': 'system', 'content': systemPrompt},
          <String, String>{'role': 'user', 'content': userPrompt},
        ],
        'temperature': temperature,
        if (jsonMode)
          'response_format': <String, String>{'type': 'json_object'},
      }),
    );
    if (response.statusCode != 200) {
      throw OpenAIException(
        'OpenAI ${response.statusCode}: ${response.body}',
      );
    }
    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    final List<dynamic> choices = data['choices'] as List<dynamic>;
    final Map<String, dynamic> message =
        (choices.first as Map<String, dynamic>)['message']
            as Map<String, dynamic>;
    return (message['content'] ?? '').toString();
  }

  // Feature 1: plain-language trend summary over recent cognitive scores.
  Future<String> analyzeCognitiveTrend(
    List<Map<String, dynamic>> assessments,
  ) async {
    if (assessments.isEmpty) {
      return 'Complete a few assessments first to see trends.';
    }
    final String list = assessments
        .take(10)
        .map((a) =>
            '- ${a['score']}/${a['maxScore']} on ${a['date'] ?? 'unknown date'}')
        .join('\n');
    return _chat(
      systemPrompt:
          'You are a warm, cautious cognitive health assistant for an app used '
          'by older adults and caregivers. Summarize trends in plain, simple '
          'language (3–4 short sentences). Never diagnose. If the trend looks '
          'concerning (noticeable decline across multiple recent attempts), '
          'gently suggest discussing it with a doctor.',
      userPrompt:
          'Here are recent cognitive self-check scores (most recent first):\n'
          '$list\n\nPlease summarize what you see.',
      temperature: 0.4,
    );
  }

  // Feature 2: weekly caregiver digest combining cognitive, medication, wellness.
  Future<String> weeklyCaregiverDigest({
    required List<Map<String, dynamic>> cognitiveHistory,
    required int medsTaken,
    required int medsMissed,
    required List<Map<String, dynamic>> wellnessLogs,
  }) async {
    final String cog = cognitiveHistory.isEmpty
        ? '(no recent assessments)'
        : cognitiveHistory
            .take(5)
            .map((a) => '${a['score']}/${a['maxScore']}')
            .join(', ');
    final String wellness = wellnessLogs.isEmpty
        ? '(no recent wellness logs)'
        : wellnessLogs
            .take(7)
            .map((e) =>
                '${e['date']}: mood=${e['mood']}, sleep=${e['sleep']}')
            .join('\n');
    return _chat(
      systemPrompt:
          'You are writing a short weekly digest for a caregiver of someone '
          'at risk of Alzheimer\'s. Tone: warm, concrete, not alarmist. 4–6 '
          'short bullet points. Call out any concerning combinations (e.g. '
          'declining scores + missed medications + low mood). Close with a '
          'kind suggestion. Never diagnose.',
      userPrompt: 'Cognitive scores (recent first): $cog\n\n'
          'Medication adherence this week: $medsTaken taken, $medsMissed missed.\n\n'
          'Wellness logs:\n$wellness\n\n'
          'Write the weekly digest now.',
      temperature: 0.4,
    );
  }

  // Feature 3: analyze a wellness journal entry for mood/coherence signals.
  Future<Map<String, dynamic>> analyzeWellnessNote(String note) async {
    if (note.trim().isEmpty) {
      return <String, dynamic>{
        'summary': 'No journal entry to analyze.',
        'moodSignals': <String>[],
        'concernLevel': 'low',
      };
    }
    final String raw = await _chat(
      systemPrompt:
          'You analyze short journal entries from an older adult using a '
          'wellness app. Return strict JSON with fields: summary (1 short '
          'sentence), moodSignals (array of 1–3 short phrases), concernLevel '
          '("low" | "medium" | "high"), observations (array of up to 3 short '
          'notes about tone, clarity, or coherence). Be gentle and careful. '
          'Never diagnose.',
      userPrompt: 'Journal entry:\n"""$note"""\n\nReturn JSON only.',
      jsonMode: true,
      temperature: 0.3,
    );
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{
        'summary': raw,
        'moodSignals': <String>[],
        'concernLevel': 'low',
        'observations': <String>[],
      };
    }
  }

  // Feature 4: generate a themed exercise set by picking from available pools.
  Future<Map<String, dynamic>> generateThemedExerciseSet({
    required List<String> availablePictureIds,
    required List<String> availableWords,
    required int pictureTargetCount,
    required int pictureDistractorCount,
    required int wordTargetCount,
    required int wordDistractorCount,
  }) async {
    final String raw = await _chat(
      systemPrompt:
          'You design gentle memory exercises for older adults. Given a list '
          'of available picture ids and a list of available words, pick a '
          'themed subset suitable for a memory recall exercise. Return strict '
          'JSON with fields: theme (short phrase), pictureTargets (array of N '
          'ids), pictureDistractors (array of M ids, disjoint), wordTargets '
          '(array of K words), wordDistractors (array of L words, disjoint). '
          'Only use ids/words from the provided lists.',
      userPrompt: jsonEncode(<String, dynamic>{
        'availablePictureIds': availablePictureIds,
        'availableWords': availableWords,
        'counts': <String, int>{
          'pictureTargets': pictureTargetCount,
          'pictureDistractors': pictureDistractorCount,
          'wordTargets': wordTargetCount,
          'wordDistractors': wordDistractorCount,
        },
      }),
      jsonMode: true,
      temperature: 0.8,
    );
    return jsonDecode(raw) as Map<String, dynamic>;
  }
}

class OpenAIException implements Exception {
  const OpenAIException(this.message);
  final String message;
  @override
  String toString() => message;
}

class OpenAIUnconfiguredException extends OpenAIException {
  const OpenAIUnconfiguredException()
      : super(
          'OpenAI API key not configured. Set OPENAI_API_KEY in assets/env '
          'and restart the app to enable AI features.',
        );
}