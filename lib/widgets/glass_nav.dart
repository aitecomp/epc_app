import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme.dart';

class GlassNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const GlassNavItem({required this.icon, required this.activeIcon, required this.label});
}

/// شريط تنقّل سفلي زجاجي (Glassmorphism)
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
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: EdgeInsets.only(
            top: 10,
            bottom: 10 + MediaQuery.of(context).padding.bottom * 0.35,
            left: 18,
            right: 18,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.55), width: 1.2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavButton(
                    item: items[i],
                    active: i == index,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final GlassNavItem item;
  final bool active;
  final VoidCallback onTap;

  const _NavButton({required this.item, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 52,
              height: 32,
              decoration: BoxDecoration(
                gradient: active ? AppColors.headerGradient : null,
                color: active ? null : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: AppColors.purple.withValues(alpha: 0.32),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                active ? item.activeIcon : item.icon,
                size: 20,
                color: active ? Colors.white : AppColors.muted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? AppColors.purple : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
