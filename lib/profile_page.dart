import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const String _nameKey = 'profile_name';
  static const String _ageKey = 'profile_age';
  static const String _languageKey = 'profile_language';
  static const String _caregiverNameKey = 'profile_caregiver_name';
  static const String _caregiverPhoneKey = 'profile_caregiver_phone';
  static const String _medicalNotesKey = 'profile_medical_notes';
  static const String _medReminderKey = 'profile_medication_reminders';
  static const String _locationShareKey = 'profile_location_sharing';

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _languageController = TextEditingController();
  final TextEditingController _caregiverNameController = TextEditingController();
  final TextEditingController _caregiverPhoneController = TextEditingController();
  final TextEditingController _medicalNotesController = TextEditingController();

  bool _medicationReminders = true;
  bool _locationSharing = false;
  bool _isLoading = true;
  bool _isEditMode = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _languageController.dispose();
    _caregiverNameController.dispose();
    _caregiverPhoneController.dispose();
    _medicalNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _nameController.text = prefs.getString(_nameKey) ?? '';
      _ageController.text = prefs.getString(_ageKey) ?? '';
      _languageController.text = prefs.getString(_languageKey) ?? '';
      _caregiverNameController.text = prefs.getString(_caregiverNameKey) ?? '';
      _caregiverPhoneController.text = prefs.getString(_caregiverPhoneKey) ?? '';
      _medicalNotesController.text = prefs.getString(_medicalNotesKey) ?? '';
      _medicationReminders = prefs.getBool(_medReminderKey) ?? true;
      _locationSharing = prefs.getBool(_locationShareKey) ?? false;
      _isEditMode = !_hasProfileData();
      _isLoading = false;
    });
  }

  Future<void> _saveProfile() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, _nameController.text.trim());
    await prefs.setString(_ageKey, _ageController.text.trim());
    await prefs.setString(_languageKey, _languageController.text.trim());
    await prefs.setString(_caregiverNameKey, _caregiverNameController.text.trim());
    await prefs.setString(_caregiverPhoneKey, _caregiverPhoneController.text.trim());
    await prefs.setString(_medicalNotesKey, _medicalNotesController.text.trim());
    await prefs.setBool(_medReminderKey, _medicationReminders);
    await prefs.setBool(_locationShareKey, _locationSharing);
    if (!mounted) return;
    setState(() {
      _isEditMode = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile saved')));
  }

  bool _hasProfileData() {
    return _nameController.text.trim().isNotEmpty ||
        _ageController.text.trim().isNotEmpty ||
        _languageController.text.trim().isNotEmpty ||
        _caregiverNameController.text.trim().isNotEmpty ||
        _caregiverPhoneController.text.trim().isNotEmpty ||
        _medicalNotesController.text.trim().isNotEmpty;
  }

  Widget _buildInfoBubble(String label, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6DAE3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7B8493),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF252E3E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: const Color(0xFF3D7BE6)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF202939),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD6DAE3)),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const AuthPage()),
        (route) => false,
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Could not log out.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not log out.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.indigo[400],
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    final String headerName =
        _nameController.text.trim().isEmpty ? 'Your Profile' : _nameController.text.trim();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.indigo[400],
        foregroundColor: Colors.white,
        actions: <Widget>[
          IconButton(
            onPressed: _logout,
            tooltip: 'Log out',
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      backgroundColor: Colors.indigo[400],
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).padding.bottom + 88,
        ),
        child: Column(
          children: <Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.indigo[300],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: <Widget>[
                  const CircleAvatar(
                    radius: 34,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.account_circle_rounded,
                      size: 58,
                      color: Color(0xFF6168D7),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          headerName,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Keep emergency contacts, health notes, and preferences up to date.',
                          style: TextStyle(
                            color: Color(0xFFDDE1FF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _buildSection(
              title: 'Basic Information',
              icon: Icons.person_outline_rounded,
              child: _isEditMode
                  ? Column(
                      children: <Widget>[
                        _buildField(label: 'Name', controller: _nameController),
                        const SizedBox(height: 10),
                        _buildField(
                          label: 'Age',
                          controller: _ageController,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 10),
                        _buildField(
                          label: 'Preferred Language',
                          controller: _languageController,
                        ),
                      ],
                    )
                  : Column(
                      children: <Widget>[
                        _buildInfoBubble('Name', _nameController.text.trim()),
                        _buildInfoBubble('Age', _ageController.text.trim()),
                        _buildInfoBubble(
                          'Preferred Language',
                          _languageController.text.trim(),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 14),
            _buildSection(
              title: 'Caregiver Contact',
              icon: Icons.contact_phone_outlined,
              child: _isEditMode
                  ? Column(
                      children: <Widget>[
                        _buildField(
                          label: 'Caregiver Name',
                          controller: _caregiverNameController,
                        ),
                        const SizedBox(height: 10),
                        _buildField(
                          label: 'Caregiver Phone',
                          controller: _caregiverPhoneController,
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                    )
                  : Column(
                      children: <Widget>[
                        _buildInfoBubble(
                          'Caregiver Name',
                          _caregiverNameController.text.trim(),
                        ),
                        _buildInfoBubble(
                          'Caregiver Phone',
                          _caregiverPhoneController.text.trim(),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 14),
            _buildSection(
              title: 'Medical Notes',
              icon: Icons.medical_information_outlined,
              child: _isEditMode
                  ? _buildField(
                      label: 'Allergies, doctor notes, etc.',
                      controller: _medicalNotesController,
                      minLines: 3,
                      maxLines: 5,
                    )
                  : _buildInfoBubble(
                      'Medical Notes',
                      _medicalNotesController.text.trim(),
                    ),
            ),
            const SizedBox(height: 14),
            _buildSection(
              title: 'Preferences',
              icon: Icons.tune_rounded,
              child: _isEditMode
                  ? Column(
                      children: <Widget>[
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _medicationReminders,
                          onChanged: (value) {
                            setState(() => _medicationReminders = value);
                          },
                          title: const Text('Medication reminders'),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _locationSharing,
                          onChanged: (value) {
                            setState(() => _locationSharing = value);
                          },
                          title: const Text('Share location in emergencies'),
                        ),
                      ],
                    )
                  : Column(
                      children: <Widget>[
                        _buildInfoBubble(
                          'Medication reminders',
                          _medicationReminders ? 'On' : 'Off',
                        ),
                        _buildInfoBubble(
                          'Share location in emergencies',
                          _locationSharing ? 'On' : 'Off',
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isEditMode
                    ? _saveProfile
                    : () {
                        setState(() {
                          _isEditMode = true;
                        });
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF273444),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _isEditMode ? 'Save Profile' : 'Edit Profile',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}