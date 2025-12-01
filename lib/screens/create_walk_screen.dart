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

  InputDecoration _fieldDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.grey.shade300,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFF4F925C),
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
    );
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
      joined: false,

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
    const bgColor = Color(0xFFF7F9F2);

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          // ===== Gradient header (same style family as other screens) =====
          Container(
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
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 64,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios_new,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(width: 4),
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
                      // Notifications only – no profile avatar here
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white24,
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Center(
                              child: Icon(
                                Icons.notifications_none,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                            Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.red,
                                ),
                                child: const Text(
                                  '3',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                  ),
                                ),
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

          // ===== Main content =====
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Big rounded card holding the whole form
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 1,
                    color: const Color(0xFFFCFEF9),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header inside the card
                            Row(
                              children: const [
                                Icon(
                                  Icons.flag_outlined,
                                  size: 22,
                                  color: Color(0xFF294630),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Create new walk',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF294630),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Set the basics, time, and meeting point for your walk.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.grey.shade700),
                            ),

                            const SizedBox(height: 20),

                            // ------ Basics ------
                            Text(
                              'Basics',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),

                            // Title
                            TextFormField(
                              decoration: _fieldDecoration(
                                'Title',
                                hint: 'Morning walk in the park',
                              ),
                              onSaved: (val) => _title = val!.trim(),
                              validator: (val) => (val == null ||
                                      val.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                            ),
                            const SizedBox(height: 12),

                            // Distance
                            TextFormField(
                              decoration: _fieldDecoration(
                                'Distance (km)',
                                hint: 'e.g. 3.5',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              initialValue: _distanceKm.toStringAsFixed(1),
                              onSaved: (val) => _distanceKm =
                                  double.tryParse(val ?? '') ?? 3.0,
                            ),
                            const SizedBox(height: 12),

                            // Gender chips
                            Text(
                              'Who can join?',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              children: [
                                _GenderChip(
                                  label: 'Mixed',
                                  selected: _gender == 'Mixed',
                                  onTap: () =>
                                      setState(() => _gender = 'Mixed'),
                                ),
                                _GenderChip(
                                  label: 'Women only',
                                  selected: _gender == 'Women only',
                                  onTap: () =>
                                      setState(() => _gender = 'Women only'),
                                ),
                                _GenderChip(
                                  label: 'Men only',
                                  selected: _gender == 'Men only',
                                  onTap: () =>
                                      setState(() => _gender = 'Men only'),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // ------ When ------
                            Text(
                              'When',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),

                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                leading: const Icon(Icons.calendar_today),
                                title: const Text('Date & time'),
                                subtitle: Text(
                                  _dateTime.toString(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.grey.shade700),
                                ),
                                trailing: const Icon(Icons.edit_outlined),
                                onTap: _pickDateTime,
                              ),
                            ),

                            const SizedBox(height: 20),

                            // ------ Meeting point ------
                            Text(
                              'Meeting point',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),

                            TextFormField(
                              decoration: _fieldDecoration(
                                'Location name (optional)',
                                hint: 'e.g. Rainbow St. entrance',
                              ),
                              onSaved: (val) =>
                                  _meetingPlace = (val ?? '').trim(),
                            ),
                            const SizedBox(height: 8),

                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _pickOnMap,
                                icon: const Icon(Icons.map_outlined),
                                label: const Text('Pick on map'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _meetingLatLng == null
                                  ? 'No location chosen yet'
                                  : 'Picked: Lat ${_meetingLatLng!.latitude.toStringAsFixed(5)}, '
                                      'Lng ${_meetingLatLng!.longitude.toStringAsFixed(5)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.grey.shade700),
                            ),

                            const SizedBox(height: 20),

                            // ------ Details ------
                            Text(
                              'Details',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),

                            TextFormField(
                              decoration: _fieldDecoration(
                                'Description (optional)',
                                hint:
                                    'Any notes for the group? Pace, difficulty, what to bring…',
                              ),
                              maxLines: 3,
                              onSaved: (val) =>
                                  _description = (val ?? '').trim(),
                            ),

                            const SizedBox(height: 24),

                            // Submit button
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _submit,
                                icon: const Icon(Icons.check),
                                label: const Text('Create walk'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
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
          ),
        ],
      ),
    );
  }
}

class _GenderChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GenderChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFFB7E76A),
      labelStyle: TextStyle(
        color: selected ? Colors.black : Colors.black87,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
