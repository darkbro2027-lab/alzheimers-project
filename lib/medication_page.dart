import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_page.dart';

class MedicationPage extends StatefulWidget {
  const MedicationPage({super.key});

  @override
  State<MedicationPage> createState() => _MedicationPageState();
}

class _MedicationPageState extends State<MedicationPage> {
  static const String _medReminderKey = 'profile_medication_reminders';
  final List<_MedicationEntry> _medications = <_MedicationEntry>[];
  bool _showManageOptions = false;
  bool _medicationRemindersEnabled = true;

  static const List<String> _weekdayLabels = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  String get _todayLabel => _weekdayLabels[DateTime.now().weekday - 1];
  String get _todayKey => DateTime.now().toIso8601String().split('T').first;

  String _todayStatus(_MedicationEntry entry) {
    return entry.statusDate == _todayKey ? entry.status : '';
  }

  List<int> _todayMedicationIndexes() {
    final List<int> indexes = <int>[];
    for (int i = 0; i < _medications.length; i++) {
      if (_medications[i].days.contains(_todayLabel)) {
        indexes.add(i);
      }
    }
    return indexes;
  }

  void _sortMedicationsByTime() {
    _medications.sort(
      (a, b) => a.timeSortValue.compareTo(b.timeSortValue),
    );
  }

  void _updateMedicationStatus(int index, String status) {
    if (index < 0 || index >= _medications.length) {
      return;
    }
    setState(() {
      _medications[index] = _medications[index].copyWith(
        status: status,
        statusDate: _todayKey,
      );
    });
    _saveMedications();
  }

  @override
  void initState() {
    super.initState();
    _loadMedications();
  }

  Future<void> _loadMedications() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool remindersEnabled = prefs.getBool(_medReminderKey) ?? true;
    final List<String> rawList =
        prefs.getStringList('saved_medications') ?? <String>[];
    final List<_MedicationEntry> loaded = rawList
        .map((String item) {
          try {
            final Map<String, dynamic> data =
                jsonDecode(item) as Map<String, dynamic>;
            return _MedicationEntry.fromJson(data);
          } catch (_) {
            return null;
          }
        })
        .whereType<_MedicationEntry>()
        .toList();

