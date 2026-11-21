import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme.dart';

class GlassNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const GlassNavItem({required this.icon, required this.activeIcon, required this.label});
}

/// شريط تنقّل سفلي عائم زجاجي (Glassmorphism)
/// يبقى فوق منطقة إيماءات النظام ولا يختلط بها
class GlassNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final List<GlassNavItem> items;

  const GlassNavBar({
    super.key,
    required this.index,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, safeBottom > 0 ? safeBottom : kFloatingNavGap),
      child: Container(
        height: kFloatingNavHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.plum.withValues(alpha: 0.20),
              blurRadius: 26,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: (dark ? const Color(0xFF1B0A2E) : Colors.white)
                    .withValues(alpha: dark ? 0.72 : 0.62),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: dark ? 0.16 : 0.65),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: _NavButton(
                        item: items[i],
                        active: i == index,
                        dark: dark,
                        onTap: () => onTap(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final GlassNavItem item;
  final bool active;
  final bool dark;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.active,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: active ? 8 : 6,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            gradient: active ? AppColors.headerGradient : null,
            borderRadius: BorderRadius.circular(20),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppColors.purple.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active ? item.activeIcon : item.icon,
                size: 21,
                color: active
                    ? Colors.white
                    : (dark ? Colors.white70 : AppColors.muted),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                child: active
                    ? Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: Text(
                          item.label,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
