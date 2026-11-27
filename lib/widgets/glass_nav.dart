import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme.dart';

class GlassNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int badge;
  final bool messenger;
  const GlassNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badge = 0,
    this.messenger = false,
  });
}

/// شريط تنقّل سفلي عائم زجاجي خفيف ومرتفع عن شريط تنقل الهاتف
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
      padding: EdgeInsets.fromLTRB(12, 0, 12, safeBottom + kFloatingNavGap),
      child: Container(
        height: kFloatingNavHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.plum.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              decoration: BoxDecoration(
                color: (dark ? const Color(0xFF0A1B2E) : Colors.white)
                    .withValues(alpha: dark ? 0.72 : 0.78),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: dark ? 0.18 : 0.9),
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
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: active ? 8 : 5,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            gradient: active ? AppColors.headerGradient : null,
            borderRadius: BorderRadius.circular(18),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppColors.purple.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Badge(
                isLabelVisible: item.badge > 0,
                label: Text(item.badge > 99 ? '99+' : '${item.badge}',
                    style: const TextStyle(fontSize: 9.5)),
                backgroundColor: const Color(0xFFDC2626),
                child: item.messenger
                    ? CustomPaint(
                        size: const Size(19, 19),
                        painter: _MessengerPainter(
                          active ? Colors.white : (dark ? Colors.white70 : AppColors.muted),
                        ),
                      )
                    : Icon(
                        active ? item.activeIcon : item.icon,
                        size: 19,
                        color: active ? Colors.white : (dark ? Colors.white70 : AppColors.muted),
                      ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: active
                    ? Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 62),
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
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

class _MessengerPainter extends CustomPainter {
  final Color color;
  _MessengerPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 24, sy = size.height / 24;
    canvas.save();
    canvas.scale(sx, sy);
    final bubble = Path()
      ..moveTo(12, 1)
      ..cubicTo(5.7, 1, 1, 5.6, 1, 11.4)
      ..cubicTo(1, 14.6, 2.4, 17.3, 4.8, 19.1)
      ..lineTo(4.8, 23)
      ..lineTo(8.6, 20.9)
      ..cubicTo(9.7, 21.2, 10.8, 21.4, 12, 21.4)
      ..cubicTo(18.3, 21.4, 23, 17, 23, 11.4)
      ..cubicTo(23, 5.6, 18.3, 1, 12, 1)
      ..close();
    canvas.drawPath(bubble, Paint()..color = color);
    final bolt = Path()
      ..moveTo(4.6, 14.7)
      ..lineTo(10.3, 8.6)
      ..lineTo(13.5, 11.7)
      ..lineTo(19.3, 8.6)
      ..lineTo(13.7, 14.8)
      ..lineTo(10.4, 11.7)
      ..close();
    canvas.drawPath(bolt, Paint()..color = (color == Colors.white ? const Color(0xFF173452) : Colors.white));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MessengerPainter oldDelegate) => oldDelegate.color != color;
}
