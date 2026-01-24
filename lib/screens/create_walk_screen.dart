// lib/screens/create_walk_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import '../models/walk_event.dart';
import '../models/recurrence_rule.dart';
import 'map_pick_screen.dart';
import '../services/app_preferences.dart';
import '../services/geocoding_service.dart';
import '../services/crash_service.dart';
import '../services/recurring_walk_service.dart';
import '../services/storage_service.dart';
import '../utils/error_handler.dart';
import '../utils/invite_utils.dart';
import '../utils/search_utils.dart';

// ===== Design tokens (match Home / Profile) =====
const double kRadiusCard = 24;
const double kRadiusControl = 16;
const double kRadiusPill = 999;

const double kSpace1 = 8;
const double kSpace2 = 16;
const double kSpace3 = 24;
const double kSpace4 = 32;

const Color kLightSurface = Color(0xFFFBFEF8);
const double kCardElevationLight = 0.6;
const double kCardElevationDark = 0.0;
const double kCardBorderAlpha = 0.06;


class CreateWalkScreen extends StatefulWidget {
  final void Function(WalkEvent) onEventCreated;
  final VoidCallback onCreatedNavigateHome;

  const CreateWalkScreen({
    super.key,
    required this.onEventCreated,
    required this.onCreatedNavigateHome,
  });

  @override
  State<CreateWalkScreen> createState() => _CreateWalkScreenState();
}

class _CreateWalkScreenState extends State<CreateWalkScreen> {
  final _formKey = GlobalKey<FormState>();

  // ===== Walk type tabs =====
  // 0 = Point to point (default), 1 = Loop
  int _walkTypeIndex = 0;

  String _title = '';

  // Free walk distance (optional unless edited)
  double _distanceKm = 3.0;
  bool _distanceEdited = false;

  String _gender = 'Mixed';
  String _pace = 'Normal';
  DateTime _dateTime = DateTime.now().add(const Duration(days: 1));

  // Legacy meeting point name (kept for backwards compatibility)
  final String _meetingPlace = '';

  // Coordinates picked from the map
  LatLng? _meetingLatLng;

  // Start/end points (if null, start defaults to "My current location")
  LatLng? _startLatLng;
  LatLng? _endLatLng;

  // City detected from meeting location
  String? _detectedCity;

  // Type B (loop): Duration + Distance (kept in sync)
  int _loopMinutes = 30;
  double _loopDistanceKm = 3.0;

  final TextEditingController _loopMinutesCtrl = TextEditingController();
  final TextEditingController _loopDistanceCtrl = TextEditingController();

  bool _syncingLoop = false;

  // Simple pace assumption: 12 minutes per km (≈ 5 km/h)
  static const double _minutesPerKm = 12.0;

  String _description = '';

  // ===== Tags / vibe metadata =====
  static const List<String> _walkTagOptions = [
    'Scenic views',
    'City loop',
    'Trail run',
    'Dog friendly',
    'Family / stroller',
    'Sunrise',
    'Sunset',
    'Coffee after',
    'Mindful pace',
    'Women only',
    'Beginners welcome',
    'Hiking',
  ];
  final Set<String> _selectedTags = {};

  static const List<String> _comfortOptions = [
    'Social & chatty',
    'Quiet & mindful',
    'Workout focused',
  ];
  String _comfortLevel = _comfortOptions.first;

  static const List<String> _experienceOptions = [
    'All levels',
    'Beginners welcome',
    'Intermediate walkers',
    'Advanced hikers',
  ];
  String _experienceLevel = _experienceOptions.first;

  // ===== Photo picker fields =====
  final List<_SelectedPhoto> _selectedPhotos = [];
  final ImagePicker _imagePicker = ImagePicker();

  // ===== Recurring walk fields =====
  bool _isRecurring = false;
  RecurrenceType _recurrenceType = RecurrenceType.weekly;
  final Set<int> _selectedWeekDays = {
    DateTime.now().weekday,
  }; // Default to today's weekday
  DateTime? _recurringEndDate;

  // ===== Point-to-point visibility =====
  bool _isPrivatePointToPoint = false;
  String? _privateShareCode;
  DateTime? _shareCodeGeneratedAt;
  String? _draftWalkId;

  @override
  void initState() {
    super.initState();

    // Loop defaults (initial text)
    _loopMinutesCtrl.text = _loopMinutes.toString();
    _loopDistanceCtrl.text = _loopDistanceKm.toStringAsFixed(1);

    // Sync logic (two-way)
    _loopMinutesCtrl.addListener(() {
      if (_syncingLoop) return;
      if (_walkTypeIndex != 1) return; // only react while on Loop tab

      final raw = _loopMinutesCtrl.text.trim();
      final mins = int.tryParse(raw);
      if (mins == null || mins <= 0) return;

      final km = mins / _minutesPerKm;

      _syncingLoop = true;
      _loopDistanceKm = km;
      _loopDistanceCtrl.text = km.toStringAsFixed(1);
      _syncingLoop = false;
    });

    _loopDistanceCtrl.addListener(() {
      if (_syncingLoop) return;
      if (_walkTypeIndex != 1) return; // only react while on Loop tab

      final raw = _loopDistanceCtrl.text.trim();
      final km = double.tryParse(raw);
      if (km == null || km <= 0) return;

      final mins = (km * _minutesPerKm).round();

      _syncingLoop = true;
      _loopMinutes = mins;
      _loopMinutesCtrl.text = mins.toString();
      _syncingLoop = false;
    });

    _loadDefaultsFromPrefs();
  }

  @override
  void dispose() {
    _loopMinutesCtrl.dispose();
    _loopDistanceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDefaultsFromPrefs() async {
    final distance = await AppPreferences.getDefaultDistanceKm();
    final gender = await AppPreferences.getDefaultGender();

    if (!mounted) return;
    setState(() {
      _distanceKm = distance;
      _gender = gender;
    });
  }

  String _formatDateTime(DateTime dt) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
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

    final w = weekdays[dt.weekday - 1];
    final m = months[dt.month - 1];
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');

    return '$w, $d $m • $hh:$mm';
  }

