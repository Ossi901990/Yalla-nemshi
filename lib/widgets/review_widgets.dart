import 'package:flutter/material.dart';
import '../models/review.dart';

/// Widget to display a single review
class ReviewCard extends StatelessWidget {
  final Review review;
  final VoidCallback? onDelete;
  final VoidCallback? onHelpful;

  const ReviewCard({
    super.key,
    required this.review,
    this.onDelete,
    this.onHelpful,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Avatar, name, rating
            Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 20,
                  backgroundImage: review.userProfileUrl != null
                      ? NetworkImage(review.userProfileUrl!)
                      : null,
                  child: review.userProfileUrl == null
                      ? const Icon(Icons.person, size: 20)
                      : null,
                ),
                const SizedBox(width: 12),
                // Name and date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.userName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _formatDate(review.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Rating stars
                _buildRatingStars(review.rating, theme),
              ],
            ),
            const SizedBox(height: 12),
            if ((review.reviewText ?? '').isNotEmpty) ...[
              // Review text
              Text(
                review.reviewText!,
                style: theme.textTheme.bodyMedium,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
            ],
            // Actions
            Row(
              children: [
                if (onHelpful != null)
                  TextButton.icon(
                    onPressed: onHelpful,
                    icon: const Icon(Icons.thumb_up, size: 16),
                    label: Text(
                      'Helpful (${review.helpfulCount})',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                const Spacer(),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete, size: 18),
                    onPressed: onDelete,
                    tooltip: 'Delete review',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingStars(double rating, ThemeData theme) {
    return Row(
      children: List.generate(5, (index) {
        final filled = index < rating.toInt();
        return Icon(
          filled ? Icons.star : Icons.star_border,
          size: 16,
          color: Colors.amber,
        );
      }),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}

/// Widget to display rating stats
class RatingStatsWidget extends StatelessWidget {
  final ReviewStats stats;
  final VoidCallback? onWriteReview;

  const RatingStatsWidget({super.key, required this.stats, this.onWriteReview});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (stats.totalReviews == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              const Icon(Icons.star_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                'No reviews yet',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Be the first to review this walk',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              if (onWriteReview != null) ...[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: onWriteReview,
                  child: const Text('Write a Review'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Average rating and count
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      stats.averageRating.toStringAsFixed(1),
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      children: [
                        _buildSmallRatingStars(stats.averageRating),
                        const SizedBox(height: 4),
                        Text(
                          '${stats.totalReviews} review${stats.totalReviews > 1 ? 's' : ''}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const Spacer(),
            if (onWriteReview != null)
              FilledButton(
                onPressed: onWriteReview,
                child: const Text('Write Review'),
              ),
          ],
        ),
        const SizedBox(height: 24),
        // Rating distribution bars
        ..._buildRatingBars(stats, theme),
      ],
    );
  }

  Widget _buildSmallRatingStars(double rating) {
    return Row(
      children: List.generate(5, (index) {
        final filled = index < rating.toInt();
        return Icon(
          filled ? Icons.star : Icons.star_border,
          size: 14,
          color: Colors.amber,
        );
      }),
    );
  }

  List<Widget> _buildRatingBars(ReviewStats stats, ThemeData theme) {
    return [5, 4, 3, 2, 1].map((rating) {
      final count = stats.ratingDistribution[rating] ?? 0;
      final percentage = stats.totalReviews == 0
          ? 0.0
          : (count / stats.totalReviews);

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Text(
                '$rating★',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percentage,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getRatingColor(rating),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 40,
              child: Text(
                count.toString(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Color _getRatingColor(int rating) {
    switch (rating) {
      case 5:
      case 4:
        return const Color(0xFF00D97E);
      case 3:
        return Colors.amber;
      case 2:
      case 1:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
