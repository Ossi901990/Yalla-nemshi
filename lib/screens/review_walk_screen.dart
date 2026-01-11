import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/walk_event.dart';
import '../services/review_service.dart';
import '../services/crash_service.dart';

/// Custom exception for timeout errors
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => message;
}

class ReviewWalkScreen extends StatefulWidget {
  static const routeName = '/review-walk';

  final WalkEvent walk;
  final String? userId;
  final String? userName;

  const ReviewWalkScreen({
    super.key,
    required this.walk,
    this.userId,
    this.userName,
  });

  @override
  State<ReviewWalkScreen> createState() => _ReviewWalkScreenState();
}

class _ReviewWalkScreenState extends State<ReviewWalkScreen> {
  final _reviewController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  double _rating = 5.0;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final userId = widget.userId ?? currentUser.uid;
      final userName =
          widget.userName ?? currentUser.displayName ?? 'Anonymous';

      // Prevent duplicate reviews per user per walk
      final hasReviewed = await ReviewService.userAlreadyReviewed(
        widget.walk.id,
        userId,
      ).timeout(const Duration(seconds: 10));
      if (hasReviewed) {
        setState(() {
          _errorMessage = 'You have already reviewed this walk.';
          _isLoading = false;
        });
        return;
      }

      await ReviewService.addReview(
        walkId: widget.walk.id,
        userId: userId,
        userName: userName,
        userProfileUrl: currentUser.photoURL,
        rating: _rating,
        reviewText: _reviewController.text.trim(),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Thank you for your review!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      Navigator.of(
        context,
      ).pop(true); // Return true to indicate review was added
    } catch (e) {
      String message = 'Failed to submit review. Please try again.';

      if (e is TimeoutException) {
        message = 'Request timed out. Please check your internet connection.';
      }

      setState(() {
        _errorMessage = message;
        _isLoading = false;
      });

      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'ReviewWalkScreen._submitReview',
      );
    }
  }

  String? _validateReview(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please write a review';
    }
    if (value.trim().length < 10) {
      return 'Review must be at least 10 characters';
    }
    if (value.length > 500) {
      return 'Review must be less than 500 characters';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Review Walk',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: isDark
            ? const Color(0xFF1B2624)
            : const Color(0xFF294630),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Walk info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.walk.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.walk.city ?? 'Unknown location',
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Rating section
              Text(
                'How was the walk?',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),

              Center(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final starValue = index + 1;
                        final isFilled = starValue <= _rating;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _rating = starValue.toDouble()),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(
                              isFilled ? Icons.star : Icons.star_border,
                              size: 40,
                              color: isFilled
                                  ? Colors.amber
                                  : Colors.grey.shade400,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _getRatingLabel(_rating.toInt()),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Review text
              Text(
                'Tell us more (optional but appreciated)',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _reviewController,
                      enabled: !_isLoading,
                      validator: _validateReview,
                      maxLines: 5,
                      minLines: 3,
                      maxLength: 500,
                      decoration: InputDecoration(
                        hintText:
                            'Share your experience. What did you like? Any suggestions?',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.primaryColor,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey.withValues(alpha: 0.05),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Colors.red,
                            width: 1.5,
                          ),
                        ),
                        errorStyle: const TextStyle(color: Colors.red),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _submitReview,
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    theme.colorScheme.onPrimary,
                                  ),
                                ),
                              )
                            : Text(
                                'Submit Review',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Info box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info, color: Colors.blue, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your review helps other walkers decide if this event is for them.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.blue.shade700,
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
    );
  }

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }
}
