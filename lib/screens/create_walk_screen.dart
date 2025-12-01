// lib/screens/create_walk_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/walk_event.dart';
import 'map_pick_screen.dart';

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

    return Scaffold(
      // match app style (green behind rounded sheet)
      backgroundColor: const Color(0xFF4F925C),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ===== SIMPLE HEADER (logo + app name only, NO buttons) =====
            Container(
              height: 56,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF294630),
                    Color(0xFF4F925C),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Container(
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
                    ),
                    const SizedBox(width: 8),
                    const Text(
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

            // ===== MAIN SHEET (ROUNDED TOP) =====
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFFBFEF8),
                  borderRadius: BorderRadius.vertical(
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
                          color: const Color(0xFF294630),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Set your walk details and invite others to join.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.black54,
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
                              decoration:
                                  const InputDecoration(labelText: 'Title'),
                              onSaved: (val) => _title = val!.trim(),
                              validator: (val) => (val == null ||
                                      val.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                            ),
                            const SizedBox(height: 12),

                            // Distance
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Distance (km)',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              initialValue: _distanceKm.toStringAsFixed(1),
                              onSaved: (val) => _distanceKm =
                                  double.tryParse(val ?? '') ?? 3.0,
                            ),
                            const SizedBox(height: 12),

                            // Gender filter
                            DropdownButtonFormField<String>(
                              initialValue: _gender,
                              decoration: const InputDecoration(
                                  labelText: 'Who can join?'),
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
                              title: const Text('Date & time'),
                              subtitle: Text(_dateTime.toString()),
                              trailing: IconButton(
                                icon: const Icon(Icons.calendar_today),
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
                                hintText: 'e.g. Rainbow St. entrance',
                              ),
                              onSaved: (val) =>
                                  _meetingPlace = (val ?? '').trim(),
                            ),
                            const SizedBox(height: 8),

                            // Button to pick on map
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _pickOnMap,
                                icon: const Icon(Icons.map_outlined),
                                label: const Text('Pick on map'),
                              ),
                            ),

                            const SizedBox(height: 4),

                            // Show status of picked coordinates
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _meetingLatLng == null
                                    ? 'No location chosen yet'
                                    : 'Picked: '
                                        'Lat ${_meetingLatLng!.latitude.toStringAsFixed(5)}, '
                                        'Lng ${_meetingLatLng!.longitude.toStringAsFixed(5)}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Description
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Description (optional)',
                              ),
                              maxLines: 3,
                              onSaved: (val) =>
                                  _description = (val ?? '').trim(),
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
          ],
        ),
      ),
    );
  }
}
