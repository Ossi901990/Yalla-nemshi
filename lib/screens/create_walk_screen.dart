// lib/screens/create_walk_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/walk_event.dart';
import 'map_pick_screen.dart';
import '../services/app_preferences.dart';
import 'package:flutter/services.dart';

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
  // 0 = Point to point (default), 1 = Loop, 2 = Free
  int _walkTypeIndex = 0;

  String _title = '';
  double _distanceKm = 3.0;
  String _gender = 'Mixed';

  DateTime _dateTime = DateTime.now().add(const Duration(days: 1));

  // Type A destination search text (name/label only for now)
  String _destinationText = '';

  // Legacy meeting point name (kept for backwards compatibility)
  String _meetingPlace = '';

  // Coordinates picked from the map
  LatLng? _meetingLatLng;

  // Start/end points (if null, start defaults to "My current location")
  LatLng? _startLatLng;
  LatLng? _endLatLng;

  // Type B (loop) simple duration preset in minutes
  int _loopMinutes = 30;

  String _description = '';


  @override
  void initState() {
    super.initState();
    _loadDefaultsFromPrefs(); // 👈 load saved defaults
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
    // Short weekday names
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

    // Example: "Tue, 10 Dec • 18:30"
    return '$w, $d $m • $hh:$mm';
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

        const dialogBg = Color(0xFF0C2430); // bluish surface
        const accent = Color(0xFF1F6E8C); // bluish highlight
        const accentContainer = Color(0xFF164B60);

        final cs = theme.colorScheme.copyWith(
          brightness: Brightness.dark,

          // These help some internal surfaces
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

            // This controls the date picker background/header
            datePickerTheme: const DatePickerThemeData(
              backgroundColor: dialogBg,
              headerBackgroundColor: dialogBg,
              headerForegroundColor: Colors.white,
            ), dialogTheme: DialogThemeData(backgroundColor: dialogBg),
          ),
          child: child!,
        );
      },
    );

    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
      builder: (context, child) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        if (!isDark) return child!;

        const dialogBg = Color(0xFF0C2430); // bluish surface
        const accent = Color(0xFF1F6E8C); // bluish highlight
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

            // ✅ Forces time picker background + dial look
            timePickerTheme: TimePickerThemeData(
              backgroundColor: dialogBg,

              // More breathing room
              padding: const EdgeInsets.all(20),

              // Rounder + "bigger" feel
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),

              // Header / help
              helpTextStyle: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),

              // Hour/minute fields (make larger)
              hourMinuteColor: dialogBg,
              hourMinuteTextColor: Colors.white,
              hourMinuteTextStyle: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),

              // Dial
              dialBackgroundColor: dialogBg,
              dialHandColor: accent,
              dialTextColor: Colors.white,
              dialTextStyle: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),

              // Entry mode icon
              entryModeIconColor: Colors.white70,

              // AM/PM (if shown)
              dayPeriodColor: dialogBg,
              dayPeriodTextColor: Colors.white,
              dayPeriodTextStyle: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              dayPeriodBorderSide: const BorderSide(color: Colors.white24),

              // Buttons (Cancel / OK) larger tap targets
              cancelButtonStyle: TextButton.styleFrom(
                foregroundColor: Colors.white70,
                textStyle: const TextStyle(
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
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ), dialogTheme: DialogThemeData(backgroundColor: dialogBg),
          ),
          child: child!,
        );
      },
    );

    if (time == null) return;

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
    // Push the map screen and wait for selected start & end points
    final result = await Navigator.of(context).push<List<LatLng>>(
      MaterialPageRoute(builder: (_) => const MapPickScreen()),
    );

    if (result != null && result.length == 2) {
      setState(() {
        _startLatLng = result[0];
        _endLatLng = result[1];
        // keep meetingLatLng for backwards compatibility (use start)
        _meetingLatLng = _startLatLng;
      });
    }
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

    // 1) Build the Firestore payload
    final payload = <String, dynamic>{
      'title': _title,
      'dateTime': _dateTime.toIso8601String(),
      'distanceKm': _distanceKm,
      'gender': _gender,
      'hostUid': uid,
      'cancelled': false,
      'meetingPlaceName': _meetingPlace.isEmpty ? null : _meetingPlace,
      // Keep meetingLat/meetingLng for legacy use (start point)
      'meetingLat': _meetingLatLng?.latitude,
      'meetingLng': _meetingLatLng?.longitude,
      // New start/end coordinates
      'startLat': _startLatLng?.latitude,
      'startLng': _startLatLng?.longitude,
      'endLat': _endLatLng?.latitude,
      'endLng': _endLatLng?.longitude,
      'description': _description.isEmpty ? null : _description,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      // 2) Create walk doc in Firestore
      final docRef = await FirebaseFirestore.instance
          .collection('walks')
          .add(payload);

      // 3) Build your local WalkEvent with the REAL firestoreId
      final newEvent = WalkEvent(
        id: docRef.id,
        hostUid: uid,
        firestoreId: docRef.id, // ✅ this is what chat uses
        title: _title,
        dateTime: _dateTime,
        distanceKm: _distanceKm,
        gender: _gender,
        isOwner: true,
        joined: false,
        meetingPlaceName: _meetingPlace.isEmpty ? null : _meetingPlace,
        meetingLat: _meetingLatLng?.latitude,
        meetingLng: _meetingLatLng?.longitude,
        startLat: _startLatLng?.latitude,
        startLng: _startLatLng?.longitude,
        endLat: _endLatLng?.latitude,
        endLng: _endLatLng?.longitude,
        description: _description.isEmpty ? null : _description,
      );

      // 4) Notify HomeScreen + go back
      widget.onEventCreated(newEvent);
      widget.onCreatedNavigateHome();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to create walk: $e')));
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
                      _HeaderLogo(), // ✅ remove const so it can adapt correctly if needed
                      const SizedBox(width: 8),
                      Text(
                        'Yalla Nemshi',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : const Color.fromARGB(
                                  255,
                                  255,
                                  255,
                                  255,
                                ), // ✅ dark text in light mode
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),

                  // Keep the right side empty like before (no feature changes)
                  const SizedBox(width: 32),
                ],
              ),
            ),
          ),

