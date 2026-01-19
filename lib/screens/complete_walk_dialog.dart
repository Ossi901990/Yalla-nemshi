import 'package:flutter/material.dart';
import '../models/walk_event.dart';
import '../services/walk_history_service.dart';
import '../services/user_stats_service.dart';
import '../services/crash_service.dart';
import '../utils/error_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Dialog for marking a walk as completed and recording stats
class CompleteWalkDialog extends StatefulWidget {
  final WalkEvent walk;
  final VoidCallback onCompleted;

  const CompleteWalkDialog({
    super.key,
    required this.walk,
    required this.onCompleted,
  });

  @override
  State<CompleteWalkDialog> createState() => _CompleteWalkDialogState();
}

class _CompleteWalkDialogState extends State<CompleteWalkDialog> {
  late TextEditingController _distanceController;
  late TextEditingController _durationController;
  late TextEditingController _notesController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _distanceController =
        TextEditingController(text: widget.walk.distanceKm.toStringAsFixed(1));
    _durationController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _distanceController.dispose();
    _durationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitCompletion() async {
    if (_durationController.text.isEmpty) {
      ErrorHandler.showErrorSnackBar(
        context,
        'Please enter walk duration (minutes)',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final distance = double.tryParse(_distanceController.text) ??
          widget.walk.distanceKm;
      final durationMinutes =
          int.tryParse(_durationController.text) ?? 0;
      final duration = Duration(minutes: durationMinutes);
      final notes = _notesController.text.trim();

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        throw Exception('User not authenticated');
      }

      final walkId = widget.walk.firestoreId.isNotEmpty
          ? widget.walk.firestoreId
          : widget.walk.id;

      // Mark walk as completed
      await WalkHistoryService.instance.markWalkCompleted(
        walkId,
        distanceKm: distance,
        duration: duration,
        notes: notes.isNotEmpty ? notes : null,
      );

      // Update user stats (assumes user is a participant, not host)
      // Only count as completed if user walked majority of time
      final participantCount = widget.walk.joinedUserUids.length;
      await UserStatsService.instance.incrementWalkCompleted(
        userId: uid,
        distanceKm: distance,
        duration: duration,
        participantCount: participantCount,
      );

      if (mounted) {
        Navigator.of(context).pop();
        widget.onCompleted();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Walk completed! Stats saved.')),
        );
      }
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'CompleteWalkDialog._submitCompletion error',
      );
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          'Failed to save walk completion',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Complete Walk'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.walk.title,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _distanceController,
              decoration: InputDecoration(
                labelText: 'Distance (km)',
                prefixIcon: const Icon(Icons.straighten),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _durationController,
              decoration: InputDecoration(
                labelText: 'Duration (minutes)',
                prefixIcon: const Icon(Icons.timer),
                hintText: 'e.g., 60',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                prefixIcon: const Icon(Icons.note),
                hintText: 'How was the walk?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitCompletion,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

/// Show complete walk dialog
void showCompleteWalkDialog({
  required BuildContext context,
  required WalkEvent walk,
  required VoidCallback onCompleted,
}) {
  showDialog(
    context: context,
    builder: (context) => CompleteWalkDialog(
      walk: walk,
      onCompleted: onCompleted,
    ),
  );
}