    if (!mounted) {
      return;
    }
    setState(() {
      _medicationRemindersEnabled = remindersEnabled;
      _medications
        ..clear()
        ..addAll(loaded);
      _sortMedicationsByTime();
    });
  }

  Future<void> _saveMedications() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'saved_medications',
      _medications
          .map((entry) => jsonEncode(entry.toJson()))
          .toList(growable: false),
    );
  }

  Future<void> _openAddMedicationForm() async {
    final _MedicationEntry? newMedication = await Navigator.push<_MedicationEntry>(
      context,
      MaterialPageRoute(builder: (context) => const _AddMedicationFormPage()),
    );

    if (newMedication != null) {
      setState(() {
        _medications.add(newMedication);
        _sortMedicationsByTime();
      });
      _saveMedications();
    }
  }

  Future<void> _openManageMedications() async {
    final List<_MedicationEntry>? updatedList = await Navigator.push<List<_MedicationEntry>>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            _ManageMedicationsPage(initialMedications: List<_MedicationEntry>.from(_medications)),
      ),
    );

    if (updatedList != null) {
      setState(() {
        _medications
          ..clear()
          ..addAll(updatedList);
        _sortMedicationsByTime();
        _showManageOptions = false;
      });
      _saveMedications();
    }
  }

  void _openMedicationRecords() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _MedicationRecordsPage(medications: _medications),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<int> todayIndexes = _todayMedicationIndexes();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medication'),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 18, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: _openAddMedicationForm,
                  child: SizedBox(
                    width: double.infinity,
                    height: 86,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFDFF5E7),
                              border: Border.all(
                                color: const Color(0xFF2EA66A),
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.medication_rounded,
                              size: 28,
                              color: Color(0xFF2EA66A),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Add Medication',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _medicationRemindersEnabled
                        ? const Color(0xFF2EA66A)
                        : const Color(0xFFD6DAE3),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      _medicationRemindersEnabled
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_off_rounded,
                      color: _medicationRemindersEnabled
                          ? const Color(0xFF2EA66A)
                          : const Color(0xFF7B8493),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _medicationRemindersEnabled
                            ? 'Medication reminders are ON (from Profile).'
                            : 'Medication reminders are OFF (from Profile).',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF273444),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      sizeFactor: animation,
                      axisAlignment: -1,
                      child: child,
                    ),
                  );
                },
                child: !_showManageOptions
                    ? SizedBox(
                        key: const ValueKey('manage_single_button'),
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _showManageOptions = true;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF273444),
                            elevation: 3,
                            shadowColor: const Color(0x33000000),
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.tune_rounded, size: 20),
                          label: const Text(
                            'Manage',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                    : Column(
                        key: const ValueKey('manage_split_buttons'),
                        children: <Widget>[
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _openManageMedications,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF273444),
                                elevation: 4,
                                shadowColor: const Color(0x33000000),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              icon: const Icon(Icons.edit_note_rounded, size: 20),
                              label: const Text(
                                'Manage Medications',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _openMedicationRecords,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF273444),
                                elevation: 4,
                                shadowColor: const Color(0x33000000),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              icon: const Icon(Icons.history_rounded, size: 20),
                              label: const Text(
                                'Medication Records',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              if (todayIndexes.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F3F7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFD6DAE3),
                      width: 1.4,
                    ),
                  ),
                  child: Text(
                    'No medications scheduled for $_todayLabel.',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF4A5968),
                    ),
                  ),
                ),
              ...todayIndexes.map((index) {
                final _MedicationEntry entry = _medications[index];
                final String todayStatus = _todayStatus(entry);
                final bool isTaken = todayStatus == 'Taken';
                final bool isMissed = todayStatus == 'Missed';
                final Color statusColor = isTaken
                    ? const Color(0xFF2EA66A)
                    : isMissed
                    ? const Color(0xFFB8860B)
                    : const Color(0xFFD6DAE3);
                final Color statusFillColor = isTaken
                    ? const Color(0xFFEAF8F1)
                    : isMissed
                    ? const Color(0xFFF9F2E5)
                    : const Color(0xFFF2F3F7);
                return SizedBox(
                  width: double.infinity,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: statusFillColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: statusColor,
                        width: (isTaken || isMissed) ? 1.8 : 1.4,
                      ),
                      boxShadow: (isTaken || isMissed)
                          ? <BoxShadow>[
                              BoxShadow(
                                color: statusColor.withValues(alpha: 0.18),
                                blurRadius: 10,
                                spreadRadius: 0.2,
                              ),
                            ]
                          : const <BoxShadow>[],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: entry.iconColor.withValues(alpha: 0.18),
                            border: Border.all(color: entry.iconColor, width: 1.8),
                          ),
                          child: Icon(
                            entry.iconData,
                            size: 30,
                            color: entry.iconColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    entry.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF273444),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  entry.timeLabel,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF273444),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              entry.amount,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF4A5968),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () =>
                                        _updateMedicationStatus(index, 'Taken'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: todayStatus == 'Taken'
                                          ? const Color(0xFF2EA66A)
                                          : const Color(0xFFE3E5EA),
                                      foregroundColor: todayStatus == 'Taken'
                                          ? Colors.white
                                          : const Color(0xFF4A5968),
                                      side: BorderSide(
                                        color: todayStatus == 'Taken'
                                            ? const Color(0xFF2EA66A)
                                            : const Color(0xFFD6DAE3),
                                        width: 1.4,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                    ),
                                    child: const Text('✓ Taken'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () =>
                                        _updateMedicationStatus(index, 'Missed'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: todayStatus == 'Missed'
                                          ? const Color(0xFFF0544F)
                                          : const Color(0xFFE3E5EA),
                                      foregroundColor: todayStatus == 'Missed'
                                          ? Colors.white
                                          : const Color(0xFF4A5968),
                                      side: BorderSide(
                                        color: todayStatus == 'Missed'
                                            ? const Color(0xFFB8860B)
                                            : const Color(0xFFD6DAE3),
                                        width: 1.4,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                    ),
                                    child: const Text('✕ Missed'),
                                  ),
                                ),
                              ],
                            ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddMedicationFormPage extends StatefulWidget {
  const _AddMedicationFormPage({this.initialEntry});

  final _MedicationEntry? initialEntry;

  @override
  State<_AddMedicationFormPage> createState() => _AddMedicationFormPageState();
}

