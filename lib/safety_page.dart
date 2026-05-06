import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:alzheimers_project/profile_page.dart';
import 'package:alzheimers_project/services/guest_mode.dart';
import 'package:alzheimers_project/services/user_data_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SafetyPage extends StatefulWidget {
  const SafetyPage({super.key});

  @override
  State<SafetyPage> createState() => _SafetyPageState();
}

class _SafetyPageState extends State<SafetyPage> {
  final List<_EmergencyContact> _contacts = <_EmergencyContact>[];
  static const List<_ContactAvatarChoice> _avatarChoices = <_ContactAvatarChoice>[
    _ContactAvatarChoice(Icons.person_rounded, Color(0xFF3D7BE6)),
    _ContactAvatarChoice(Icons.person_outline_rounded, Color(0xFF2EA66A)),
    _ContactAvatarChoice(Icons.face_rounded, Color(0xFF8E44AD)),
    _ContactAvatarChoice(Icons.favorite_rounded, Color(0xFFEF4444)),
    _ContactAvatarChoice(Icons.star_rounded, Color(0xFFF59E0B)),
    _ContactAvatarChoice(Icons.shield_rounded, Color(0xFF0EA5A6)),
  ];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final snapshot = await UserDataService.instance
          .contactsCol()
          .orderBy('createdAt', descending: true)
          .get();
      final List<_EmergencyContact> loaded = snapshot.docs
          .map((doc) => _EmergencyContact.fromDoc(doc.id, doc.data()))
          .toList();

