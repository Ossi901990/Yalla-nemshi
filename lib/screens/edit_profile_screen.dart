import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/profile_storage.dart';

class EditProfileScreen extends StatefulWidget {
  final UserProfile? profile;

  const EditProfileScreen({super.key, this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _bioController;
  String _gender = 'Not set';

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameController = TextEditingController(text: p?.name ?? '');
    _ageController =
        TextEditingController(text: p != null && p.age > 0 ? p.age.toString() : '');
    _bioController = TextEditingController(text: p?.bio ?? '');
    _gender = p?.gender ?? 'Not set';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final age = int.tryParse(_ageController.text.trim()) ?? 0;

    final existing = widget.profile;

    final updatedProfile = UserProfile(
      name: _nameController.text.trim(),
      age: age,
      gender: _gender,
      bio: _bioController.text.trim(),
      // VERY IMPORTANT: keep the existing photo if there is one
      profileImagePath: existing?.profileImagePath,
    );

    await ProfileStorage.saveProfile(updatedProfile);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  return Scaffold(
    // ✅ match rest of app
    backgroundColor:
        isDark ? const Color(0xFF0B1A13) : const Color(0xFF4F925C),
    appBar: AppBar(
      title: const Text('Edit profile'),
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [
                    Color(0xFF020908), // darker top
                    Color(0xFF0B1A13), // darker bottom
                  ]
                : const [
                    Color(0xFF294630), // top
                    Color(0xFF4F925C), // bottom
                  ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
    ),
    body: SafeArea(
      top: false, // AppBar already handles status bar
      bottom: false,
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color.fromARGB(255, 9, 2, 7)
                    : const Color(0xFFF7F9F2),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                image: DecorationImage(
                  image: AssetImage(
                    isDark
                        ? 'assets/images/bg_minimal_dark.png'
                        : 'assets/images/bg_minimal_light.png',
                  ),
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
              // overlay so fields stay readable in dark mode
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withOpacity(0.35)
                      : Colors.transparent,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Optional title inside sheet (visually matches others)
                        Text(
                          'Your details',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF294630),
                          ),
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                          ),
                          validator: (value) {
                            if (value == null ||
                                value.trim().isEmpty) {
                              return 'Please enter your name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _ageController,
                          decoration: const InputDecoration(
                            labelText: 'Age',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),

                        DropdownButtonFormField<String>(
                          initialValue: _gender,
                          decoration: const InputDecoration(
                            labelText: 'Gender',
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'Not set',
                                child: Text('Not set')),
                            DropdownMenuItem(
                                value: 'Female',
                                child: Text('Female')),
                            DropdownMenuItem(
                                value: 'Male',
                                child: Text('Male')),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _gender = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _bioController,
                          decoration: const InputDecoration(
                            labelText: 'Bio',
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _save,
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFF14532D),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ),
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