  /// Build a loading dialog for async operations
  PageRoute _buildLoadingDialog(BuildContext context) {
    return PageRouteBuilder(
      opaque: false,
      barrierDismissible: false,
      pageBuilder: (context, animation, secondaryAnimation) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Creating your walk...',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        if (!isDark) return child!;

        const dialogBg = Color(0xFF0C2430);
        const accent = Color(0xFF1F6E8C);
        const accentContainer = Color(0xFF164B60);

        final cs = theme.colorScheme.copyWith(
          brightness: Brightness.dark,
          surface: dialogBg,
          surfaceContainerHighest: dialogBg,
          onSurface: Colors.white,
          primary: accent,
          onPrimary: Colors.white,
          primaryContainer: accentContainer,
          onPrimaryContainer: Colors.white,
          secondary: accent,
          onSecondary: Colors.white,
          secondaryContainer: accentContainer,
          onSecondaryContainer: Colors.white,
        );

        return Theme(
          data: theme.copyWith(
            colorScheme: cs,
            datePickerTheme: const DatePickerThemeData(
              backgroundColor: dialogBg,
              headerBackgroundColor: dialogBg,
              headerForegroundColor: Colors.white,
            ),
            dialogTheme: const DialogThemeData(backgroundColor: dialogBg),
          ),
          child: child!,
        );
      },
    );

    if (date == null) return;

    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
      builder: (context, child) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        if (!isDark) return child!;

        const dialogBg = Color(0xFF0C2430);
        const accent = Color(0xFF1F6E8C);
        const accentContainer = Color(0xFF164B60);

        final cs = theme.colorScheme.copyWith(
          brightness: Brightness.dark,
          surface: dialogBg,
          surfaceContainerHighest: dialogBg,
          onSurface: Colors.white,
          primary: accent,
          onPrimary: Colors.white,
          primaryContainer: accentContainer,
          onPrimaryContainer: Colors.white,
        );

