// lib/widgets/ui/floating_nav_bar.dart
import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';

/// Floating bottom bar of the redesign: Home, Map, (+), Calendar, Profile.
///
/// It floats over the page, so screens using it must leave
/// [FloatingNavBar.reservedHeight] of space at the bottom of their content.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onCreate,
  });

  /// 0 = home, 1 = map, 2 = calendar, 3 = profile.
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onCreate;

  /// Space to leave below scrolling content so nothing hides under the bar.
  static const double reservedHeight = 120;

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.map_outlined, Icons.map_rounded, 'Walks map'),
    (Icons.calendar_today_outlined, Icons.calendar_today_rounded, 'Calendar'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    Widget item(int index) {
      final (icon, activeIcon, label) = _items[index];
      final selected = index == currentIndex;
      return Expanded(
        child: Center(
          child: Tooltip(
            message: label,
            child: Semantics(
              button: true,
              selected: selected,
              label: label,
              child: InkResponse(
                onTap: () => onTap(index),
                radius: 32,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFF4F7F5)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    selected ? activeIcon : icon,
                    color: selected ? AppPalette.ink : p.navIcon,
                    size: 26,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottomInset),
      child: SizedBox(
        height: 96,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: 76,
              decoration: BoxDecoration(
                color: p.navBar,
                borderRadius: BorderRadius.circular(38),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  item(0),
                  item(1),
                  const SizedBox(width: 88), // room for the + button
                  item(2),
                  item(3),
                ],
              ),
            ),
            Positioned(top: 0, child: _CreateButton(onTap: onCreate)),
          ],
        ),
      ),
    );
  }
}

/// Raised lime "+" with the coral offset block behind it.
class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const size = 76.0;
    return Semantics(
      button: true,
      label: 'Create a walk',
      child: SizedBox(
        width: size + 6,
        height: size + 6,
        child: Stack(
          children: [
            Positioned(
              left: 6,
              top: 6,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: AppPalette.coral,
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
            Material(
              color: AppPalette.lime,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: const BorderSide(color: AppPalette.ink, width: 3),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: onTap,
                child: const SizedBox(
                  width: size,
                  height: size,
                  child: Icon(
                    Icons.add_rounded,
                    color: AppPalette.ink,
                    size: 40,
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