      if (!mounted) return;
      setState(() {
        _contacts
          ..clear()
          ..addAll(loaded);
      });
    } catch (_) {
      // Keep UI usable even if load fails.
    }
  }

  static bool _isValidPhone(String value) {
    final String digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 7 && digits.length <= 15;
  }


  Future<_EmergencyContact?> _showContactForm({
    _EmergencyContact? initial,
  }) {
    return showDialog<_EmergencyContact>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => _ContactFormDialog(
        initial: initial,
        avatarChoices: _avatarChoices,
        isValidPhone: _isValidPhone,
      ),
    );
  }

  Future<void> _addContact() async {
    if (guestBlocked(context, feature: 'add emergency contacts')) return;
    final _EmergencyContact? newContact = await _showContactForm();
    if (newContact == null || !mounted) return;
    final doc = await UserDataService.instance.contactsCol().add(<String, dynamic>{
      ...newContact.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (!mounted) return;
    setState(() => _contacts.insert(0, newContact.copyWith(id: doc.id)));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${newContact.name} added as emergency contact.')),
    );
  }

  Future<void> _editContact(int index) async {
    if (guestBlocked(context, feature: 'edit contacts')) return;
    final _EmergencyContact current = _contacts[index];
    final _EmergencyContact? updated =
        await _showContactForm(initial: current);
    if (updated == null || !mounted) return;
    final _EmergencyContact merged = updated.copyWith(id: current.id);
    await UserDataService.instance
        .contactsCol()
        .doc(current.id)
        .update(merged.toMap());
    if (!mounted) return;
    setState(() => _contacts[index] = merged);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${updated.name} updated.')),
    );
  }

  Future<void> _deleteContact(int index) async {
    if (guestBlocked(context, feature: 'delete contacts')) return;
    final _EmergencyContact contact = _contacts[index];
    try {
      await UserDataService.instance.contactsCol().doc(contact.id).delete();
    } catch (_) {
      // If remote delete fails we still remove locally.
    }
    if (!mounted) return;
    setState(() => _contacts.removeAt(index));
  }

  Future<void> _callNumber(String label, String number) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Container(
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          Color(0xFF16A34A),
                          Color(0xFF22C55E),
                        ],
                      ),
                    ),
                    child: Column(
                      children: <Widget>[
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.55),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.call_rounded,
                            size: 34,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Confirm Call',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'This will open your phone dialer.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                    child: Column(
                      children: <Widget>[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4FA),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Text(
                                'Calling',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF5C6675),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF202939),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: <Widget>[
                                  const Icon(
                                    Icons.phone_rounded,
                                    size: 16,
                                    color: Color(0xFF3D7BE6),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    number,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF3D7BE6),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, false),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF5C6675),
                                  side: const BorderSide(
                                    color: Color(0xFFD6DAE3),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, true),
                                icon: const Icon(Icons.call_rounded, size: 18),
                                label: const Text(
                                  'Call',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF22C55E),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
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
          ),
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final String sanitizedNumber = number.replaceAll(RegExp(r'[^0-9+]'), '');
    final Uri telUri = Uri(scheme: 'tel', path: sanitizedNumber);
    final bool launched = await launchUrl(telUri);
    if (!mounted) return;
    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to place call to $label.')),
      );
    }
  }

  Future<void> _showAvatarPicker(int index) async {
    final _ContactAvatarChoice? selectedChoice =
        await showDialog<_ContactAvatarChoice>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Change profile picture'),
          content: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _avatarChoices.map((choice) {
              return InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => Navigator.pop(dialogContext, choice),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Color.lerp(choice.color, Colors.white, 0.8),
                    shape: BoxShape.circle,
                    border: Border.all(color: choice.color, width: 1.2),
                  ),
                  child: Icon(choice.icon, color: choice.color),
                ),
              );
            }).toList(),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (selectedChoice == null || !mounted) return;
    if (guestBlocked(context, feature: 'change avatars')) return;
    final _EmergencyContact contact = _contacts[index];
    final _EmergencyContact updated = contact.copyWith(
      avatarIcon: selectedChoice.icon,
      avatarColor: selectedChoice.color,
    );
    try {
      await UserDataService.instance
          .contactsCol()
          .doc(contact.id)
          .update(updated.toMap());
    } catch (_) {
      // Still update locally if remote write fails.
    }
    if (!mounted) return;
    setState(() => _contacts[index] = updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety'),
        backgroundColor: const Color(0xFF6168D7),
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
      backgroundColor: const Color(0xFF6168D7),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4FA),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFDE2E2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.call_rounded,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Emergency Contacts',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF202939),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_contacts.isEmpty)
                    const Text(
                      'No emergency contacts yet.',
                      style: TextStyle(
                        color: Color(0xFF5C6675),
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    ..._contacts.asMap().entries.map((entry) {
                      final int index = entry.key;
                      final _EmergencyContact contact = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Color.lerp(
                                  contact.avatarColor,
                                  Colors.white,
                                  0.8,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                contact.avatarIcon,
                                color: contact.avatarColor,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    contact.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18,
                                    ),
                                  ),
                                  Text(
                                    contact.phone,
                                    style: const TextStyle(
                                      color: Color(0xFF5C6675),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              decoration: const BoxDecoration(
                                color: Color(0xFF22C55E),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                onPressed: () =>
                                    _callNumber(contact.name, contact.phone),
                                icon: const Icon(
                                  Icons.call_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  await _editContact(index);
                                } else if (value == 'change_profile_picture') {
                                  await _showAvatarPicker(index);
                                } else if (value == 'delete') {
                                  await _deleteContact(index);
                                }
                              },
                              itemBuilder: (context) =>
                                  const <PopupMenuEntry<String>>[
                                PopupMenuItem<String>(
                                  value: 'edit',
                                  child: Row(
                                    children: <Widget>[
                                      Icon(
                                        Icons.edit_rounded,
                                        color: Color(0xFF3D7BE6),
                                      ),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem<String>(
                                  value: 'change_profile_picture',
                                  child: Row(
                                    children: <Widget>[
                                      Icon(
                                        Icons.account_circle_outlined,
                                        color: Color(0xFF3D7BE6),
                                      ),
                                      SizedBox(width: 8),
                                      Text('Change profile picture'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem<String>(
                                  value: 'delete',
                                  child: Row(
                                    children: <Widget>[
                                      Icon(
                                        Icons.delete_outline_rounded,
                                        color: Color(0xFFEF4444),
                                      ),
                                      SizedBox(width: 8),
                                      Text('Delete'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _addContact,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Emergency Contact'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF3D7BE6),
                        side: const BorderSide(color: Color(0xFF3D7BE6)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4FA),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Row(
                    children: <Widget>[
                      Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
                      SizedBox(width: 8),
                      Text(
                        'SOS',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF202939),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _callNumber('Police', '911'),
                      icon: const Icon(Icons.local_police_rounded),
                      label: const Text('Call Police: 911'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _callNumber('Mental Health Crisis Hotline', '988'),
                      icon: const Icon(Icons.support_agent_rounded),
                      label: const Text('Mental Health Crisis Hotline: 988'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8E44AD),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyContact {
  const _EmergencyContact({
    this.id = '',
    required this.name,
    required this.phone,
    required this.avatarIcon,
    required this.avatarColor,
  });

  final String id;
  final String name;
  final String phone;
  final IconData avatarIcon;
  final Color avatarColor;

  _EmergencyContact copyWith({
    String? id,
    String? name,
    String? phone,
    IconData? avatarIcon,
    Color? avatarColor,
  }) {
    return _EmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      avatarIcon: avatarIcon ?? this.avatarIcon,
      avatarColor: avatarColor ?? this.avatarColor,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'phone': phone,
      'avatarIconCodePoint': avatarIcon.codePoint,
      'avatarColorValue': avatarColor.toARGB32(),
    };
  }

  factory _EmergencyContact.fromDoc(String id, Map<String, dynamic> data) {
    final int iconCodePoint = data['avatarIconCodePoint'] is int
        ? data['avatarIconCodePoint'] as int
        : Icons.person_rounded.codePoint;
    final int colorValue = data['avatarColorValue'] is int
        ? data['avatarColorValue'] as int
        : const Color(0xFF3D7BE6).toARGB32();

    return _EmergencyContact(
      id: id,
      name: (data['name'] ?? '').toString(),
      phone: (data['phone'] ?? '').toString(),
      avatarIcon: IconData(iconCodePoint, fontFamily: 'MaterialIcons'),
      avatarColor: Color(colorValue),
    );
  }
}

class _ContactAvatarChoice {
  const _ContactAvatarChoice(this.icon, this.color);

  final IconData icon;
  final Color color;
}

class _ContactFormDialog extends StatefulWidget {
  const _ContactFormDialog({
    required this.initial,
    required this.avatarChoices,
    required this.isValidPhone,
  });

  final _EmergencyContact? initial;
  final List<_ContactAvatarChoice> avatarChoices;
  final bool Function(String) isValidPhone;

  @override
  State<_ContactFormDialog> createState() => _ContactFormDialogState();
}

class _ContactFormDialogState extends State<_ContactFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late _ContactAvatarChoice _selectedAvatar;

  @override
  void initState() {
    super.initState();
    final _EmergencyContact? initial = widget.initial;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _phoneController = TextEditingController(text: initial?.phone ?? '');
    _selectedAvatar = widget.avatarChoices.firstWhere(
      (c) =>
          c.icon.codePoint ==
              (initial?.avatarIcon.codePoint ??
                  widget.avatarChoices.first.icon.codePoint) &&
          c.color.toARGB32() ==
              (initial?.avatarColor.toARGB32() ??
                  widget.avatarChoices.first.color.toARGB32()),
      orElse: () => widget.avatarChoices.first,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      _EmergencyContact(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        avatarIcon: _selectedAvatar.icon,
        avatarColor: _selectedAvatar.color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.initial != null;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Container(
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      Color(0xFF6168D7),
                      Color(0xFF3D7BE6),
                    ],
                  ),
                ),
                child: Column(
                  children: <Widget>[
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 1.4,
                        ),
                      ),
                      child: Icon(
                        _selectedAvatar.icon,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isEditing
                          ? 'Edit Emergency Contact'
                          : 'Add Emergency Contact',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Someone to reach in an emergency',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'Name',
                          prefixIcon:
                              const Icon(Icons.person_outline_rounded),
                          filled: true,
                          fillColor: const Color(0xFFF3F4FA),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: const Icon(Icons.phone_rounded),
                          filled: true,
                          fillColor: const Color(0xFFF3F4FA),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a phone number';
                          }
                          if (!widget.isValidPhone(value)) {
                            return 'Enter a valid phone (7–15 digits)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Profile picture',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF273444),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: widget.avatarChoices.map((choice) {
                          final bool isSelected =
                              choice.icon.codePoint ==
                                      _selectedAvatar.icon.codePoint &&
                                  choice.color.toARGB32() ==
                                      _selectedAvatar.color.toARGB32();
                          return InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () {
                              setState(() {
                                _selectedAvatar = choice;
                              });
                            },
                            child: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: Color.lerp(
                                  choice.color,
                                  Colors.white,
                                  0.8,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? choice.color
                                      : Colors.transparent,
                                  width: 2.4,
                                ),
                              ),
                              child: Icon(
                                choice.icon,
                                color: choice.color,
                                size: 22,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF5C6675),
                                side: const BorderSide(
                                  color: Color(0xFFD6DAE3),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3D7BE6),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                isEditing ? 'Save' : 'Add Contact',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}