// lib/screens/edit_profile_screen.dart
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
    final _picker = ImagePicker();

  String? _localImagePath;      // for mobile/desktop
  String? _imageBase64ForWeb;   // for web testing


  static const _kDarkBase = Color(0xFF071B26);
  static const _kDarkSurface = Color(0xFF0C2430);
  static const _kLightBase = Color(0xFFF7F9F2);
  static const _kLightHeaderTop = Color(0xFF294630);
  static const _kLightHeaderBottom = Color(0xFF4F925C);

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameController = TextEditingController(text: p?.name ?? '');
    _ageController = TextEditingController(
      text: (p != null && p.age > 0) ? p.age.toString() : '',
    );
    _bioController = TextEditingController(text: p?.bio ?? '');
    _gender = p?.gender ?? 'Not set';
    // Keep existing image (mobile path OR web base64)
    _localImagePath = p?.profileImagePath;
    _imageBase64ForWeb = p?.profileImageBase64;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _bioController.dispose();
    super.dispose();
  }
    Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (picked == null) return;

    if (kIsWeb) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _imageBase64ForWeb = base64Encode(bytes);
        _localImagePath = null;
      });
    } else {
      setState(() {
        _localImagePath = picked.path;
        _imageBase64ForWeb = null;
      });
    }
  }

  void _removeImage() {
    setState(() {
      _localImagePath = null;
      _imageBase64ForWeb = null;
    });
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

      // Mobile keeps file path
      profileImagePath: kIsWeb ? null : (_localImagePath ?? existing?.profileImagePath),

      // Web testing uses base64
      profileImageBase64: kIsWeb ? (_imageBase64ForWeb ?? existing?.profileImageBase64) : null,
    );


    await ProfileStorage.saveProfile(updatedProfile);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  InputDecoration _fieldDecoration({
    required BuildContext context,
    required bool isDark,
    required String label,
  }) {
    final theme = Theme.of(context);
    final borderColor = (isDark ? Colors.white : Colors.black).withAlpha((0.18 * 255).round());

    return InputDecoration(
      labelText: label,
      filled: false, // ✅ prevent grey fill layer
      labelStyle: theme.textTheme.bodySmall?.copyWith(
        color: isDark ? Colors.white70 : Colors.black54,
        fontWeight: FontWeight.w600,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: (isDark ? Colors.white : Colors.black).withAlpha((0.28 * 255).round()),
          width: 1.2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red.withAlpha((0.7 * 255).round()), width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red.withAlpha((0.9 * 255).round()), width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? _kDarkBase : _kLightHeaderBottom,
      body: Column(
        children: [
          // ===== HEADER (match Home/Profile/Settings pattern) =====
          if (isDark)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 18,
                      ),
                      splashRadius: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Edit profile',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ) ?? const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 24,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              height: 64,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_kLightHeaderTop, _kLightHeaderBottom],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 18,
                        ),
                        splashRadius: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Edit profile',
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ) ?? const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ===== MAIN AREA =====
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? _kDarkBase : _kLightBase,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                image: DecorationImage(
                  image: AssetImage(
                    isDark
                        ? 'assets/images/Dark_Grey_Background.png'
                        : 'assets/images/Light_Beige_background.png',
                  ),
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withAlpha((0.35 * 255).round())
                      : Colors.transparent,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Card(
                    color: isDark ? _kDarkSurface : const Color(0xFFFBFEF8),
                    elevation: isDark ? 0.0 : 0.6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(
                        color: (isDark ? Colors.white : Colors.black)
                            .withAlpha((0.06 * 255).round()),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your details',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 14),
                                                        // ===== PROFILE PHOTO (mobile + web testing) =====
                            Row(
                              children: [
                                _ProfilePhotoPreview(
                                  isDark: isDark,
                                  imageBase64: _imageBase64ForWeb,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Profile photo',
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white : const Color(0xFF111827),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: _pickImage,
                                            icon: const Icon(Icons.photo_library_outlined, size: 18),
                                            label: const Text('Change'),
                                          ),
                                          TextButton.icon(
                                            onPressed: _removeImage,
                                            icon: const Icon(Icons.delete_outline, size: 18),
                                            label: const Text('Remove'),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        kIsWeb
                                            ? 'Web testing: stored as base64.'
                                            : 'Stored on device (file path).',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: isDark ? Colors.white60 : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),


                            TextFormField(
                              controller: _nameController,
                              decoration: _fieldDecoration(
                                context: context,
                                isDark: isDark,
                                label: 'Name',
                              ),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),

                            TextFormField(
                              controller: _ageController,
                              decoration: _fieldDecoration(
                                context: context,
                                isDark: isDark,
                                label: 'Age',
                              ),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 12),

                            DropdownButtonFormField<String>(
                              initialValue: _gender,
                              decoration: _fieldDecoration(
                                context: context,
                                isDark: isDark,
                                label: 'Gender',
                              ),
                              dropdownColor: isDark
                                  ? _kDarkSurface
                                  : Colors.white,
                              icon: Icon(
                                Icons.arrow_drop_down,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Not set',
                                  child: Text('Not set'),
                                ),
                                DropdownMenuItem(
                                  value: 'Female',
                                  child: Text('Female'),
                                ),
                                DropdownMenuItem(
                                  value: 'Male',
                                  child: Text('Male'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _gender = value);
                              },
                            ),
                            const SizedBox(height: 12),

                            TextFormField(
                              controller: _bioController,
                              decoration: _fieldDecoration(
                                context: context,
                                isDark: isDark,
                                label: 'Bio',
                              ),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 3,
                            ),

                            const SizedBox(height: 18),

                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _save,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  backgroundColor: const Color(0xFF14532D),
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
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePhotoPreview extends StatelessWidget {
  final bool isDark;
  final String? imageBase64;

  const _ProfilePhotoPreview({
    required this.isDark,
    required this.imageBase64,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF0C2430) : const Color(0xFFFBFEF8);
    final border = (isDark ? Colors.white : Colors.black).withAlpha((0.12 * 255).round());

    if (kIsWeb && imageBase64 != null && imageBase64!.isNotEmpty) {
      final bytes = base64Decode(imageBase64!);
      return CircleAvatar(
        radius: 28,
        backgroundColor: bg,
        backgroundImage: MemoryImage(bytes),
      );
    }

    // On this screen we don't preview local file path to avoid dart:io handling here;
    // actual avatar rendering is handled in ProfileScreen / other UI.
    return CircleAvatar(
      radius: 28,
      backgroundColor: bg,
      child: Icon(Icons.person, color: border),
    );
  }
}