        return Theme(
          data: theme.copyWith(
            colorScheme: cs,
            timePickerTheme: TimePickerThemeData(
              backgroundColor: dialogBg,
              padding: const EdgeInsets.all(20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              helpTextStyle:
                  Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ) ??
                  const TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
              hourMinuteColor: dialogBg,
              hourMinuteTextColor: Colors.white,
              hourMinuteTextStyle:
                  Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ) ??
                  const TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
              dialBackgroundColor: dialogBg,
              dialHandColor: accent,
              dialTextColor: Colors.white,
              dialTextStyle:
                  Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ) ??
                  const TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
              entryModeIconColor: Colors.white70,
              dayPeriodColor: dialogBg,
              dayPeriodTextColor: Colors.white,
              dayPeriodTextStyle:
                  Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ) ??
                  const TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
              dayPeriodBorderSide: const BorderSide(color: Colors.white24),
              cancelButtonStyle: TextButton.styleFrom(
                foregroundColor: Colors.white70,
                textStyle:
                    Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ) ??
                    const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
              confirmButtonStyle: TextButton.styleFrom(
                foregroundColor: Colors.white,
                textStyle:
                    Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ) ??
                    const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
            dialogTheme: const DialogThemeData(backgroundColor: dialogBg),
          ),
          child: child!,
        );
      },
    );

    if (time == null) return;

    if (!mounted) return;

    setState(() {
      _dateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _pickOnMap() async {
    final result = await Navigator.of(context).push<List<LatLng>>(
      MaterialPageRoute(builder: (_) => const MapPickScreen()),
    );

    if (result != null && result.length == 2) {
      final startPoint = result[0];

      // Auto-detect city from meeting location
      String? detectedCity;
      try {
        detectedCity = await GeocodingService.getCityFromCoordinates(
          latitude: startPoint.latitude,
          longitude: startPoint.longitude,
        );
      } catch (e) {
        debugPrint('Error detecting city: $e');
        // If geocoding fails, fall back to user's saved city
        try {
          detectedCity = await AppPreferences.getUserCity();
        } catch (_) {
          // City detection completely failed - will be null
        }
      }

      if (mounted) {
        setState(() {
          _startLatLng = startPoint;
          _endLatLng = result[1];
          _meetingLatLng = _startLatLng; // legacy
          _detectedCity = detectedCity;
        });
      }
    }
  }

  String _generateShareCode() {
    return InviteUtils.generateShareCode();
  }

  void _preparePrivateInviteState() {
    _privateShareCode ??= _generateShareCode();
    _shareCodeGeneratedAt ??= DateTime.now();
    _draftWalkId ??=
        FirebaseFirestore.instance.collection('walks').doc().id;
  }

  void _resetPrivateInviteState() {
    _privateShareCode = null;
    _shareCodeGeneratedAt = null;
    _draftWalkId = null;
  }

  String? _buildInviteLink() {
    if (_draftWalkId == null || _privateShareCode == null) return null;
    return InviteUtils.buildInviteLink(
      walkId: _draftWalkId!,
      shareCode: _privateShareCode!,
    );
  }

  Future<void> _copyInviteCode() async {
    final code = _privateShareCode;
    if (code == null) return;

    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Invite code copied')));
  }

  Future<void> _copyInviteLink() async {
    final link = _buildInviteLink();
    if (link == null) return;

    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite link copied')),
    );
  }

  void _regenerateInviteCode() {
    setState(() {
      _privateShareCode = _generateShareCode();
      _shareCodeGeneratedAt = DateTime.now();
      _draftWalkId ??=
          FirebaseFirestore.instance.collection('walks').doc().id;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Invite code refreshed')));
  }

  Widget _buildInviteCodeCard(ThemeData theme, bool isDark) {
    final code = _privateShareCode ?? '------';
    final generatedAt = _shareCodeGeneratedAt ?? DateTime.now();
    final expiresAt = generatedAt.add(InviteUtils.privateInviteTtl);
    final expiryText = _formatDateTime(expiresAt);
    final expiresInDays = InviteUtils.privateInviteTtl.inDays;
    final hasInviteLink = _buildInviteLink() != null;

    final borderColor = (isDark ? Colors.white : Colors.black).withAlpha(
      (0.12 * 255).round(),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        color: isDark
            ? Colors.white.withAlpha((0.05 * 255).round())
            : Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Private invite code',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF1A2332),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      code,
                      style:
                          theme.textTheme.headlineSmall?.copyWith(
                            fontFamily: 'Poppins',
                            letterSpacing: 2,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A2332),
                          ) ??
                          TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 20,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A2332),
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Copy invite code',
                icon: const Icon(Icons.copy),
                onPressed: _privateShareCode == null ? null : _copyInviteCode,
              ),
              TextButton(
                onPressed: _regenerateInviteCode,
                child: const Text('Regenerate'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Expires $expiresInDays days after you publish (est. $expiryText). '
            'Regenerating immediately invalidates the previous code.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: hasInviteLink ? _copyInviteLink : null,
            icon: const Icon(Icons.link),
            label: const Text('Copy invite link'),
          ),
          const SizedBox(height: 6),
          Text(
            'The invite link becomes active once you publish this private walk.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // ===== Photo picker methods =====
  Future<void> _pickPhotos() async {
    try {
      final List<XFile> pickedFiles = await _imagePicker.pickMultiImage(
        maxHeight: 1080,
        maxWidth: 1080,
        imageQuality: 85,
      );

      if (pickedFiles.isEmpty) return;

      // Limit to 10 photos max
      final available = 10 - _selectedPhotos.length;
      final limited = pickedFiles.take(available).toList();
      if (limited.isEmpty) return;

      final newPhotos = <_SelectedPhoto>[];
      for (final xf in limited) {
        newPhotos.add(await _createSelectedPhoto(xf));
      }

      if (!mounted) return;
      setState(() {
        _selectedPhotos.addAll(newPhotos);
      });

      if (mounted && _selectedPhotos.length >= 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maximum 10 photos reached'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e, st) {
      debugPrint('❌ Photo pick error: $e');
      CrashService.recordError(e, st);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick photos: $e')));
      }
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _selectedPhotos.removeAt(index);
    });
  }

  Future<_SelectedPhoto> _createSelectedPhoto(XFile file) async {
    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      return _SelectedPhoto(bytes: bytes, mimeType: file.mimeType);
    }
    return _SelectedPhoto(file: File(file.path), mimeType: file.mimeType);
  }

  /// Upload selected photos to Firebase Storage and return URLs
  Future<List<String>> _uploadPhotos(String walkId) async {
    if (_selectedPhotos.isEmpty) return [];

    final photoUrls = <String>[];

    try {
      for (int i = 0; i < _selectedPhotos.length; i++) {
        final photo = _selectedPhotos[i];
        final photoIndex = 'photo_$i';

        final url = await StorageService.uploadWalkPhoto(
          walkId: walkId,
          photoFile: photo.file,
          photoBytes: photo.bytes,
          contentType: photo.mimeType,
          photoIndex: photoIndex,
        );

        photoUrls.add(url);
      }

      debugPrint('✅ Uploaded ${photoUrls.length} photos');
      return photoUrls;
    } catch (e, st) {
      debugPrint('❌ Photo upload batch error: $e');
      CrashService.recordError(e, st);
      rethrow;
    }
  }

  Future<void> _pickRecurringEndDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _recurringEndDate ?? now.add(const Duration(days: 60)),
      firstDate: _dateTime,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _recurringEndDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final currentUser = FirebaseAuth.instance.currentUser;
    final uid = currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to create a walk.'),
        ),
      );
      return;
    }

    // ✅ Refresh auth token to ensure it's valid (fixes permission-denied errors)
    try {
      await currentUser?.reload();
      debugPrint('✅ Auth token refreshed');
    } catch (e) {
      debugPrint('⚠️ Token refresh failed: $e');
      // Continue anyway - token might still be valid
    }

    // ✅ Get host info from Firebase Auth (for new host fields)
    final hostName = currentUser?.displayName;
    final hostPhotoUrl = currentUser?.photoURL;

    final walkType = _walkTypeIndex == 0 ? 'point_to_point' : 'loop';
    final bool isPrivatePointToPoint =
        walkType == 'point_to_point' && _isPrivatePointToPoint;

    if (isPrivatePointToPoint) {
      _preparePrivateInviteState();
    }

    final Timestamp? shareCodeExpiresAt = isPrivatePointToPoint
      ? Timestamp.fromDate(InviteUtils.nextExpiry())
      : null;
    final DateTime? shareCodeExpiresAtDate = shareCodeExpiresAt?.toDate();

    // Compute effective points:
    final LatLng? effectiveStart = _startLatLng;
    final LatLng? effectiveEnd = walkType == 'loop'
        ? (effectiveStart ?? _endLatLng)
        : (walkType == 'free' ? null : _endLatLng);

    final LatLng? effectiveMeeting = effectiveStart ?? _meetingLatLng;

    // Effective distance:
    // - point_to_point: null (we removed distance from this tab)
    // - loop: loopDistanceKm
    // - free: null unless edited
    final double? effectiveDistanceKm = walkType == 'loop'
        ? _loopDistanceKm
        : (walkType == 'free' ? (_distanceEdited ? _distanceKm : null) : null);

    // ✅ Ensure walk has a city (critical for visibility to other users!)
    // Fall back to user's saved city if auto-detect failed
    String? cityForWalk = _detectedCity;
    if (cityForWalk == null || cityForWalk.isEmpty) {
      try {
        cityForWalk = await AppPreferences.getUserCity();
      } catch (_) {
        // City completely unavailable - walk will still be created but may not appear in queries
        debugPrint('⚠️ Warning: Walk created without city information');
      }
    }

    final sanitizedDescription = _description.trim();
    final descriptionForPayload =
        sanitizedDescription.isEmpty ? null : sanitizedDescription;

    final selectedTagsList = _selectedTags.toList(growable: false);

    final keywordBundle = SearchUtils.buildKeywords(
      title: _title,
      description: descriptionForPayload,
      city: cityForWalk,
      tags: selectedTagsList,
      comfortLevel: _comfortLevel,
      experienceLevel: _experienceLevel,
      pace: _pace,
    );

    final payload = <String, dynamic>{
      'walkType': walkType,
      'title': _title,
      'dateTime': Timestamp.fromDate(_dateTime),
      'distanceKm': effectiveDistanceKm,
      'gender': _gender,
      'pace': _pace,
      'hostUid': uid,
      'cancelled': false,

      // ===== Host Info (for UI display) =====
      'hostName': hostName,
      'hostPhotoUrl': hostPhotoUrl,
      'joinedUserUids': [],
      'joinedUserPhotoUrls': [],
      'joinedCount': 0,

      // ===== Visibility & join rules (Point-to-point only for now) =====
      'visibility': isPrivatePointToPoint ? 'private' : 'open',
      'joinPolicy': 'request',
      'shareCode': isPrivatePointToPoint ? _privateShareCode : null,
      'shareCodeExpiresAt': shareCodeExpiresAt,

      // Loop fields
      'loopMinutes': walkType == 'loop' ? _loopMinutes : null,
      'loopDistanceKm': walkType == 'loop' ? _loopDistanceKm : null,

      'meetingPlaceName': _meetingPlace.isEmpty ? null : _meetingPlace,

      // Legacy meeting lat/lng (start point)
      'meetingLat': effectiveMeeting?.latitude,
      'meetingLng': effectiveMeeting?.longitude,

      // Start/end coordinates
      'startLat': effectiveStart?.latitude,
      'startLng': effectiveStart?.longitude,
      'endLat': effectiveEnd?.latitude,
      'endLng': effectiveEnd?.longitude,

      'city': cityForWalk,
      'description': descriptionForPayload,
      'tags': selectedTagsList,
      'comfortLevel': _comfortLevel,
      'experienceLevel': _experienceLevel,
      'searchKeywords': keywordBundle,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      // Show loading indicator
      if (!mounted) return;

      final loadingDialog = _buildLoadingDialog(context);
      Navigator.of(context).push(loadingDialog);

      try {
        // Check if recurring walk
        if (_isRecurring) {
          // Create recurring walk with instances
          final templateWalk = WalkEvent(
            id: '',
            hostUid: uid,
            firestoreId: '',
            title: _title,
            dateTime: _dateTime,
            distanceKm: (effectiveDistanceKm ?? 0),
            gender: _gender,
            pace: _pace,
            visibility: isPrivatePointToPoint ? 'private' : 'open',
            joinPolicy: 'request',
            shareCode: isPrivatePointToPoint ? _privateShareCode : null,
            shareCodeExpiresAt: shareCodeExpiresAtDate,
            isOwner: true,
            joined: false,
            meetingPlaceName: _meetingPlace.isEmpty ? null : _meetingPlace,
            meetingLat: effectiveMeeting?.latitude,
            meetingLng: effectiveMeeting?.longitude,
            startLat: effectiveStart?.latitude,
            startLng: effectiveStart?.longitude,
            endLat: effectiveEnd?.latitude,
            endLng: effectiveEnd?.longitude,
            city: cityForWalk,
            description: descriptionForPayload,
            tags: selectedTagsList,
            comfortLevel: _comfortLevel,
            experienceLevel: _experienceLevel,
            searchKeywords: keywordBundle,
          );

          final recurrence = RecurrenceRule(
            type: _recurrenceType,
            weekDays: _recurrenceType == RecurrenceType.weekly
                ? (_selectedWeekDays.toList()..sort())
                : null,
            monthDay: _recurrenceType == RecurrenceType.monthly
                ? _dateTime.day
                : null,
          );

          await RecurringWalkService.createRecurringWalk(
            templateWalk: templateWalk,
            recurrence: recurrence,
            endDate: _recurringEndDate,
          ).timeout(const Duration(seconds: 30));

          if (!mounted) return;
          Navigator.of(context).pop(); // close loading dialog

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Recurring walk created! ${recurrence.getDescription()}',
              ),
              backgroundColor: const Color(0xFF00D97E),
            ),
          );

          widget.onCreatedNavigateHome();
        } else {
          // Regular walk creation
          debugPrint(
            '📝 Creating walk with title: "${payload['title']}", pace: "${payload['pace']}", gender: "${payload['gender']}"',
          );
          debugPrint('🔐 User UID: $uid');
          debugPrint(
            '✅ Payload hostUid matches user UID: ${payload['hostUid'] == uid}',
          );

            final walksCollection =
              FirebaseFirestore.instance.collection('walks');
            late final DocumentReference<Map<String, dynamic>> docRef;

            if (isPrivatePointToPoint) {
            final forcedWalkId = _draftWalkId ?? walksCollection.doc().id;
            docRef = walksCollection.doc(forcedWalkId);
            await docRef
              .set(payload)
              .timeout(const Duration(seconds: 30));
            } else {
            docRef = await walksCollection
              .add(payload)
              .timeout(const Duration(seconds: 30));
            }

          // Upload photos if any selected
          List<String> photoUrls = [];
          if (_selectedPhotos.isNotEmpty) {
            try {
              photoUrls = await _uploadPhotos(
                docRef.id,
              ).timeout(const Duration(seconds: 60));

              // Update walk document with photo URLs
              if (photoUrls.isNotEmpty) {
                await docRef.update({'photoUrls': photoUrls});
                debugPrint('✅ Walk document updated with photo URLs');
              }
            } catch (e, st) {
              debugPrint('⚠️ Photo upload failed (walk still created): $e');
              CrashService.recordError(
                e,
                st,
                reason: 'Photo upload after walk creation',
              );
              // Don't throw - walk is already created
            }
          }

          if (!mounted) return;
          Navigator.of(context).pop(); // close loading dialog

          final newEvent = WalkEvent(
            id: docRef.id,
            hostUid: uid,
            firestoreId: docRef.id,
            title: _title,
            dateTime: _dateTime,
            distanceKm: (effectiveDistanceKm ?? 0),
            gender: _gender,
            pace: _pace,
            visibility: isPrivatePointToPoint ? 'private' : 'open',
            joinPolicy: 'request',
            shareCode: isPrivatePointToPoint ? _privateShareCode : null,
            shareCodeExpiresAt: shareCodeExpiresAtDate,
            isOwner: true,
            joined: false,
            meetingPlaceName: _meetingPlace.isEmpty ? null : _meetingPlace,
            meetingLat: effectiveMeeting?.latitude,
            meetingLng: effectiveMeeting?.longitude,
            startLat: effectiveStart?.latitude,
            startLng: effectiveStart?.longitude,
            endLat: effectiveEnd?.latitude,
            endLng: effectiveEnd?.longitude,
            city: cityForWalk,
            description: descriptionForPayload,
            tags: selectedTagsList,
            comfortLevel: _comfortLevel,
            experienceLevel: _experienceLevel,
            searchKeywords: keywordBundle,
          );

          widget.onEventCreated(newEvent);
          widget.onCreatedNavigateHome();
        }
      } on TimeoutException catch (e, st) {
        if (!mounted) return;
        Navigator.of(context).pop(); // close loading dialog

        await ErrorHandler.handleError(
          context,
          e,
          st,
          action: 'create_walk',
          userMessage:
              'Creating the walk took too long. Please check your internet and try again.',
        );
      }
    } catch (e, st) {
      if (!mounted) return;

      // Ensure loading dialog is closed
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      debugPrint('❌ Walk creation error: $e');
      CrashService.recordError(e, st);

      String userMessage = 'Unable to create walk';

      if (e.toString().contains('PERMISSION_DENIED')) {
        userMessage =
            'You don\'t have permission to create walks. Try logging out and back in.';
      } else if (e.toString().contains('network') ||
          e.toString().contains('Connection')) {
        userMessage =
            'Network error. Check your internet connection and try again.';
      } else if (e.toString().contains('INVALID_ARGUMENT')) {
        userMessage = 'Please fill in all required fields correctly.';
      }

      if (mounted) {
        ErrorHandler.showErrorSnackBar(context, userMessage);
      }
    }
  }

  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: isDark
          ? const Color(0xFF071B26)
          : const Color(0xFF1ABFC4),
      body: Column(
        children: [
          // ===== HOME-STYLE HEADER (no bar) =====
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _HeaderLogo(),
                      const SizedBox(width: 8),
                      Text(
                        'Yalla Nemshi',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 32),
                ],
              ),
            ),
          ),

          // ===== MAIN AREA =====
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  gradient: isDark
                      ? const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF071B26), Color(0xFF041016)],
                        )
                      : null,
                  color: isDark ? null : const Color(0xFFF7F9F2),
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    kSpace2,
                    kSpace2,
                    kSpace2,
                    kSpace3 +
                        MediaQuery.of(context).viewInsets.bottom +
                        MediaQuery.of(context).padding.bottom,
                  ),
                  child: Card(
                    color: isDark ? const Color(0xFF0C2430) : kLightSurface,
                    elevation: isDark
                        ? kCardElevationDark
                        : kCardElevationLight,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(kRadiusCard),
                      side: BorderSide(
                        color: (isDark ? Colors.white : Colors.black).withAlpha(
                          (kCardBorderAlpha * 255).round(),
                        ),
                      ),
                    ),
                    child: Theme(
                      data: theme.copyWith(
                        inputDecorationTheme: InputDecorationTheme(
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withAlpha((0.06 * 255).round())
                              : Colors.white,
                          labelStyle: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          hintStyle: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(kRadiusControl),
                            borderSide: BorderSide(
                              color: (isDark ? Colors.white : Colors.black)
                                  .withAlpha((0.12 * 255).round()),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(kRadiusControl),
                            borderSide: BorderSide(
                              color: (isDark ? Colors.white : Colors.black)
                                  .withAlpha((0.12 * 255).round()),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(kRadiusControl),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white.withAlpha((0.35 * 255).round())
                                  : const Color(0xFF1A2332),
                              width: 1.2,
                            ),
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          kSpace2,
                          kSpace3,
                          kSpace2,
                          kSpace3,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create walk',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1A2332),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Set your walk details and invite others to join.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 20),

                            DefaultTabController(
                              length: 3,
                              initialIndex: 0,
                              child: Builder(
                                builder: (context) {
                                  final tabController = DefaultTabController.of(
                                    context,
                                  );

                                  tabController.addListener(() {
                                    if (!tabController.indexIsChanging) return;
                                    setState(() {
                                      _walkTypeIndex = tabController.index;
                                      _distanceEdited = false;
                                    });
                                  });

                                  return Form(
                                    key: _formKey,
                                    child: Column(
                                      children: [
                                        // Tabs
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? Colors.white.withAlpha(
                                                    (0.06 * 255).round(),
                                                  )
                                                : Colors.black.withAlpha(
                                                    (0.04 * 255).round(),
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color:
                                                  (isDark
                                                          ? Colors.white
                                                          : Colors.black)
                                                      .withAlpha(
                                                        (0.08 * 255).round(),
                                                      ),
                                            ),
                                          ),
                                          child: TabBar(
                                            dividerColor: Colors.transparent,
                                            indicatorSize:
                                                TabBarIndicatorSize.tab,
                                            indicator: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              color: isDark
                                                  ? Colors.white.withAlpha(
                                                      (0.10 * 255).round(),
                                                    )
                                                  : Colors.white,
                                            ),
                                            labelColor: isDark
                                                ? Colors.white
                                                : const Color(0xFF1A2332),
                                            unselectedLabelColor: isDark
                                                ? Colors.white70
                                                : Colors.black54,
                                            labelStyle: const TextStyle(
                                              fontFamily: 'Poppins',
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                            ),
                                            unselectedLabelStyle:
                                                const TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                ),
                                            tabs: const [
                                              Tab(text: 'Point to point'),
                                              Tab(text: 'Loop'),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 16),

                                        // Title
                                        TextFormField(
                                          decoration: const InputDecoration(
                                            labelText: 'Title',
                                          ),
                                          onSaved: (val) =>
                                              _title = (val ?? '').trim(),
                                          validator: (val) =>
                                              (val == null ||
                                                  val.trim().isEmpty)
                                              ? 'Required'
                                              : null,
                                        ),
                                        const SizedBox(height: 12),

                                        // Shared starting point (single place only)
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? Colors.white.withAlpha(
                                                    (0.06 * 255).round(),
                                                  )
                                                : Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color:
                                                  (isDark
                                                          ? Colors.white
                                                          : Colors.black)
                                                      .withAlpha(
                                                        (0.12 * 255).round(),
                                                      ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.my_location,
                                                size: 18,
                                                color: isDark
                                                    ? Colors.white70
                                                    : const Color(0xFF1A2332),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  _startLatLng == null
                                                      ? 'Starting from: My current location'
                                                      : 'Starting from: Custom location selected',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: theme
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        fontFamily: 'Inter',
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: isDark
                                                            ? Colors.white
                                                            : Colors.black87,
                                                      ),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: _pickOnMap,
                                                style: TextButton.styleFrom(
                                                  foregroundColor: isDark
                                                      ? Colors.white70
                                                      : const Color(0xFF1A2332),
                                                ),
                                                child: const Text('Change'),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 16),

                                        // ===== TYPE-SPECIFIC SECTION =====
                                        if (_walkTypeIndex == 0) ...[
                                          // Point-to-point
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              'Route',
                                              style: theme.textTheme.titleMedium
                                                  ?.copyWith(
                                                    fontFamily: 'Poppins',
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark
                                                        ? Colors.white
                                                        : const Color(
                                                            0xFF1A2332,
                                                          ),
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(height: 12),

                                          // Visibility (Open / Private)
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              'Visibility',
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                    fontFamily: 'Poppins',
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark
                                                        ? Colors.white
                                                        : const Color(
                                                            0xFF1A2332,
                                                          ),
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),

                                          Row(
                                            children: [
                                              Expanded(
                                                child: ChoiceChip(
                                                  label: const Text('Open'),
                                                  selected:
                                                      !_isPrivatePointToPoint,
                                                  onSelected: (_) {
                                                    setState(() {
                                                      _isPrivatePointToPoint =
                                                          false;
                                                      _resetPrivateInviteState();
                                                    });
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: ChoiceChip(
                                                  label: const Text('Private'),
                                                  selected:
                                                      _isPrivatePointToPoint,
                                                  onSelected: (_) {
                                                    setState(() {
                                                      _isPrivatePointToPoint =
                                                          true;
                                                      _preparePrivateInviteState();
                                                    });
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              _isPrivatePointToPoint
                                                  ? 'Hidden from Nearby walks. Share a link or QR to invite.'
                                                  : 'Visible in Nearby walks. Others can request to join.',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    fontFamily: 'Inter',
                                                    fontWeight: FontWeight.w600,
                                                    color: isDark
                                                        ? Colors.white70
                                                        : Colors.black54,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(height: 16),

                                          if (_isPrivatePointToPoint) ...[
                                            _buildInviteCodeCard(theme, isDark),
                                            const SizedBox(height: 16),
                                          ],

                                          // Map picker handled by the top 'Change' button
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              _endLatLng == null
                                                  ? 'Destination pin not selected yet'
                                                  : 'Destination selected on map',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    fontFamily: 'Inter',
                                                    fontWeight: FontWeight.w600,
                                                    color: isDark
                                                        ? Colors.white54
                                                        : Colors.black54,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                        ] else if (_walkTypeIndex == 1) ...[
                                          // Loop
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              'Loop walk',
                                              style: theme.textTheme.titleMedium
                                                  ?.copyWith(
                                                    fontFamily: 'Poppins',
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark
                                                        ? Colors.white
                                                        : const Color(
                                                            0xFF1A2332,
                                                          ),
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),

                                          TextFormField(
                                            controller: _loopMinutesCtrl,
                                            decoration: const InputDecoration(
                                              labelText: 'Duration (minutes)',
                                              hintText: 'e.g. 30',
                                            ),
                                            keyboardType: TextInputType.number,
                                            validator: (val) {
                                              final v = int.tryParse(
                                                (val ?? '').trim(),
                                              );
                                              if (v == null) {
                                                return 'Enter minutes';
                                              }
                                              if (v <= 0) {
                                                return 'Must be greater than 0';
                                              }
                                              if (v > 600) {
                                                return 'Try under 600 minutes';
                                              }
                                              return null;
                                            },
                                            onSaved: (val) {
                                              final v = int.tryParse(
                                                (val ?? '').trim(),
                                              );
                                              if (v != null) _loopMinutes = v;
                                            },
                                          ),
                                          const SizedBox(height: 12),

                                          TextFormField(
                                            controller: _loopDistanceCtrl,
                                            decoration: const InputDecoration(
                                              labelText: 'Distance (km)',
                                              hintText: 'e.g. 3.0',
                                            ),
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            validator: (val) {
                                              final v = double.tryParse(
                                                (val ?? '').trim(),
                                              );
                                              if (v == null) {
                                                return 'Enter distance';
                                              }
                                              if (v <= 0) {
                                                return 'Must be greater than 0';
                                              }
                                              if (v > 100) {
                                                return 'Try under 100 km';
                                              }
                                              return null;
                                            },
                                            onSaved: (val) {
                                              final v = double.tryParse(
                                                (val ?? '').trim(),
                                              );
                                              if (v != null) {
                                                _loopDistanceKm = v;
                                              }
                                            },
                                          ),
                                          const SizedBox(height: 6),
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              'Duration and distance update each other automatically.',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    fontFamily: 'Inter',
                                                    fontWeight: FontWeight.w600,
                                                    color: isDark
                                                        ? Colors.white70
                                                        : Colors.black54,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                        ] else ...[
                                          // Free
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              'Free walk',
                                              style: theme.textTheme.titleMedium
                                                  ?.copyWith(
                                                    fontFamily: 'Poppins',
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark
                                                        ? Colors.white
                                                        : const Color(
                                                            0xFF1A2332,
                                                          ),
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              'No destination. Walk freely and end whenever you want.',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    fontFamily: 'Inter',
                                                    fontWeight: FontWeight.w600,
                                                    color: isDark
                                                        ? Colors.white70
                                                        : Colors.black54,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                        ],

                                        // Distance (Free walk only, optional)
                                        if (_walkTypeIndex == 2) ...[
                                          TextFormField(
                                            key: ValueKey(
                                              'distance_${_walkTypeIndex}_$_distanceKm',
                                            ),
                                            decoration: const InputDecoration(
                                              labelText: 'Distance (km)',
                                              helperText:
                                                  'Optional: only used if you change it',
                                            ),
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            initialValue: _distanceKm
                                                .toStringAsFixed(1),
                                            onChanged: (_) {
                                              setState(
                                                () => _distanceEdited = true,
                                              );
                                            },
                                            validator: (val) {
                                              if (!_distanceEdited) return null;
                                              final d = double.tryParse(
                                                (val ?? '').trim(),
                                              );
                                              if (d == null) {
                                                return 'Please enter a number';
                                              }
                                              if (d <= 0) {
                                                return 'Distance must be greater than 0';
                                              }
                                              if (d > 100) {
                                                return 'That’s a long walk! Try under 100 km';
                                              }
                                              return null;
                                            },
                                            onSaved: (val) {
                                              if (!_distanceEdited) return;
                                              final parsed = double.tryParse(
                                                (val ?? '').trim(),
                                              );
                                              if (parsed != null) {
                                                _distanceKm = parsed;
                                              }
                                            },
                                          ),
                                          const SizedBox(height: 12),
                                        ],

                                        // Gender
                                        DropdownButtonFormField<String>(
                                          initialValue: _gender,
                                          decoration: const InputDecoration(
                                            labelText: 'Who can join?',
                                          ),
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'Mixed',
                                              child: Text('Mixed'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'Women only',
                                              child: Text('Women only'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'Men only',
                                              child: Text('Men only'),
                                            ),
                                          ],
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(() => _gender = val);
                                            }
                                          },
                                        ),
                                        const SizedBox(height: 12),

                                        // Pace
                                        DropdownButtonFormField<String>(
                                          initialValue: _pace,
                                          decoration: const InputDecoration(
                                            labelText: 'Walking pace',
                                          ),
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'Relaxed',
                                              child: Text('Relaxed (2-3 km/h)'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'Normal',
                                              child: Text('Normal (3-4 km/h)'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'Brisk',
                                              child: Text('Brisk (4+ km/h)'),
                                            ),
                                          ],
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(() => _pace = val);
                                            }
                                          },
                                        ),
                                        const SizedBox(height: 12),

                                        // Date & time
                                        ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          title: Text(
                                            'Date & time',
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                  fontFamily: 'Poppins',
                                                  fontWeight: FontWeight.w700,
                                                  color: isDark
                                                      ? Colors.white
                                                      : const Color(0xFF1A2332),
                                                ),
                                          ),
                                          subtitle: Text(
                                            _formatDateTime(_dateTime),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  fontFamily: 'Inter',
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark
                                                      ? Colors.white70
                                                      : Colors.black54,
                                                ),
                                          ),
                                          trailing: IconButton(
                                            icon: Icon(
                                              Icons.calendar_today,
                                              color: isDark
                                                  ? Colors.white70
                                                  : Colors.white,
                                            ),
                                            onPressed: _pickDateTime,
                                          ),
                                        ),
                                        const SizedBox(height: 12),

                                        // Description
                                        TextFormField(
                                          decoration: const InputDecoration(
                                            labelText: 'Description (optional)',
                                          ),
                                          minLines: 3,
                                          maxLines:
                                              MediaQuery.of(
                                                    context,
                                                  ).size.height <
                                                  700
                                              ? 3
                                              : 5,
                                          onSaved: (val) =>
                                              _description = (val ?? '').trim(),
                                        ),
                                        const SizedBox(height: 24),

                                        Text(
                                          'Tags & vibe',
                                          style: theme.textTheme.titleMedium?.copyWith(
                                                fontFamily: 'Poppins',
                                                fontWeight: FontWeight.w700,
                                                color: isDark
                                                    ? Colors.white
                                                    : const Color(0xFF1A2332),
                                              ) ??
                                              TextStyle(
                                                fontFamily: 'Poppins',
                                                fontWeight: FontWeight.w700,
                                                color: isDark
                                                    ? Colors.white
                                                    : const Color(0xFF1A2332),
                                              ),
                                        ),
                                        const SizedBox(height: 12),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: _walkTagOptions.map((tag) {
                                            final selected = _selectedTags.contains(tag);
                                            return GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  if (selected) {
                                                    _selectedTags.remove(tag);
                                                  } else {
                                                    _selectedTags.add(tag);
                                                  }
                                                });
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: selected ? Colors.teal.shade100 : Colors.transparent,
                                                  border: Border.all(
                                                    color: selected ? Colors.teal : Colors.grey.shade400,
                                                    width: 1,
                                                  ),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  tag,
                                                  style: TextStyle(
                                                    fontFamily: 'Inter',
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: selected ? Colors.teal : Colors.grey.shade700,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                        const SizedBox(height: 16),

                                        DropdownButtonFormField<String>(
                                          initialValue: _comfortLevel,
                                          decoration: const InputDecoration(
                                            labelText: 'Comfort vibe',
                                          ),
                                          items: _comfortOptions
                                              .map(
                                                (option) => DropdownMenuItem(
                                                  value: option,
                                                  child: Text(option),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(() => _comfortLevel = val);
                                            }
                                          },
                                        ),
                                        const SizedBox(height: 12),

                                        DropdownButtonFormField<String>(
                                          initialValue: _experienceLevel,
                                          decoration: const InputDecoration(
                                            labelText: 'Experience level',
                                          ),
                                          items: _experienceOptions
                                              .map(
                                                (option) => DropdownMenuItem(
                                                  value: option,
                                                  child: Text(option),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(() => _experienceLevel = val);
                                            }
                                          },
                                        ),
                                        const SizedBox(height: 24),

                                        // ===== Photo Picker Section =====
                                        Container(
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? Colors.white.withAlpha(
                                                    (0.04 * 255).round(),
                                                  )
                                                : Colors.grey.withAlpha(
                                                    (0.05 * 255).round(),
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color:
                                                  (isDark
                                                          ? Colors.white
                                                          : Colors.black)
                                                      .withAlpha(
                                                        (0.12 * 255).round(),
                                                      ),
                                            ),
                                          ),
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    'Photos (Optional)',
                                                    style: theme
                                                        .textTheme
                                                        .titleSmall
                                                        ?.copyWith(
                                                          fontFamily: 'Poppins',
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: isDark
                                                              ? Colors.white
                                                              : const Color(
                                                                  0xFF1A2332,
                                                                ),
                                                        ),
                                                  ),
                                                  if (_selectedPhotos
                                                      .isNotEmpty)
                                                    Text(
                                                      '${_selectedPhotos.length}/10',
                                                      style: theme
                                                          .textTheme
                                                          .labelSmall
                                                          ?.copyWith(
                                                            fontFamily: 'Inter',
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: Colors.grey,
                                                          ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              // Photo grid
                                              if (_selectedPhotos.isEmpty)
                                                Center(
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          24,
                                                        ),
                                                    child: Column(
                                                      children: [
                                                        Icon(
                                                          Icons.image_outlined,
                                                          size: 40,
                                                          color:
                                                              Colors.grey[600],
                                                        ),
                                                        const SizedBox(
                                                          height: 8,
                                                        ),
                                                        Text(
                                                          'Add walk photos',
                                                          style: theme
                                                              .textTheme
                                                              .bodySmall
                                                              ?.copyWith(
                                                                fontFamily:
                                                                    'Inter',
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Colors
                                                                    .grey[600],
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                )
                                              else
                                                GridView.builder(
                                                  shrinkWrap: true,
                                                  physics:
                                                      const NeverScrollableScrollPhysics(),
                                                  gridDelegate:
                                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                                        crossAxisCount: 3,
                                                        crossAxisSpacing: 8,
                                                        mainAxisSpacing: 8,
                                                      ),
                                                  itemCount:
                                                      _selectedPhotos.length,
                                                  itemBuilder: (ctx, idx) {
                                                    final photo =
                                                        _selectedPhotos[idx];
                                                    return Stack(
                                                      children: [
                                                        Container(
                                                          decoration: BoxDecoration(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                            image: DecorationImage(
                                                              image:
                                                                  photo.imageProvider,
                                                              fit: BoxFit.cover,
                                                            ),
                                                          ),
                                                        ),
                                                        Positioned(
                                                          top: 4,
                                                          right: 4,
                                                          child: GestureDetector(
                                                            onTap: () =>
                                                                _removePhoto(
                                                                  idx,
                                                                ),
                                                            child: Container(
                                                              decoration: BoxDecoration(
                                                                color: Colors
                                                                    .red
                                                                    .withAlpha(
                                                                      (0.8 * 255)
                                                                          .round(),
                                                                    ),
                                                                shape: BoxShape
                                                                    .circle,
                                                              ),
                                                              padding:
                                                                  const EdgeInsets.all(
                                                                    2,
                                                                  ),
                                                              child: const Icon(
                                                                Icons.close,
                                                                color: Colors
                                                                    .white,
                                                                size: 14,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                ),
                                              if (_selectedPhotos.length < 10)
                                                const SizedBox(height: 12),
                                              if (_selectedPhotos.length < 10)
                                                SizedBox(
                                                  width: double.infinity,
                                                  child: OutlinedButton.icon(
                                                    onPressed: _pickPhotos,
                                                    icon: const Icon(
                                                      Icons.add_photo_alternate,
                                                    ),
                                                    label: Text(
                                                      _selectedPhotos.isEmpty
                                                          ? 'Pick Photos'
                                                          : 'Add More Photos',
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 24),

                                        // ===== Recurring Walk Section =====
                                        Container(
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? Colors.white.withAlpha(
                                                    (0.04 * 255).round(),
                                                  )
                                                : Colors.grey.withAlpha(
                                                    (0.05 * 255).round(),
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color:
                                                  (isDark
                                                          ? Colors.white
                                                          : Colors.black)
                                                      .withAlpha(
                                                        (0.08 * 255).round(),
                                                      ),
                                            ),
                                          ),
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.repeat,
                                                    size: 20,
                                                    color: isDark
                                                        ? Colors.white70
                                                        : Colors.black87,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Recurring Walk',
                                                    style: theme
                                                        .textTheme
                                                        .titleSmall
                                                        ?.copyWith(
                                                          fontFamily: 'Poppins',
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: isDark
                                                              ? Colors.white
                                                              : const Color(
                                                                  0xFF1A2332,
                                                                ),
                                                        ),
                                                  ),
                                                  const Spacer(),
                                                  Switch(
                                                    value: _isRecurring,
                                                    onChanged: (val) {
                                                      setState(() {
                                                        _isRecurring = val;
                                                      });
                                                    },
                                                  ),
                                                ],
                                              ),
                                              if (_isRecurring) ...[
                                                const SizedBox(height: 16),
                                                // Frequency selector
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: SegmentedButton<RecurrenceType>(
                                                        segments: const [
                                                          ButtonSegment(
                                                            value:
                                                                RecurrenceType
                                                                    .weekly,
                                                            label: Text(
                                                              'Weekly',
                                                            ),
                                                          ),
                                                          ButtonSegment(
                                                            value:
                                                                RecurrenceType
                                                                    .monthly,
                                                            label: Text(
                                                              'Monthly',
                                                            ),
                                                          ),
                                                        ],
                                                        selected: {
                                                          _recurrenceType,
                                                        },
                                                        onSelectionChanged:
                                                            (
                                                              Set<
                                                                RecurrenceType
                                                              >
                                                              newSelection,
                                                            ) {
                                                              setState(() {
                                                                _recurrenceType =
                                                                    newSelection
                                                                        .first;
                                                              });
                                                            },
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                // Weekly: Day selection
                                                if (_recurrenceType ==
                                                    RecurrenceType.weekly) ...[
                                                  Text(
                                                    'Select days:',
                                                    style: theme
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          fontFamily: 'Inter',
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: isDark
                                                              ? Colors.white70
                                                              : Colors.black87,
                                                        ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Wrap(
                                                    spacing: 8,
                                                    runSpacing: 8,
                                                    children: [
                                                      for (var day in [
                                                        (1, 'Mon'),
                                                        (2, 'Tue'),
                                                        (3, 'Wed'),
                                                        (4, 'Thu'),
                                                        (5, 'Fri'),
                                                        (6, 'Sat'),
                                                        (7, 'Sun'),
                                                      ])
                                                        FilterChip(
                                                          label: Text(day.$2),
                                                          selected:
                                                              _selectedWeekDays
                                                                  .contains(
                                                                    day.$1,
                                                                  ),
                                                          onSelected: (val) {
                                                            setState(() {
                                                              if (val) {
                                                                _selectedWeekDays
                                                                    .add(
                                                                      day.$1,
                                                                    );
                                                              } else {
                                                                _selectedWeekDays
                                                                    .remove(
                                                                      day.$1,
                                                                    );
                                                              }
                                                            });
                                                          },
                                                        ),
                                                    ],
                                                  ),
                                                ],
                                                // Monthly: Show info
                                                if (_recurrenceType ==
                                                    RecurrenceType.monthly)
                                                  Text(
                                                    'Repeats on the ${_dateTime.day}${_getDaySuffix(_dateTime.day)} of each month',
                                                    style: theme
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          fontFamily: 'Inter',
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: isDark
                                                              ? Colors.white70
                                                              : Colors.black87,
                                                        ),
                                                  ),
                                                const SizedBox(height: 12),
                                                // End date (optional)
                                                ListTile(
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                  title: Text(
                                                    'End date (optional)',
                                                    style: theme
                                                        .textTheme
                                                        .bodyMedium
                                                        ?.copyWith(
                                                          fontFamily: 'Poppins',
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: isDark
                                                              ? Colors.white
                                                              : const Color(
                                                                  0xFF1A2332,
                                                                ),
                                                        ),
                                                  ),
                                                  subtitle: Text(
                                                    _recurringEndDate != null
                                                        ? '${_recurringEndDate!.day}/${_recurringEndDate!.month}/${_recurringEndDate!.year}'
                                                        : 'No end date',
                                                    style: theme
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: isDark
                                                              ? Colors.white60
                                                              : Colors.black54,
                                                        ),
                                                  ),
                                                  trailing: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      if (_recurringEndDate !=
                                                          null)
                                                        IconButton(
                                                          icon: const Icon(
                                                            Icons.clear,
                                                          ),
                                                          onPressed: () {
                                                            setState(() {
                                                              _recurringEndDate =
                                                                  null;
                                                            });
                                                          },
                                                        ),
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.calendar_today,
                                                        ),
                                                        onPressed:
                                                            _pickRecurringEndDate,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 24),

                                        // Submit
                                        SizedBox(
                                          width: double.infinity,
                                          child: FilledButton(
                                            onPressed: _submit,
                                            style: FilledButton.styleFrom(
                                              minimumSize:
                                                  const Size.fromHeight(52),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              backgroundColor: const Color(
                                                0xFF1A2332,
                                              ),
                                              foregroundColor: Colors.white,
                                            ),
                                            child: Text(
                                              _walkTypeIndex == 0
                                                  ? 'Create walk'
                                                  : 'Create loop walk',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontFamily: 'Poppins',
                                                fontWeight: FontWeight.w700,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
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

class _SelectedPhoto {
  const _SelectedPhoto({this.file, this.bytes, this.mimeType});

  final File? file;
  final Uint8List? bytes;
  final String? mimeType;

  ImageProvider<Object> get imageProvider {
    if (file != null) {
      return FileImage(file!);
    }
    return MemoryImage(bytes!);
  }
}

// Small reusable header logo (matches other screens)
class _HeaderLogo extends StatelessWidget {
  const _HeaderLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white24,
      ),
      child: const Icon(Icons.directions_walk, size: 18, color: Colors.white),
    );
  }
}