class _AddMedicationFormPageState extends State<_AddMedicationFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  TimeOfDay? _selectedTime;
  final Set<String> _selectedDays = <String>{};
  static const List<_MedicationIconOption> _iconOptions =
      <_MedicationIconOption>[
        _MedicationIconOption(
          icon: Icons.medication_rounded,
          color: Color(0xFF2E9AEF),
          label: 'Pill',
        ),
        _MedicationIconOption(
          icon: Icons.vaccines_rounded,
          color: Color(0xFFE58E26),
          label: 'Injection',
        ),
        _MedicationIconOption(
          icon: Icons.local_drink_rounded,
          color: Color(0xFF8E44AD),
          label: 'Liquid',
        ),
      ];
  _MedicationIconOption _selectedIcon = _iconOptions.first;

  static const List<String> _weekDays = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  void initState() {
    super.initState();
    final _MedicationEntry? entry = widget.initialEntry;
    if (entry != null) {
      _nameController.text = entry.name;
      _amountController.text = entry.amount;
      _selectedDays.addAll(entry.days);
      _selectedTime = _parseTimeLabel(entry.timeLabel);
      _selectedIcon = _iconOptions.firstWhere(
        (option) =>
            option.icon.codePoint == entry.iconCodePoint &&
            option.color.toARGB32() == entry.iconColorValue,
        orElse: () => _iconOptions.first,
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  TimeOfDay? _parseTimeLabel(String label) {
    final RegExp matchPattern = RegExp(r'^(\d{1,2}):(\d{2})\s?(AM|PM)$');
    final Match? match = matchPattern.firstMatch(label.trim().toUpperCase());
    if (match == null) {
      return null;
    }
    int hour = int.parse(match.group(1)!);
    final int minute = int.parse(match.group(2)!);
    final String meridiem = match.group(3)!;
    if (meridiem == 'PM' && hour != 12) {
      hour += 12;
    } else if (meridiem == 'AM' && hour == 12) {
      hour = 0;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _saveMedication() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_selectedTime == null || _selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a time and at least one day.'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Medication saved')),
    );
    Navigator.pop(
      context,
      _MedicationEntry(
        name: _nameController.text.trim(),
        amount: _amountController.text.trim(),
        timeLabel: _selectedTime!.format(context),
        days: _selectedDays.toList()..sort(),
        iconCodePoint: _selectedIcon.icon.codePoint,
        iconColorValue: _selectedIcon.color.toARGB32(),
        status: '',
        statusDate: '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String timeLabel = _selectedTime == null
        ? 'Select time'
        : _selectedTime!.format(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialEntry == null ? 'Add Medication' : 'Edit Medication'),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F3F7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Medication Name',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Donepezil',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a medication name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Amount to Take',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. 1 tablet / 10mg',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter amount';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Time',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.access_time),
                      label: Text(timeLabel),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Days of Week',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _weekDays.map((String day) {
                      return FilterChip(
                        label: Text(day),
                        selected: _selectedDays.contains(day),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedDays.add(day);
                            } else {
                              _selectedDays.remove(day);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Icon',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _iconOptions.map((_MedicationIconOption option) {
                      final bool isSelected =
                          _selectedIcon.icon.codePoint == option.icon.codePoint;
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          setState(() {
                            _selectedIcon = option;
                          });
                        },
                        child: Container(
                          width: 90,
                          height: 82,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? option.color
                                  : const Color(0xFFD6DAE3),
                              width: isSelected ? 2 : 1.4,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Icon(option.icon, color: option.color, size: 34),
                              const SizedBox(height: 6),
                              Text(
                                option.label,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF4A5968),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveMedication,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo[400],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        widget.initialEntry == null
                            ? 'Save Medication'
                            : 'Update Medication',
                      ),
                    ),
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

class _ManageMedicationsPage extends StatefulWidget {
  const _ManageMedicationsPage({required this.initialMedications});

  final List<_MedicationEntry> initialMedications;

  @override
  State<_ManageMedicationsPage> createState() => _ManageMedicationsPageState();
}

class _MedicationRecordsPage extends StatelessWidget {
  const _MedicationRecordsPage({required this.medications});

  final List<_MedicationEntry> medications;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medication Records'),
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
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: <Widget>[
            if (medications.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F3F7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'No medications saved yet.',
                  style: TextStyle(color: Color(0xFF4A5968), fontSize: 14),
                ),
              )
            else
              ...medications.map((entry) {
                final bool isTaken = entry.status == 'Taken';
                final bool isMissed = entry.status == 'Missed';
                final String statusLabel = isTaken
                    ? 'Taken'
                    : isMissed
                    ? 'Missed'
                    : 'Not marked';
                final Color statusColor = isTaken
                    ? const Color(0xFF2EA66A)
                    : isMissed
                    ? const Color(0xFFB8860B)
                    : const Color(0xFF7A8795);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F3F7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFD6DAE3),
                      width: 1.4,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        entry.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF273444),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Amount: ${entry.amount}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF4A5968),
                        ),
                      ),
                      Text(
                        'Time: ${entry.timeLabel}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF4A5968),
                        ),
                      ),
                      Text(
                        'Days: ${entry.days.join(', ')}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF4A5968),
                        ),
                      ),
                      if (entry.statusDate.isNotEmpty)
                        Text(
                          'Date: ${entry.statusDate}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF4A5968),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          const Text(
                            'Status: ',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF4A5968),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 14,
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _ManageMedicationsPageState extends State<_ManageMedicationsPage> {
  late final List<_MedicationEntry> _medications;

  void _sortMedicationsByTime() {
    _medications.sort(
      (a, b) => a.timeSortValue.compareTo(b.timeSortValue),
    );
  }

  @override
  void initState() {
    super.initState();
    _medications = List<_MedicationEntry>.from(widget.initialMedications);
    _sortMedicationsByTime();
  }

  Future<void> _editMedication(int index) async {
    final _MedicationEntry current = _medications[index];
    final _MedicationEntry? edited = await Navigator.push<_MedicationEntry>(
      context,
      MaterialPageRoute(
        builder: (context) => _AddMedicationFormPage(initialEntry: current),
      ),
    );
    if (edited != null) {
      setState(() {
        _medications[index] = edited;
        _sortMedicationsByTime();
      });
    }
  }

  void _deleteMedication(int index) {
    setState(() {
      _medications.removeAt(index);
    });
  }

  void _closeWithResult() {
    Navigator.pop(context, _medications);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _closeWithResult,
        ),
        title: const Text('Manage Medications'),
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
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: <Widget>[
            if (_medications.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F3F7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'No medications saved yet.',
                  style: TextStyle(color: Color(0xFF4A5968), fontSize: 14),
                ),
              )
            else
              ..._medications.asMap().entries.map((entryMap) {
                final int index = entryMap.key;
                final _MedicationEntry entry = entryMap.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F3F7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        entry.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF273444),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Amount: ${entry.amount}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF4A5968),
                        ),
                      ),
                      Text(
                        'Time: ${entry.timeLabel}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF4A5968),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _editMedication(index),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E9AEF),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Edit'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _deleteMedication(index),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE74C3C),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Delete'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _MedicationEntry {
  const _MedicationEntry({
    required this.name,
    required this.amount,
    required this.timeLabel,
    required this.days,
    required this.iconCodePoint,
    required this.iconColorValue,
    required this.status,
    required this.statusDate,
  });

  final String name;
  final String amount;
  final String timeLabel;
  final List<String> days;
  final int iconCodePoint;
  final int iconColorValue;
  final String status;
  final String statusDate;

  int get timeSortValue {
    final String normalized = timeLabel.trim().toUpperCase();

    // Supports formats like "6:30 PM"
    final RegExp twelveHourPattern = RegExp(r'^(\d{1,2}):(\d{2})\s?(AM|PM)$');
    final Match? twelveHourMatch = twelveHourPattern.firstMatch(normalized);
    if (twelveHourMatch != null) {
      int hour = int.parse(twelveHourMatch.group(1)!);
      final int minute = int.parse(twelveHourMatch.group(2)!);
      final String meridiem = twelveHourMatch.group(3)!;
      if (meridiem == 'PM' && hour != 12) {
        hour += 12;
      } else if (meridiem == 'AM' && hour == 12) {
        hour = 0;
      }
      return hour * 60 + minute;
    }

    // Supports formats like "18:30"
    final RegExp twentyFourHourPattern = RegExp(r'^(\d{1,2}):(\d{2})$');
    final Match? twentyFourHourMatch = twentyFourHourPattern.firstMatch(normalized);
    if (twentyFourHourMatch != null) {
      final int hour = int.parse(twentyFourHourMatch.group(1)!);
      final int minute = int.parse(twentyFourHourMatch.group(2)!);
      return hour * 60 + minute;
    }

    // Unknown format goes to the bottom.
    return 24 * 60;
  }

  IconData get iconData =>
      IconData(iconCodePoint, fontFamily: 'MaterialIcons');
  Color get iconColor => Color(iconColorValue);

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'amount': amount,
      'timeLabel': timeLabel,
      'days': days,
      'iconCodePoint': iconCodePoint,
      'iconColorValue': iconColorValue,
      'status': status,
      'statusDate': statusDate,
    };
  }

  factory _MedicationEntry.fromJson(Map<String, dynamic> json) {
    const int defaultIconCodePoint = 0xe3d2;
    const int defaultIconColorValue = 0xFF2EA66A;
    return _MedicationEntry(
      name: (json['name'] ?? '').toString(),
      amount: (json['amount'] ?? '').toString(),
      timeLabel: (json['timeLabel'] ?? '').toString(),
      days: (json['days'] is List)
          ? (json['days'] as List)
                .map((item) => item.toString())
                .toList(growable: false)
          : const <String>[],
      iconCodePoint: (json['iconCodePoint'] is num)
          ? (json['iconCodePoint'] as num).toInt()
          : defaultIconCodePoint,
      iconColorValue: (json['iconColorValue'] is num)
          ? (json['iconColorValue'] as num).toInt()
          : defaultIconColorValue,
      status: (json['status'] ?? '').toString(),
      statusDate: (json['statusDate'] ?? '').toString(),
    );
  }

  _MedicationEntry copyWith({
    String? name,
    String? amount,
    String? timeLabel,
    List<String>? days,
    int? iconCodePoint,
    int? iconColorValue,
    String? status,
    String? statusDate,
  }) {
    return _MedicationEntry(
      name: name ?? this.name,
      amount: amount ?? this.amount,
      timeLabel: timeLabel ?? this.timeLabel,
      days: days ?? this.days,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconColorValue: iconColorValue ?? this.iconColorValue,
      status: status ?? this.status,
      statusDate: statusDate ?? this.statusDate,
    );
  }
}

class _MedicationIconOption {
  const _MedicationIconOption({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;
}