// ===== MAIN AREA: Home-style gradient in dark mode =====
Expanded(
  child: Container(
    width: double.infinity,
    decoration: const BoxDecoration(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF071B26), // top (dark blue)
                  Color(0xFF041016), // bottom (almost black)
                ],
              )
            : null, // keep light mode exactly as-is (no gradient added here)
        color: isDark ? null : const Color(0xFFF7F9F2), // same light background
      ),
      child: SingleChildScrollView(
        
                padding: EdgeInsets.fromLTRB(
                  kSpace2,
                  kSpace2,
                  kSpace2,
                  kSpace3 +
                      MediaQuery.of(context).viewInsets.bottom + // keyboard
                      MediaQuery.of(
                        context,
                      ).padding.bottom, // gesture bar / safe bottom
                ),
                child: Card(
                  color: isDark ? const Color(0xFF0C2430) : kLightSurface,
                  elevation: isDark ? kCardElevationDark : kCardElevationLight,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(kRadiusCard),
                    side: BorderSide(
                      color: (isDark ? Colors.white : Colors.black).withOpacity(
                        kCardBorderAlpha,
                      ),
                    ),
                  ),
                  child: Theme(
                    data: theme.copyWith(
                      inputDecorationTheme: InputDecorationTheme(
                        filled: true,
                        fillColor: isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.white,

                        labelStyle: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),

                        // default border
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(kRadiusControl),
                          borderSide: BorderSide(
                            color: (isDark ? Colors.white : Colors.black)
                              .withOpacity(0.12),
                          ),
                        ),

                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(kRadiusControl),
                          borderSide: BorderSide(
                            color: (isDark ? Colors.white : Colors.black)
                              .withOpacity(0.12),
                          ),
                        ),

                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(kRadiusControl),
                          borderSide: BorderSide(
                            color: isDark
                              ? Colors.white.withOpacity(0.35)
                                : const Color(0xFF294630),
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        kSpace2,
                        kSpace3,
                        kSpace2,
                        kSpace3,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title + subtitle INSIDE the card (Home-style)
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
                          // ===== FORM + WALK TYPE TABS =====
                          DefaultTabController(
                            length: 3,
                            initialIndex: 0, // Type A default
                            child: Builder(
                              builder: (context) {
                                final tabController =
                                    DefaultTabController.of(context);

                                tabController.addListener(() {
                                  if (!tabController.indexIsChanging) return;
                                  setState(() => _walkTypeIndex = tabController.index);
                                });

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Tabs (inside card)
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white.withOpacity(0.06)
                                            : Colors.black.withOpacity(0.04),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: (isDark ? Colors.white : Colors.black)
                                              .withOpacity(0.08),
                                        ),
                                      ),
                                      child: TabBar(
                                        dividerColor: Colors.transparent,
                                        indicatorSize: TabBarIndicatorSize.tab,
                                        indicator: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          color: isDark
                                              ? Colors.white.withOpacity(0.10)
                                              : Colors.white,
                                        ),
                                        labelColor:
                                            isDark ? Colors.white : const Color(0xFF294630),
                                        unselectedLabelColor:
                                            isDark ? Colors.white70 : Colors.black54,
                                        tabs: const [
                                          Tab(text: 'Point to point'),
                                          Tab(text: 'Loop'),
                                          Tab(text: 'Explore walk'),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    Form(
                                      key: _formKey,
                                      child: Column(
                                        children: [
                                          // Title (still used for hosted walks)
                                          TextFormField(
                                            decoration: const InputDecoration(
                                              labelText: 'Title',
                                            ),
                                            onSaved: (val) => _title = val!.trim(),
                                            validator: (val) =>
                                                (val == null || val.trim().isEmpty)
                                                    ? 'Required'
                                                    : null,
                                          ),
                                          const SizedBox(height: 12),

                                          // ===== TYPE-SPECIFIC SECTION =====
                                          if (_walkTypeIndex == 0) ...[
                                            // Type A: Point-to-point
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                'Route',
                                                style: theme.textTheme.titleMedium,
                                              ),
                                            ),
                                            const SizedBox(height: 8),

                                            // Start (default: current location)
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 12,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? Colors.white.withOpacity(0.06)
                                                    : Colors.white,
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: (isDark ? Colors.white : Colors.black)
                                                      .withOpacity(0.12),
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
                                                      overflow: TextOverflow.ellipsis,
                                                      style: theme.textTheme.bodyMedium?.copyWith(
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
                                            const SizedBox(height: 10),

                                            // Destination search (text only for now)
                                            TextFormField(
                                              decoration: const InputDecoration(
                                                labelText: 'Destination (search)',
                                                hintText: 'Search for a place name',
                                                prefixIcon: Icon(Icons.search),
                                              ),
                                              onSaved: (val) => _destinationText = (val ?? '').trim(),
                                            ),
                                            const SizedBox(height: 8),

                                            // Pick destination on map (uses end point)
                                            SizedBox(
                                              width: double.infinity,
                                              child: OutlinedButton.icon(
                                                onPressed: _pickOnMap,
                                                style: OutlinedButton.styleFrom(
                                                  minimumSize: const Size.fromHeight(52),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(16),
                                                  ),
                                                  side: BorderSide(
                                                    color: (isDark ? Colors.white : Colors.black)
                                                        .withOpacity(0.18),
                                                  ),
                                                  foregroundColor:
                                                      isDark ? Colors.white : Colors.black,
                                                ),
                                                icon: const Icon(Icons.map_outlined),
                                                label: const Text(
                                                  'Pick start & destination on map',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),

                                            const SizedBox(height: 6),

                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                _endLatLng == null
                                                    ? 'Destination pin not selected yet (optional for now)'
                                                    : 'Destination selected on map',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  color: isDark ? Colors.white54 : Colors.black54,
                                                ),
                                              ),
                                            ),

                                            const SizedBox(height: 16),
                                          ] else if (_walkTypeIndex == 1) ...[
                                            // Type B: Loop
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                'Loop walk',
                                                style: theme.textTheme.titleMedium,
                                              ),
                                            ),
                                            const SizedBox(height: 8),

                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 12,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? Colors.white.withOpacity(0.06)
                                                    : Colors.white,
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: (isDark ? Colors.white : Colors.black)
                                                      .withOpacity(0.12),
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
                                                      overflow: TextOverflow.ellipsis,
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
                                            const SizedBox(height: 12),

                                            // Simple duration preset
                                            DropdownButtonFormField<int>(
                                              value: _loopMinutes,
                                              decoration: const InputDecoration(
                                                labelText: 'Duration',
                                              ),
                                              items: const [
                                                DropdownMenuItem(value: 20, child: Text('20 min')),
                                                DropdownMenuItem(value: 30, child: Text('30 min')),
                                                DropdownMenuItem(value: 40, child: Text('40 min')),
                                                DropdownMenuItem(value: 60, child: Text('60 min')),
                                              ],
                                              onChanged: (v) {
                                                if (v == null) return;
                                                setState(() => _loopMinutes = v);
                                              },
                                            ),
                                            const SizedBox(height: 16),
                                          ] else ...[
                                            // Type C: Free walk
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                'Free walk',
                                                style: theme.textTheme.titleMedium,
                                              ),
                                            ),
                                            const SizedBox(height: 8),

                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 12,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? Colors.white.withOpacity(0.06)
                                                    : Colors.white,
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: (isDark ? Colors.white : Colors.black)
                                                      .withOpacity(0.12),
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
                                                      overflow: TextOverflow.ellipsis,
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
                                            const SizedBox(height: 10),

                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                'No destination. Walk freely and end whenever you want.',
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  color: isDark ? Colors.white70 : Colors.black54,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                          ],

                                          // Distance
                                          // - Hidden for Type A (point-to-point)
                                          // - Required for Type B (loop)
                                          // - Optional for Type C (free): only applies if user enters a value
                                          if (_walkTypeIndex != 0) ...[
                                            TextFormField(
                                              key: ValueKey(_distanceKm),
                                              decoration: InputDecoration(
                                                labelText: 'Distance (km)',
                                                hintText: _walkTypeIndex == 2
                                                    ? 'Optional (leave empty to track freely)'
                                                    : null,
                                              ),
                                              keyboardType:
                                                  const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),

                                              // For Free walk (Type C), start blank so it's truly optional
                                              initialValue: _walkTypeIndex == 2
                                                  ? ''
                                                  : _distanceKm.toStringAsFixed(1),

                                              validator: (val) {
                                                final raw = (val ?? '').trim();

                                                // Free walk: optional
                                                if (_walkTypeIndex == 2) {
                                                  if (raw.isEmpty) return null; // ✅ optional
                                                  final d = double.tryParse(raw);
                                                  if (d == null) return 'Please enter a number';
                                                  if (d <= 0) return 'Distance must be greater than 0';
                                                  if (d > 100) return 'That’s a long walk! Try under 100 km';
                                                  return null;
                                                }

                                                // Loop walk: required
                                                final d = double.tryParse(raw);
                                                if (d == null) return 'Please enter a number';
                                                if (d <= 0) return 'Distance must be greater than 0';
                                                if (d > 100) return 'That’s a long walk! Try under 100 km';
                                                return null;
                                              },

                                              onSaved: (val) {
                                                final raw = (val ?? '').trim();

                                                // Free walk: only apply if user entered something
                                                if (_walkTypeIndex == 2) {
                                                  if (raw.isEmpty) return; // ✅ keep existing _distanceKm
                                                  _distanceKm =
                                                      double.tryParse(raw) ?? _distanceKm;
                                                  return;
                                                }

                                                // Loop: always save
                                                _distanceKm = double.tryParse(raw) ?? _distanceKm;
                                              },
                                            ),
                                            const SizedBox(height: 12),
                                          ],



                                          // Gender filter
                                          DropdownButtonFormField<String>(
                                            initialValue: _gender,
                                            decoration: const InputDecoration(
                                              labelText: 'Who can join?',
                                            ),
                                            items: const [
                                              DropdownMenuItem(value: 'Mixed', child: Text('Mixed')),
                                              DropdownMenuItem(value: 'Women only', child: Text('Women only')),
                                              DropdownMenuItem(value: 'Men only', child: Text('Men only')),
                                            ],
                                            onChanged: (val) {
                                              if (val != null) setState(() => _gender = val);
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
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: isDark ? Colors.white70 : Colors.black54,
                                              ),
                                            ),
                                            trailing: IconButton(
                                              icon: Icon(
                                                Icons.calendar_today,
                                                color: isDark ? Colors.white70 : Colors.white,
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
                                                MediaQuery.of(context).size.height < 700 ? 3 : 5,
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
                                                minimumSize: const Size.fromHeight(52),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(16),
                                                ),
                                                backgroundColor: const Color(0xFF14532D),
                                                foregroundColor: Colors.white,
                                              ),
                                              child: Text(
                                                _walkTypeIndex == 0
                                                    ? 'Create walk'
                                                    : _walkTypeIndex == 1
                                                        ? 'Create loop walk'
                                                        : 'Start free walk',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
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
