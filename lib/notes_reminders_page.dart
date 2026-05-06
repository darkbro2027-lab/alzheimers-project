import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:alzheimers_project/profile_page.dart';
import 'package:alzheimers_project/services/guest_mode.dart';
import 'package:alzheimers_project/services/user_data_service.dart';

class NotesRemindersPage extends StatefulWidget {
  const NotesRemindersPage({super.key});

  @override
  State<NotesRemindersPage> createState() => _NotesRemindersPageState();
}

class _NotesRemindersPageState extends State<NotesRemindersPage> {
  static const List<String> _quickTags = <String>[
    'Important',
    'Reminder',
    'Observation',
    'Safety',
    'Other',
  ];

  final TextEditingController _quickNoteTitleController = TextEditingController();
  final TextEditingController _quickNoteDescriptionController =
      TextEditingController();
  final FocusNode _quickNoteFocusNode = FocusNode();
  final List<_NoteItem> _todayNotes = <_NoteItem>[];
  final List<_NoteItem> _previousNotes = <_NoteItem>[];
  bool _isLoading = true;
  bool _isQuickNoteExpanded = false;
  String _selectedQuickTag = 'Important';

  @override
  void initState() {
    super.initState();
    _quickNoteFocusNode.addListener(_handleQuickNoteFocusChanged);
    _loadNotes();
  }

  @override
  void dispose() {
    _quickNoteFocusNode.removeListener(_handleQuickNoteFocusChanged);
    _quickNoteFocusNode.dispose();
    _quickNoteTitleController.dispose();
    _quickNoteDescriptionController.dispose();
    super.dispose();
  }

  void _handleQuickNoteFocusChanged() {
    if (!mounted) return;
    if (_quickNoteFocusNode.hasFocus) {
      setState(() {
        _isQuickNoteExpanded = true;
      });
      return;
    }

    if (_quickNoteTitleController.text.trim().isEmpty &&
        _quickNoteDescriptionController.text.trim().isEmpty) {
      setState(() {
        _isQuickNoteExpanded = false;
      });
    }
  }

