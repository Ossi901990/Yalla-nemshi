// lib/screens/create_walk_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/walk_event.dart';
import 'map_pick_screen.dart';
import '../services/app_preferences.dart';
import '../services/geocoding_service.dart';
import '../services/crash_service.dart';
import '../utils/error_handler.dart';

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

  // ===== Point-to-point visibility =====
  bool _isPrivatePointToPoint = false;
  String? _privateShareCode;

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
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w500),
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
              helpTextStyle: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ) ??
                  const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
              hourMinuteColor: dialogBg,
              hourMinuteTextColor: Colors.white,
              hourMinuteTextStyle: Theme.of(context)
                  .textTheme
                  .displayMedium
                  ?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ) ??
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
              dialBackgroundColor: dialogBg,
              dialHandColor: accent,
              dialTextColor: Colors.white,
              dialTextStyle: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ) ??
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
              entryModeIconColor: Colors.white70,
              dayPeriodColor: dialogBg,
              dayPeriodTextColor: Colors.white,
              dayPeriodTextStyle: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ) ??
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
              dayPeriodBorderSide: const BorderSide(color: Colors.white24),
              cancelButtonStyle: TextButton.styleFrom(
                foregroundColor: Colors.white70,
                textStyle: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600) ??
                    const TextStyle(
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
                textStyle: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w700) ??
                    const TextStyle(
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
        // If geocoding fails, city remains null
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
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final seed = DateTime.now().millisecondsSinceEpoch;
    return List.generate(
      6,
      (i) => chars[(seed + i * 13) % chars.length],
    ).join();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to create a walk.'),
        ),
      );
      return;
    }

    final walkType = _walkTypeIndex == 0
        ? 'point_to_point'
        : 'loop';

    // Ensure share code exists if private point-to-point
    if (walkType == 'point_to_point' && _isPrivatePointToPoint) {
      _privateShareCode ??= _generateShareCode();
    }

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

    final payload = <String, dynamic>{
      'walkType': walkType,
      'title': _title,
      'dateTime': _dateTime.toIso8601String(),
      'distanceKm': effectiveDistanceKm,
      'gender': _gender,
      'hostUid': uid,
      'cancelled': false,

      // ===== Visibility & join rules (Point-to-point only for now) =====
      'visibility': (walkType == 'point_to_point' && _isPrivatePointToPoint)
          ? 'private'
          : 'open',
      'joinPolicy': 'request',
      'shareCode': (walkType == 'point_to_point' && _isPrivatePointToPoint)
          ? _privateShareCode
          : null,

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

      'city': _detectedCity,

      'description': _description.isEmpty ? null : _description,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      // Show loading indicator
      if (!mounted) return;
      
      final loadingDialog = _buildLoadingDialog(context);
      Navigator.of(context).push(loadingDialog);

      try {
        final docRef = await FirebaseFirestore.instance
            .collection('walks')
            .add(payload)
            .timeout(const Duration(seconds: 30));

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
          isOwner: true,
          joined: false,
          meetingPlaceName: _meetingPlace.isEmpty ? null : _meetingPlace,
          meetingLat: effectiveMeeting?.latitude,
          meetingLng: effectiveMeeting?.longitude,
          startLat: effectiveStart?.latitude,
          startLng: effectiveStart?.longitude,
          endLat: effectiveEnd?.latitude,
          endLng: effectiveEnd?.longitude,
          city: _detectedCity,
          description: _description.isEmpty ? null : _description,
        );

        widget.onEventCreated(newEvent);
        widget.onCreatedNavigateHome();
      } on TimeoutException catch (e, st) {
        if (!mounted) return;
        Navigator.of(context).pop(); // close loading dialog
        
        await ErrorHandler.handleError(
          context,
          e,
          st,
          action: 'create_walk',
          userMessage: 'Creating the walk took too long. Please check your internet and try again.',
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
        userMessage = 'You don\'t have permission to create walks. Try logging out and back in.';
      } else if (e.toString().contains('network') || 
                 e.toString().contains('Connection')) {
        userMessage = 'Network error. Check your internet connection and try again.';
      } else if (e.toString().contains('INVALID_ARGUMENT')) {
        userMessage = 'Please fill in all required fields correctly.';
      }

      if (mounted) {
        ErrorHandler.showErrorSnackBar(context, userMessage);
      }
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
          : const Color(0xFF4F925C),
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
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                              color: isDark ? Colors.white : Colors.white,
                              fontWeight: FontWeight.w600,
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
                        color: (isDark ? Colors.white : Colors.black)
                            .withAlpha((kCardBorderAlpha * 255).round()),
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
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          hintStyle: TextStyle(
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
                                  : const Color(0xFF294630),
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
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF294630),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Set your walk details and invite others to join.',
                              style: theme.textTheme.bodySmall?.copyWith(
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
                                                ? Colors.white.withAlpha((0.06 * 255).round())
                                                : Colors.black.withAlpha((0.04 * 255).round()),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color:
                                                  (isDark
                                                          ? Colors.white
                                                          : Colors.black)
                                                      .withAlpha((0.08 * 255).round()),
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
                                                  ? Colors.white.withAlpha((0.10 * 255).round())
                                                  : Colors.white,
                                            ),
                                            labelColor: isDark
                                                ? Colors.white
                                                : const Color(0xFF294630),
                                            unselectedLabelColor: isDark
                                                ? Colors.white70
                                                : Colors.black54,
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
                                                ? Colors.white.withAlpha((0.06 * 255).round())
                                                : Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color:
                                                  (isDark
                                                          ? Colors.white
                                                          : Colors.black)
                                                      .withAlpha((0.12 * 255).round()),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.my_location,
                                                size: 18,
                                                color: isDark
                                                    ? Colors.white70
                                                    : const Color(0xFF294630),
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
                                                      : const Color(0xFF294630),
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
                                              style:
                                                  theme.textTheme.titleMedium,
                                            ),
                                          ),
                                          const SizedBox(height: 12),

                                          // Visibility (Open / Private)
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              'Visibility',
                                              style: theme.textTheme.titleSmall,
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
                                                      _privateShareCode = null;
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
                                                      _privateShareCode ??=
                                                          _generateShareCode();
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
                                                    color: isDark
                                                        ? Colors.white70
                                                        : Colors.black54,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(height: 16),

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
                                              style:
                                                  theme.textTheme.titleMedium,
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
                                              style:
                                                  theme.textTheme.titleMedium,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              'No destination. Walk freely and end whenever you want.',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
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

                                        // Date & time
                                        ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          title: Text(
                                            'Date & time',
                                            style: theme.textTheme.titleMedium,
                                          ),
                                          subtitle: Text(
                                            _formatDateTime(_dateTime),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
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
                                                0xFF14532D,
                                              ),
                                              foregroundColor: Colors.white,
                                            ),
                                            child: Text(
                                              _walkTypeIndex == 0
                                                  ? 'Create walk'
                                                  : 'Create loop walk',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
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



