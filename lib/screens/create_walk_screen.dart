// lib/screens/create_walk_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/walk_event.dart';
import 'map_pick_screen.dart';
import '../services/app_preferences.dart'; 

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

  String _title = '';
  double _distanceKm = 3.0;
  String _gender = 'Mixed';


  DateTime _dateTime = DateTime.now().add(const Duration(days: 1));

  // Text name for the meeting point (user can type it)
  String _meetingPlace = '';

  // Coordinates picked from the map
  LatLng? _meetingLatLng;

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
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
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
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
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
    // Push the map screen and wait for the selected LatLng
    final result = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => const MapPickScreen(),
      ),
    );

    if (result != null) {
      setState(() {
        _meetingLatLng = result;
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final newEvent = WalkEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _title,
      dateTime: _dateTime,
      distanceKm: _distanceKm,
      gender: _gender,
      isOwner: true,
      joined: false, // host but not "joined" by default

      // Optional text name
      meetingPlaceName: _meetingPlace.isEmpty ? null : _meetingPlace,

      // Coordinates from map (if any)
      meetingLat: _meetingLatLng?.latitude,
      meetingLng: _meetingLatLng?.longitude,

      description: _description.isEmpty ? null : _description,
    );

    widget.onEventCreated(newEvent);
    widget.onCreatedNavigateHome();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      // ✅ match Home / Nearby / Profile
      backgroundColor:
          isDark ? const Color(0xFF0B1A13) : const Color(0xFF4F925C),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ===== HEADER (same gradient pattern) =====
            Container(
              height: 56,
              width: double.infinity,
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: const [
                    // logo
                    _HeaderLogo(),
                    SizedBox(width: 8),
                    Text(
                      'Yalla Nemshi',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ===== MAIN SHEET WITH BG IMAGE (matches Home/Profile) =====
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
                          ? 'assets/images/Dark_Grey_Background.png'
                          : 'assets/images/Light_Beige_background.png',
                    ),
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
                // overlay so text & form stay readable
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title + subtitle
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
                            color:
                                isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ===== FORM =====
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              // Title
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

                              // Distance
TextFormField(
  key: ValueKey(_distanceKm), // 👈 so initialValue updates
  decoration: const InputDecoration(
    labelText: 'Distance (km)',
  ),
  keyboardType:
      const TextInputType.numberWithOptions(decimal: true),
  initialValue: _distanceKm.toStringAsFixed(1),

  // ✅ NEW: validation
  validator: (val) {
    final d = double.tryParse(val ?? '');
    if (d == null) {
      return 'Please enter a number';
    }
    if (d <= 0) {
      return 'Distance must be greater than 0';
    }
    if (d > 100) {
      return 'That’s a long walk! Try under 100 km';
    }
    return null; // OK
  },

  onSaved: (val) =>
      _distanceKm = double.tryParse(val ?? '') ?? 3.0,
),
                              const SizedBox(height: 12),

                              // Gender filter
                              DropdownButtonFormField<String>(
                                value: _gender, // 👈 binds to state
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
  style: theme.textTheme.bodySmall?.copyWith(
    color: isDark ? Colors.white70 : Colors.black87,
  ),
),

                                trailing: IconButton(
                                  icon:
                                      const Icon(Icons.calendar_today),
                                  onPressed: _pickDateTime,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Meeting point name + pick on map
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Meeting point',
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Optional custom name
                              TextFormField(
                                decoration: const InputDecoration(
                                  labelText: 'Location name (optional)',
                                  hintText:
                                      'e.g. Rainbow St. entrance',
                                ),
                                onSaved: (val) => _meetingPlace =
                                    (val ?? '').trim(),
                              ),
                              const SizedBox(height: 8),

                              // Button to pick on map
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _pickOnMap,
                                  icon:
                                      const Icon(Icons.map_outlined),
                                  label: const Text('Pick on map'),
                                ),
                              ),

                              const SizedBox(height: 4),

                              // Show status + optional mini map preview
if (_meetingLatLng == null)
  Align(
    alignment: Alignment.centerLeft,
    child: Text(
      'No location chosen yet',
      style: theme.textTheme.bodySmall,
    ),
  )
else
  Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Location selected on map',
        style: theme.textTheme.bodySmall,
      ),
      const SizedBox(height: 4),
      Text(
        'Lat ${_meetingLatLng!.latitude.toStringAsFixed(5)}, '
        'Lng ${_meetingLatLng!.longitude.toStringAsFixed(5)}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: Colors.grey.shade600,
        ),
      ),
      const SizedBox(height: 8),

      // 🔍 Mini map preview (read-only)
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 160,
          width: double.infinity,
          child: AbsorbPointer(
            // make it non-interactive so it doesn't fight the scroll
            absorbing: true,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _meetingLatLng!,
                zoom: 15,
              ),
              markers: {
                Marker(
                  markerId: const MarkerId('meeting_point'),
                  position: _meetingLatLng!,
                ),
              },
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              compassEnabled: false,
              scrollGesturesEnabled: false,
              tiltGesturesEnabled: false,
              rotateGesturesEnabled: false,
              zoomGesturesEnabled: false,
              liteModeEnabled: true, // nicer & lighter on Android
            ),
          ),
        ),
      ),

      const SizedBox(height: 4),
      TextButton.icon(
        onPressed: _pickOnMap, // reopen map to adjust
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: const Icon(Icons.map_outlined, size: 16),
        label: const Text('Change location'),
      ),
    ],
  ),

const SizedBox(height: 16),

                              // Description
                              TextFormField(
                                decoration: const InputDecoration(
                                  labelText: 'Description (optional)',
                                ),
                                maxLines: 3,
                                onSaved: (val) => _description =
                                    (val ?? '').trim(),
                              ),

                              const SizedBox(height: 24),

                              // Submit button
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _submit,
                                  style: FilledButton.styleFrom(
                                    backgroundColor:
                                        const Color(0xFF14532D),
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Create walk'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
      child: const Icon(
        Icons.directions_walk,
        size: 18,
        color: Colors.white,
      ),
    );
  }
}