  String _todayKey() {
    final DateTime now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadNotes() async {
    List<_NoteItem> loadedToday = <_NoteItem>[];
    List<_NoteItem> loadedPrevious = <_NoteItem>[];

    try {
      final todaySnap = await UserDataService.instance
          .notesCol()
          .where('bucket', isEqualTo: 'today')
          .orderBy('createdAtMillis', descending: true)
          .get();
      final previousSnap = await UserDataService.instance
          .notesCol()
          .where('bucket', isEqualTo: 'previous')
          .orderBy('createdAtMillis', descending: true)
          .get();

      loadedToday = todaySnap.docs
          .map((doc) => _NoteItem.fromDoc(doc.id, doc.data()))
          .toList();
      loadedPrevious = previousSnap.docs
          .map((doc) => _NoteItem.fromDoc(doc.id, doc.data()))
          .toList();

      final String todayKey = _todayKey();
      final metaSnap = await UserDataService.instance.metaDoc().get();
      final String? lastOpenedDay =
          metaSnap.data()?['notesLastOpenedDay'] as String?;

      if (lastOpenedDay != null &&
          lastOpenedDay != todayKey &&
          loadedToday.isNotEmpty) {
        // New day: move yesterday's "today notes" into previous notes (remote + local).
        final batch = FirebaseFirestore.instance.batch();
        for (final _NoteItem note in loadedToday) {
          batch.update(
            UserDataService.instance.notesCol().doc(note.id),
            <String, dynamic>{'bucket': 'previous'},
          );
        }
        await batch.commit();
        loadedPrevious.insertAll(0, loadedToday);
        loadedToday = <_NoteItem>[];
      }

      await UserDataService.instance.metaDoc().set(
        <String, dynamic>{'notesLastOpenedDay': todayKey},
        SetOptions(merge: true),
      );
    } catch (_) {
      // Fail-safe: still render the page even if remote load fails.
    }

    if (!mounted) return;
    setState(() {
      _todayNotes
        ..clear()
        ..addAll(loadedToday);
      _previousNotes
        ..clear()
        ..addAll(loadedPrevious);
      _isLoading = false;
    });
  }

  Future<void> _addQuickNote() async {
    final String title = _quickNoteTitleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a note first.')));
      return;
    }
    if (guestBlocked(context, feature: 'save notes')) return;

    final String description = _quickNoteDescriptionController.text.trim();
    final Color tagColor = _quickTagColor(_selectedQuickTag);
    final _NoteItem draft = _NoteItem(
      title: title,
      description: description.isEmpty ? 'No description' : description,
      tag: _selectedQuickTag,
      time: _timeLabel(TimeOfDay.now()),
      createdDateLabel: _todayDateLabel(),
      accentColor: tagColor,
      tagColor: tagColor,
    );

    try {
      final doc = await UserDataService.instance.notesCol().add(<String, dynamic>{
        ...draft.toMap(),
        'bucket': 'today',
        'createdAtMillis': DateTime.now().millisecondsSinceEpoch,
      });
      if (!mounted) return;
      setState(() {
        _todayNotes.insert(0, draft.copyWith(id: doc.id));
        _quickNoteTitleController.clear();
        _quickNoteDescriptionController.clear();
        _selectedQuickTag = 'Important';
        _isQuickNoteExpanded = false;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save note.')),
      );
      return;
    }
    _quickNoteFocusNode.unfocus();
  }

  Future<void> _showEditNoteDialog({
    required List<_NoteItem> targetList,
    required int index,
  }) async {
    await _showNoteEditorDialog(
      targetList: targetList,
      editIndex: index,
      existing: targetList[index],
    );
  }

  Future<void> _showNoteEditorDialog({
    required List<_NoteItem> targetList,
    int? editIndex,
    _NoteItem? existing,
  }) async {
    String title = existing?.title ?? '';
    String description = existing?.description ?? '';
    String tag = existing?.tag ?? '';

    final _NoteItem? savedNote = await showDialog<_NoteItem>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(existing == null ? 'Add Note' : 'Edit Note'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  initialValue: title,
                  onChanged: (value) => title = value,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: description,
                  onChanged: (value) => description = value,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: tag,
                  onChanged: (value) => tag = value,
                  decoration: const InputDecoration(labelText: 'Tag'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final String resolvedTitle = title.trim();
                if (resolvedTitle.isEmpty) return;

                final _NoteItem note = _NoteItem(
                  title: resolvedTitle,
                  description: description.trim().isEmpty
                      ? 'No description'
                      : description.trim(),
                  tag: tag.trim().isEmpty
                      ? 'Note'
                      : tag.trim(),
                  time: _timeLabel(TimeOfDay.now()),
                  createdDateLabel:
                      existing?.createdDateLabel ?? _todayDateLabel(),
                  accentColor: existing?.accentColor ?? const Color(0xFF3D7BE6),
                  tagColor: existing?.tagColor ?? const Color(0xFF3D7BE6),
                );
                Navigator.pop(dialogContext, note);
              },
              child: Text(existing == null ? 'Add' : 'Save'),
            ),
          ],
        );
      },
    );

    if (savedNote != null && mounted) {
      if (guestBlocked(context, feature: 'save notes')) return;
      final bool isToday = identical(targetList, _todayNotes);
      final String bucket = isToday ? 'today' : 'previous';
      try {
        if (editIndex == null) {
          final doc = await UserDataService.instance
              .notesCol()
              .add(<String, dynamic>{
            ...savedNote.toMap(),
            'bucket': bucket,
            'createdAtMillis': DateTime.now().millisecondsSinceEpoch,
          });
          setState(() {
            targetList.insert(0, savedNote.copyWith(id: doc.id));
          });
        } else {
          final _NoteItem prior = targetList[editIndex];
          final _NoteItem merged = savedNote.copyWith(id: prior.id);
          await UserDataService.instance
              .notesCol()
              .doc(prior.id)
              .update(merged.toMap());
          setState(() {
            targetList[editIndex] = merged;
          });
        }
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save note.')),
        );
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(existing == null ? 'Note added.' : 'Note updated.'),
        ),
      );
    }
  }

  Future<void> _deleteNote({
    required List<_NoteItem> targetList,
    required int index,
  }) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete note?'),
          content: const Text('This note will be removed.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    if (!mounted) return;
    if (guestBlocked(context, feature: 'delete notes')) return;
    final _NoteItem note = targetList[index];
    try {
      await UserDataService.instance.notesCol().doc(note.id).delete();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      targetList.removeAt(index);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Note deleted.')));
  }

  Color _quickTagColor(String tag) {
    switch (tag) {
      case 'Important':
        return const Color(0xFF3D7BE6);
      case 'Reminder':
        return const Color(0xFF8E44AD);
      case 'Medication':
        return const Color(0xFF2EA66A);
      case 'Observation':
        return const Color(0xFFF59E0B);
      case 'Safety':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF5C6675);
    }
  }

  String _timeLabel(TimeOfDay time) {
    final int hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final String minute = time.minute.toString().padLeft(2, '0');
    final String suffix = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $suffix';
  }

  String _todayDateLabel() {
    final DateTime now = DateTime.now();
    const List<String> months = <String>[
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
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF6168D7),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF6168D7),
        foregroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 74,
        titleSpacing: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Notes & Reminders',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 2),
            Text(
              'Keep track of important things',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFFD9DDF8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: const Icon(Icons.account_circle, size: 30),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfilePage(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF6168D7),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4FA),
                borderRadius: BorderRadius.circular(18),
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                constraints: BoxConstraints(
                  minHeight: _isQuickNoteExpanded ? 220 : 44,
                ),
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF7EEB0),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.sticky_note_2_rounded,
                            color: Color(0xFFC29C00),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (_isQuickNoteExpanded)
                          const Expanded(
                            child: Text(
                              'Quick note details',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF394253),
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: TextField(
                              focusNode: _quickNoteFocusNode,
                              controller: _quickNoteTitleController,
                              onTap: () {
                                setState(() {
                                  _isQuickNoteExpanded = true;
                                });
                              },
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF394253),
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Add a quick note...',
                                hintStyle: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF8A93A3),
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (_isQuickNoteExpanded) ...<Widget>[
                      const SizedBox(height: 10),
                      TextField(
                        controller: _quickNoteTitleController,
                        decoration: InputDecoration(
                          labelText: 'Title',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFD6DAE3)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _quickNoteDescriptionController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFD6DAE3)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _quickTags.map((tag) {
                            return ChoiceChip(
                              label: Text(tag),
                              selected: _selectedQuickTag == tag,
                              onSelected: (_) {
                                setState(() {
                                  _selectedQuickTag = tag;
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: _addQuickNote,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3D89EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        child: const Text(
                          'Add',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              icon: Icons.calendar_month_rounded,
              iconBg: const Color(0xFFDDECFF),
              iconColor: const Color(0xFF3D7BE6),
              title: "Today's Notes",
              notes: _todayNotes,
              showDate: false,
              onEdit: (index) =>
                  _showEditNoteDialog(targetList: _todayNotes, index: index),
              onDelete: (index) =>
                  _deleteNote(targetList: _todayNotes, index: index),
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              icon: Icons.history_rounded,
              iconBg: const Color(0xFFEFE2FF),
              iconColor: const Color(0xFF8E44AD),
              title: 'Previous Notes',
              notes: _previousNotes,
              showDate: true,
              onEdit: (index) =>
                  _showEditNoteDialog(targetList: _previousNotes, index: index),
              onDelete: (index) =>
                  _deleteNote(targetList: _previousNotes, index: index),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required List<_NoteItem> notes,
    required bool showDate,
    required ValueChanged<int> onEdit,
    required ValueChanged<int> onDelete,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4FA),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF202939),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...notes.asMap().entries.map(
            (entry) => _buildNoteCard(
              note: entry.value,
              showDate: showDate,
              onEdit: () => onEdit(entry.key),
              onDelete: () => onDelete(entry.key),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard({
    required _NoteItem note,
    required bool showDate,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 6,
            height: 128,
            decoration: BoxDecoration(
              color: note.accentColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          note.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF252E3E),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: onEdit,
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: Color(0xFF9AA4B2),
                          size: 21,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minHeight: 24,
                          minWidth: 24,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: onDelete,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Color(0xFF9AA4B2),
                          size: 21,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minHeight: 24,
                          minWidth: 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    note.description,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF5C6675),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Color.lerp(note.tagColor, Colors.white, 0.8),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          note.tag,
                          style: TextStyle(
                            color: note.tagColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        note.time,
                        style: const TextStyle(
                          color: Color(0xFF7B8493),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (showDate) ...<Widget>[
                        const SizedBox(width: 12),
                        Text(
                          note.createdDateLabel.isEmpty
                              ? 'Unknown date'
                              : note.createdDateLabel,
                          style: const TextStyle(
                            color: Color(0xFF7B8493),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteItem {
  const _NoteItem({
    this.id = '',
    required this.title,
    required this.description,
    required this.tag,
    required this.time,
    required this.createdDateLabel,
    required this.accentColor,
    required this.tagColor,
  });

  final String id;
  final String title;
  final String description;
  final String tag;
  final String time;
  final String createdDateLabel;
  final Color accentColor;
  final Color tagColor;

  _NoteItem copyWith({
    String? id,
    String? title,
    String? description,
    String? tag,
    String? time,
    String? createdDateLabel,
    Color? accentColor,
    Color? tagColor,
  }) {
    return _NoteItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      tag: tag ?? this.tag,
      time: time ?? this.time,
      createdDateLabel: createdDateLabel ?? this.createdDateLabel,
      accentColor: accentColor ?? this.accentColor,
      tagColor: tagColor ?? this.tagColor,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'title': title,
      'description': description,
      'tag': tag,
      'time': time,
      'createdDateLabel': createdDateLabel,
      'accentColorValue': accentColor.toARGB32(),
      'tagColorValue': tagColor.toARGB32(),
    };
  }

  factory _NoteItem.fromDoc(String id, Map<String, dynamic> data) {
    final int accentValue = data['accentColorValue'] is int
        ? data['accentColorValue'] as int
        : const Color(0xFF3D7BE6).toARGB32();
    final int tagValue = data['tagColorValue'] is int
        ? data['tagColorValue'] as int
        : const Color(0xFF3D7BE6).toARGB32();

    return _NoteItem(
      id: id,
      title: (data['title'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      tag: (data['tag'] ?? '').toString(),
      time: (data['time'] ?? '').toString(),
      createdDateLabel: (data['createdDateLabel'] ?? '').toString(),
      accentColor: Color(accentValue),
      tagColor: Color(tagValue),
    );
  }
}