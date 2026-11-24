// lib/widgets/ui/ui_kit.dart
//
// Shared building blocks of the 2026 redesign (docs/design/home-*.png).
// Colours come from AppPalette, text from AppText.
import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';

/// Rounded card. [shadowColor] adds the playful offset "shadow" block used on
/// the hero card (use sparingly).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.onTap,
    this.radius = AppSpace.radiusCard,
    this.shadowColor,
    this.bordered = true,
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final Color? shadowColor;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final fill = color ?? p.surface;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: bordered && color == null
          ? BorderSide(color: p.border)
          : BorderSide.none,
    );

    Widget card = Material(
      color: fill,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );

    if (shadowColor != null) {
      card = Padding(
        padding: const EdgeInsets.only(right: 8, bottom: 8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              left: 8,
              top: 8,
              right: -8,
              bottom: -8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: shadowColor,
                  borderRadius: BorderRadius.circular(radius),
                ),
              ),
            ),
            card,
          ],
        ),
      );
    }
    return card;
  }
}

/// Pill-shaped button. [dark] = ink fill with lime text (the hero card's
/// "I'm in"); otherwise lime fill with ink text.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.dark = true,
    this.icon,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool dark;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final bg = dark ? AppPalette.ink : AppPalette.lime;
    final fg = dark ? AppPalette.lime : AppPalette.ink;
    return Material(
      color: onPressed == null ? bg.withValues(alpha: 0.5) : bg,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: busy ? null : onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          child: busy
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18, color: fg),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      label,
                      style: AppText.body(
                        16,
                        color: fg,
                        weight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Round icon button (bell, +) with an optional coral count badge.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 52,
    this.background,
    this.foreground,
    this.badgeCount = 0,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? background;
  final Color? foreground;
  final int badgeCount;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final button = Material(
      color: background ?? p.surface,
      shape: CircleBorder(
        side: background == null
            ? BorderSide(color: p.border)
            : BorderSide.none,
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: foreground ?? p.text, size: size * 0.44),
        ),
      ),
    );

    return Tooltip(
      message: tooltip ?? '',
      triggerMode: tooltip == null ? TooltipTriggerMode.manual : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          button,
          if (badgeCount > 0)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: AppPalette.coral,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: p.background, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  badgeCount > 9 ? '9+' : '$badgeCount',
                  style: AppText.body(
                    11,
                    color: AppPalette.ink,
                    weight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small rounded label ("SUN · 22 NOV", "Starting soon").
class PillLabel extends StatelessWidget {
  const PillLabel({
    super.key,
    required this.text,
    this.background = AppPalette.lime,
    this.foreground = AppPalette.ink,
    this.dotColor,
  });

  final String text;
  final Color background;
  final Color foreground;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpace.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(
                13,
                color: foreground,
                weight: FontWeight.w800,
              ).copyWith(letterSpacing: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// Day + time block on the left of a walk row ("TUE / 07:00").
class TimeChip extends StatelessWidget {
  const TimeChip({
    super.key,
    required this.day,
    required this.time,
    required this.color,
    this.size = 72,
  });

  final String day;
  final String time;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppSpace.radiusChip),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            day,
            style: AppText.body(
              12,
              color: AppPalette.ink,
              weight: FontWeight.w700,
            ),
          ),
          Text(
            time,
            style: AppText.display(
              20,
              color: AppPalette.ink,
              weight: 800,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// One person in an [AvatarStack].
class AvatarStackPerson {
  const AvatarStackPerson(this.name, [this.photoUrl]);
  final String name;
  final String? photoUrl;
}

/// Overlapping initials/photo circles with a "+N" bubble.
class AvatarStack extends StatelessWidget {
  const AvatarStack({
    super.key,
    required this.people,
    this.extra = 0,
    this.size = 38,
    this.ringColor = AppPalette.ink,
  });

  final List<AvatarStackPerson> people;
  final int extra;
  final double size;
  final Color ringColor;

  static const _fills = [AppPalette.peach, AppPalette.blue, AppPalette.teal];

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p.characters.first.toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final shown = people.take(3).toList();
    final bubbles = <Widget>[
      for (var i = 0; i < shown.length; i++) _circle(shown[i], _fills[i % 3]),
      if (extra > 0)
        _bubble(
          AppPalette.ink,
          Text(
            '+$extra',
            style: AppText.body(
              size * 0.36,
              color: Colors.white,
              weight: FontWeight.w800,
            ),
          ),
        ),
    ];
    if (bubbles.isEmpty) return const SizedBox.shrink();
    final step = size * 0.68;
    return SizedBox(
      width: size + step * (bubbles.length - 1),
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < bubbles.length; i++)
            Positioned(left: step * i, child: bubbles[i]),
        ],
      ),
    );
  }

  Widget _circle(AvatarStackPerson person, Color fill) {
    final url = person.photoUrl;
    return _bubble(
      fill,
      Text(
        initials(person.name),
        style: AppText.body(
          size * 0.34,
          color: AppPalette.ink,
          weight: FontWeight.w800,
        ),
      ),
      photo: (url != null && url.isNotEmpty) ? NetworkImage(url) : null,
    );
  }

  Widget _bubble(Color fill, Widget child, {ImageProvider? photo}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: ringColor, width: 2),
      ),
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(child: child),
            if (photo != null)
              Image(
                image: photo,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Coming up ............ See all"
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(title, style: AppText.display(30, color: p.text)),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                // Lime text only on dark backgrounds.
                foregroundColor: isDark ? AppPalette.lime : p.text,
                textStyle: AppText.body(16, weight: FontWeight.w700),
              ),
              child: Text(action!),
            ),
        ],
      ),
    );
  }
}
