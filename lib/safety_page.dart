import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:alzheimers_project/profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class SafetyPage extends StatefulWidget {
  const SafetyPage({super.key});

  @override
  State<SafetyPage> createState() => _SafetyPageState();
}

class _SafetyPageState extends State<SafetyPage> {
  static const String _contactsStorageKey = 'safety_emergency_contacts';
  static const String _locationShareKey = 'profile_location_sharing';
  final List<_EmergencyContact> _contacts = <_EmergencyContact>[];
  bool _locationSharingEnabled = false;
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
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool locationSharing = prefs.getBool(_locationShareKey) ?? false;
      final List<String> raw =
          prefs.getStringList(_contactsStorageKey) ?? <String>[];
      final List<_EmergencyContact> loaded = raw
          .map((item) {
            try {
              return _EmergencyContact.fromJson(
                jsonDecode(item) as Map<String, dynamic>,
              );
            } catch (_) {
              return null;
            }
          })
          .whereType<_EmergencyContact>()
          .toList();

      if (!mounted) return;
      setState(() {
        _locationSharingEnabled = locationSharing;
        _contacts
          ..clear()
          ..addAll(loaded);
      });
    } catch (_) {
      // Keep UI usable even if local storage has malformed data.
    }
  }

  Future<void> _saveContacts() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _contactsStorageKey,
        _contacts
            .map((contact) => jsonEncode(contact.toJson()))
            .toList(growable: false),
      );
    } catch (_) {
      // Ignore persistence errors; in-memory state remains available.
    }
  }

  Future<void> _showAddContactDialog() async {
    String name = '';
    String phone = '';

    final _EmergencyContact? newContact = await showDialog<_EmergencyContact>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Emergency Contact'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                initialValue: name,
                onChanged: (value) => name = value,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: phone,
                onChanged: (value) => phone = value,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone Number'),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final String trimmedName = name.trim();
                final String trimmedPhone = phone.trim();
                if (trimmedName.isEmpty || trimmedPhone.isEmpty) return;
                Navigator.pop(
                  dialogContext,
                  _EmergencyContact(
                    name: trimmedName,
                    phone: trimmedPhone,
                    avatarIcon: _avatarChoices.first.icon,
                    avatarColor: _avatarChoices.first.color,
                  ),
                );
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (newContact == null || !mounted) return;
    setState(() => _contacts.insert(0, newContact));
    await _saveContacts();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${newContact.name} added as emergency contact.')),
    );
  }

  Future<void> _callNumber(String label, String number) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Call'),
          content: Text(
            _locationSharingEnabled
                ? 'Call $label at $number?\n\nLocation sharing is enabled for emergencies.'
                : 'Call $label at $number?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Call'),
            ),
          ],
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
    setState(() {
      final _EmergencyContact contact = _contacts[index];
      _contacts[index] = contact.copyWith(
        avatarIcon: selectedChoice.icon,
        avatarColor: selectedChoice.color,
      );
    });
    await _saveContacts();
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
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _locationSharingEnabled
                            ? const Color(0xFF2EA66A)
                            : const Color(0xFFD6DAE3),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          _locationSharingEnabled
                              ? Icons.location_on_rounded
                              : Icons.location_disabled_rounded,
                          color: _locationSharingEnabled
                              ? const Color(0xFF2EA66A)
                              : const Color(0xFF7B8493),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _locationSharingEnabled
                                ? 'Location sharing is ON (from Profile).'
                                : 'Location sharing is OFF (from Profile).',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF273444),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
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
                                if (value == 'change_profile_picture') {
                                  await _showAvatarPicker(index);
                                } else if (value == 'delete') {
                                  setState(() => _contacts.removeAt(index));
                                  await _saveContacts();
                                }
                              },
                              itemBuilder: (context) => const <PopupMenuEntry<String>>[
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
                      onPressed: _showAddContactDialog,
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
    required this.name,
    required this.phone,
    required this.avatarIcon,
    required this.avatarColor,
  });

  final String name;
  final String phone;
  final IconData avatarIcon;
  final Color avatarColor;

  _EmergencyContact copyWith({
    String? name,
    String? phone,
    IconData? avatarIcon,
    Color? avatarColor,
  }) {
    return _EmergencyContact(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      avatarIcon: avatarIcon ?? this.avatarIcon,
      avatarColor: avatarColor ?? this.avatarColor,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'phone': phone,
      'avatarIconCodePoint': avatarIcon.codePoint,
      'avatarColorValue': avatarColor.toARGB32(),
    };
  }

  factory _EmergencyContact.fromJson(Map<String, dynamic> json) {
    final int iconCodePoint = json['avatarIconCodePoint'] is int
        ? json['avatarIconCodePoint'] as int
        : Icons.person_rounded.codePoint;
    final int colorValue = json['avatarColorValue'] is int
        ? json['avatarColorValue'] as int
        : const Color(0xFF3D7BE6).toARGB32();

    return _EmergencyContact(
      name: (json['name'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
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